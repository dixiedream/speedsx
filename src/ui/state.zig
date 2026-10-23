/// EditorUI - Main UI state management
const std = @import("std");
const models = @import("../models.zig");
const types = @import("types.zig");

const AppState = types.AppState;
const TextFieldId = types.TextFieldId;
const DropTarget = types.DropTarget;
const InputState = types.InputState;
const TextInputState = types.TextInputState;
const DragDropState = types.DragDropState;
const ScrollState = types.ScrollState;
const ScrollBounds = types.ScrollBounds;
const ContextMenuState = types.ContextMenuState;
const DropdownFieldId = types.DropdownFieldId;
const DropdownPopupState = types.DropdownPopupState;
const ClipboardState = types.ClipboardState;
const SampleBrowserState = types.SampleBrowserState;
const SampleFileEntry = types.SampleFileEntry;
const WaveEditorState = types.WaveEditorState;
const FileDropState = types.FileDropState;

/// UI state for the editor
pub const EditorUI = struct {
    // Application state
    app_state: AppState = .startup,
    startup_path: models.BoundedString(256) = .{},
    startup_error: models.BoundedString(128) = .{},

    // Status message (shown in status bar, auto-clears)
    status_message: models.BoundedString(128) = .{},
    status_is_error: bool = false,
    status_timer: f32 = 0,

    // Selection state
    selected_pad: u8 = 0,
    selected_kit: u8 = 0,
    selected_wave: u16 = 0,
    selected_chain: u8 = 0,
    selected_chain_step: u8 = 0,

    // Panel visibility
    show_kit_browser: bool = true,
    show_sample_browser: bool = false,
    show_settings: bool = false,
    show_midi_config: bool = false,
    show_kit_chain: bool = false,
    show_wave_list: bool = true,
    show_kit_list: bool = true,
    show_wave_editor: bool = false,

    // Pad animation
    pad_flash: [15]f32 = @splat(0),

    // Composed state components
    input: InputState = .{},
    text_input: TextInputState = .{},
    drag: DragDropState = .{},
    scroll: ScrollState = .{},
    context_menu: ContextMenuState = .{},
    dropdown_popup: DropdownPopupState = .{},
    clipboard: ClipboardState = .{},
    sample_browser: SampleBrowserState = .{},
    wave_editor: WaveEditorState = .{},
    file_drop: FileDropState = .{},

    // Sample usage cache (avoids recalculating every frame)
    sample_usage_cache: [models.SampleLibrary.MAX_SAMPLES]bool = @splat(false),
    sample_usage_dirty: bool = true,

    pub fn init() EditorUI {
        return EditorUI{};
    }

    pub fn update(self: *EditorUI, delta: f32) void {
        for (&self.pad_flash) |*flash| {
            if (flash.* > 0) {
                flash.* -= delta * 3.0;
                if (flash.* < 0) flash.* = 0;
            }
        }

        // Cursor blink animation
        self.text_input.cursor_blink += delta * 2.0;
        if (self.text_input.cursor_blink > 1.0) {
            self.text_input.cursor_blink -= 1.0;
        }

        // Status message timer
        self.updateStatus(delta);
    }

    pub fn triggerPadFlash(self: *EditorUI, pad_index: u8) void {
        if (pad_index < 15) {
            self.pad_flash[pad_index] = 1.0;
        }
    }

    pub fn isHovered(self: *const EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
        return self.input.mouse_x >= x and self.input.mouse_x < x + w and
            self.input.mouse_y >= y and self.input.mouse_y < y + h;
    }

    pub fn isClicked(self: *const EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
        return self.input.mouse_clicked and self.isHovered(x, y, w, h);
    }

    /// Start editing a text field
    pub fn startTextInput(self: *EditorUI, field: TextFieldId, initial_text: []const u8) void {
        self.text_input.focused_field = field;
        const len = @min(initial_text.len, 63);
        @memcpy(self.text_input.input_buffer[0..len], initial_text[0..len]);
        self.text_input.input_len = @intCast(len);
        self.text_input.cursor_pos = @intCast(len);
        self.text_input.cursor_blink = 0;
    }

    /// Stop editing and return the input text
    pub fn finishTextInput(self: *EditorUI) []const u8 {
        const result = self.text_input.input_buffer[0..self.text_input.input_len];
        self.text_input.focused_field = .none;
        return result;
    }

    /// Cancel editing without saving
    pub fn cancelTextInput(self: *EditorUI) void {
        self.text_input.focused_field = .none;
        self.text_input.input_len = 0;
        self.text_input.cursor_pos = 0;
    }

    /// Get current input text
    pub fn getInputText(self: *const EditorUI) []const u8 {
        return self.text_input.input_buffer[0..self.text_input.input_len];
    }

    /// Handle a character input
    pub fn handleCharInput(self: *EditorUI, char: u8) void {
        if (self.text_input.focused_field == .none) return;
        if (char < 32 or char > 126) return; // Only printable ASCII
        if (self.text_input.input_len >= 63) return; // Buffer full

        // Insert character at cursor position
        if (self.text_input.cursor_pos < self.text_input.input_len) {
            // Shift characters to the right
            var i: u8 = self.text_input.input_len;
            while (i > self.text_input.cursor_pos) : (i -= 1) {
                self.text_input.input_buffer[i] = self.text_input.input_buffer[i - 1];
            }
        }
        self.text_input.input_buffer[self.text_input.cursor_pos] = char;
        self.text_input.input_len += 1;
        self.text_input.cursor_pos += 1;
        self.text_input.cursor_blink = 0;
    }

    /// Handle backspace
    pub fn handleBackspace(self: *EditorUI) void {
        if (self.text_input.focused_field == .none) return;
        if (self.text_input.cursor_pos == 0) return;

        // Remove character before cursor
        if (self.text_input.cursor_pos < self.text_input.input_len) {
            var i: u8 = self.text_input.cursor_pos - 1;
            while (i < self.text_input.input_len - 1) : (i += 1) {
                self.text_input.input_buffer[i] = self.text_input.input_buffer[i + 1];
            }
        }
        self.text_input.input_len -= 1;
        self.text_input.cursor_pos -= 1;
        self.text_input.cursor_blink = 0;
    }

    /// Handle delete key
    pub fn handleDelete(self: *EditorUI) void {
        if (self.text_input.focused_field == .none) return;
        if (self.text_input.cursor_pos >= self.text_input.input_len) return;

        // Remove character at cursor
        var i: u8 = self.text_input.cursor_pos;
        while (i < self.text_input.input_len - 1) : (i += 1) {
            self.text_input.input_buffer[i] = self.text_input.input_buffer[i + 1];
        }
        self.text_input.input_len -= 1;
        self.text_input.cursor_blink = 0;
    }

    /// Move cursor left
    pub fn moveCursorLeft(self: *EditorUI) void {
        if (self.text_input.cursor_pos > 0) {
            self.text_input.cursor_pos -= 1;
            self.text_input.cursor_blink = 0;
        }
    }

    /// Move cursor right
    pub fn moveCursorRight(self: *EditorUI) void {
        if (self.text_input.cursor_pos < self.text_input.input_len) {
            self.text_input.cursor_pos += 1;
            self.text_input.cursor_blink = 0;
        }
    }

    /// Move cursor to start
    pub fn moveCursorHome(self: *EditorUI) void {
        self.text_input.cursor_pos = 0;
        self.text_input.cursor_blink = 0;
    }

    /// Move cursor to end
    pub fn moveCursorEnd(self: *EditorUI) void {
        self.text_input.cursor_pos = self.text_input.input_len;
        self.text_input.cursor_blink = 0;
    }

    /// Check if currently editing text
    pub fn isEditingText(self: *const EditorUI) bool {
        return self.text_input.focused_field != .none;
    }

    /// Reset per-frame state (call at start of frame)
    pub fn beginFrame(self: *EditorUI) void {
        self.text_input.text_field_clicked_this_frame = false;
        self.input.mouse_right_clicked = false;
    }

    /// Check if we should unfocus text field (call after all UI drawing)
    pub fn shouldUnfocusTextField(self: *const EditorUI) bool {
        return self.text_input.focused_field != .none and
            self.input.mouse_clicked and
            !self.text_input.text_field_clicked_this_frame;
    }

    /// Start dragging a wave
    pub fn startDragWave(self: *EditorUI, wave_index: u16, wave_name: []const u8) void {
        self.drag.drag_type = .wave;
        self.drag.drag_wave_index = wave_index;
        self.drag.drag_start_x = self.input.mouse_x;
        self.drag.drag_start_y = self.input.mouse_y;
        self.drag.is_dragging = false; // Will become true after moving threshold

        const len = @min(wave_name.len, 63);
        @memcpy(self.drag.drag_wave_name[0..len], wave_name[0..len]);
        self.drag.drag_wave_name_len = @intCast(len);
    }

    /// Get the name of the wave being dragged
    pub fn getDragWaveName(self: *const EditorUI) []const u8 {
        return self.drag.drag_wave_name[0..self.drag.drag_wave_name_len];
    }

    /// Update drag state (call during mouse motion)
    pub fn updateDrag(self: *EditorUI) void {
        if (self.drag.drag_type == .none) return;

        // Start actual dragging after moving a threshold distance
        if (!self.drag.is_dragging) {
            const dx = self.input.mouse_x - self.drag.drag_start_x;
            const dy = self.input.mouse_y - self.drag.drag_start_y;
            const dist_sq = dx * dx + dy * dy;
            if (dist_sq > 25) { // 5 pixel threshold
                self.drag.is_dragging = true;
            }
        }
    }

    /// Cancel drag operation
    pub fn cancelDrag(self: *EditorUI) void {
        self.drag.drag_type = .none;
        self.drag.is_dragging = false;
        self.drag.drop_target = .none;
        self.drag.drop_target_pad = 0;
    }

    /// Set drop target for current drag
    pub fn setDropTarget(self: *EditorUI, target: DropTarget, pad_index: u8) void {
        self.drag.drop_target = target;
        self.drag.drop_target_pad = pad_index;
    }

    /// Clear drop target
    pub fn clearDropTarget(self: *EditorUI) void {
        self.drag.drop_target = .none;
        self.drag.drop_target_pad = 0;
    }

    /// Check if currently dragging
    pub fn isDragging(self: *const EditorUI) bool {
        return self.drag.is_dragging;
    }

    /// Handle mouse wheel scroll
    pub fn handleMouseWheel(self: *EditorUI, scroll_y: i32) void {
        const scroll_speed: i32 = 28; // 2 items per scroll tick (14px per item)

        if (self.dropdown_popup.open) {
            const item_h: i32 = 20;
            const max_visible: i32 = 8;
            const visible: i32 = @min(max_visible, @as(i32, @intCast(self.dropdown_popup.item_count)));
            const popup_h = visible * item_h + 2;
            if (self.isHovered(self.dropdown_popup.x, self.dropdown_popup.y, self.dropdown_popup.w, popup_h)) {
                self.dropdown_popup.scroll -= scroll_y * item_h;
                self.dropdown_popup.scroll = std.math.clamp(self.dropdown_popup.scroll, 0, self.dropdown_popup.max_scroll);
                return;
            }
        }

        // If sample browser is open, handle its scrolling
        if (self.show_sample_browser and self.sample_browser.max_scroll > 0) {
            self.sample_browser.scroll -= scroll_y * scroll_speed;
            self.sample_browser.scroll = std.math.clamp(self.sample_browser.scroll, 0, self.sample_browser.max_scroll);
            return;
        }

        // Check if mouse is over wave list
        if (self.isInBounds(self.scroll.wave_list_bounds)) {
            self.scroll.wave_list_scroll -= scroll_y * scroll_speed;
            self.scroll.wave_list_scroll = std.math.clamp(self.scroll.wave_list_scroll, 0, self.scroll.wave_list_max_scroll);
            return;
        }

        // Check if mouse is over kit list
        if (self.isInBounds(self.scroll.kit_list_bounds)) {
            self.scroll.kit_list_scroll -= scroll_y * scroll_speed;
            self.scroll.kit_list_scroll = std.math.clamp(self.scroll.kit_list_scroll, 0, self.scroll.kit_list_max_scroll);
            return;
        }

        // Check if mouse is over left panel
        if (self.isInBounds(self.scroll.left_panel_bounds)) {
            self.scroll.left_panel_scroll -= scroll_y * scroll_speed;
            self.scroll.left_panel_scroll = std.math.clamp(self.scroll.left_panel_scroll, 0, self.scroll.left_panel_max_scroll);
            return;
        }
    }

    /// Check if mouse is within given bounds
    fn isInBounds(self: *const EditorUI, bounds: ScrollBounds) bool {
        return self.input.mouse_x >= bounds.x and self.input.mouse_x < bounds.x + bounds.w and
            self.input.mouse_y >= bounds.y and self.input.mouse_y < bounds.y + bounds.h;
    }

    /// Open context menu for a pad at current mouse position
    pub fn openDropdown(self: *EditorUI, field_id: DropdownFieldId, anchor_x: i32, anchor_y: i32, anchor_w: i32, anchor_h: i32, item_count: usize) void {
        self.closeContextMenu();
        const popup_w = @max(anchor_w, 140);
        const item_h: i32 = 20;
        const max_visible: i32 = 8;
        const visible: i32 = @min(max_visible, @as(i32, @intCast(item_count)));
        const popup_h = visible * item_h + 2;
        const max_scroll = @as(i32, @intCast(item_count)) * item_h - popup_h + 2;
        self.dropdown_popup = .{
            .open = true,
            .field_id = field_id,
            .anchor_x = anchor_x,
            .anchor_y = anchor_y,
            .anchor_w = anchor_w,
            .anchor_h = anchor_h,
            .x = anchor_x,
            .y = anchor_y + anchor_h,
            .w = popup_w,
            .item_count = @intCast(@min(item_count, 255)),
            .scroll = 0,
            .max_scroll = @max(0, max_scroll),
        };
    }

    pub fn closeDropdown(self: *EditorUI) void {
        self.dropdown_popup.open = false;
        self.dropdown_popup.field_id = .none;
        self.dropdown_popup.scroll = 0;
    }

    pub fn openContextMenu(self: *EditorUI, pad_index: u8) void {
        self.closeDropdown();
        self.context_menu.open = true;
        self.context_menu.menu_type = .pad;
        self.context_menu.x = self.input.mouse_x;
        self.context_menu.y = self.input.mouse_y;
        self.context_menu.pad = pad_index;
    }

    /// Open context menu for a wave at current mouse position
    pub fn openWaveContextMenu(self: *EditorUI, wave_index: u16) void {
        self.closeDropdown();
        self.context_menu.open = true;
        self.context_menu.menu_type = .wave;
        self.context_menu.x = self.input.mouse_x;
        self.context_menu.y = self.input.mouse_y;
        self.context_menu.wave = wave_index;
    }

    /// Close context menu
    pub fn closeContextMenu(self: *EditorUI) void {
        self.context_menu.open = false;
        self.context_menu.menu_type = .none;
    }

    /// Copy pad to clipboard
    pub fn copyPad(self: *EditorUI, pad: *const models.Pad) void {
        self.clipboard.pad = pad.*;
    }

    /// Paste clipboard to pad
    pub fn pastePad(self: *EditorUI, pad: *models.Pad) void {
        if (self.clipboard.pad) |clip| {
            pad.* = clip;
        }
    }

    /// Check if clipboard has data
    pub fn hasClipboardData(self: *const EditorUI) bool {
        return self.clipboard.pad != null;
    }

    /// Set the startup path
    pub fn setStartupPath(self: *EditorUI, path: []const u8) void {
        self.startup_path.set(path);
    }

    /// Get the startup path
    pub fn getStartupPath(self: *const EditorUI) []const u8 {
        return self.startup_path.get();
    }

    /// Set startup error message
    pub fn setStartupError(self: *EditorUI, msg: []const u8) void {
        self.startup_error.set(msg);
    }

    /// Get startup error message
    pub fn getStartupError(self: *const EditorUI) []const u8 {
        return self.startup_error.get();
    }

    /// Clear startup error
    pub fn clearStartupError(self: *EditorUI) void {
        self.startup_error.clear();
    }

    /// Show a status message (auto-clears after a few seconds)
    pub fn showStatus(self: *EditorUI, msg: []const u8, is_error: bool) void {
        self.status_message.set(msg);
        self.status_is_error = is_error;
        self.status_timer = 4.0; // Show for 4 seconds
    }

    /// Show success message
    pub fn showSuccess(self: *EditorUI, msg: []const u8) void {
        self.showStatus(msg, false);
    }

    /// Show error message
    pub fn showError(self: *EditorUI, msg: []const u8) void {
        self.showStatus(msg, true);
    }

    /// Get current status message (empty if expired)
    pub fn getStatusMessage(self: *const EditorUI) []const u8 {
        if (self.status_timer <= 0) return "";
        return self.status_message.get();
    }

    /// Check if status is an error
    pub fn isStatusError(self: *const EditorUI) bool {
        return self.status_is_error and self.status_timer > 0;
    }

    /// Update status timer (call from update loop)
    pub fn updateStatus(self: *EditorUI, delta: f32) void {
        if (self.status_timer > 0) {
            self.status_timer -= delta;
        }
    }

    /// Transition to editor state
    pub fn enterEditor(self: *EditorUI) void {
        self.app_state = .editor;
        self.clearStartupError();
    }

    /// Check if in startup state
    pub fn isInStartup(self: *const EditorUI) bool {
        return self.app_state == .startup;
    }

    /// Return to startup state (to select a different folder)
    pub fn enterStartup(self: *EditorUI) void {
        self.app_state = .startup;
        self.clearStartupError();
    }

    /// Check if any modal is blocking input
    pub fn isModalOpen(self: *const EditorUI) bool {
        return self.show_sample_browser or self.show_midi_config or self.show_settings or self.show_kit_chain or self.show_wave_editor or self.context_menu.open or self.dropdown_popup.open;
    }

    /// Set sample browser path
    pub fn setSampleBrowserPath(self: *EditorUI, path: []const u8) void {
        self.sample_browser.setPath(path);
    }

    /// Get sample browser path
    pub fn getSampleBrowserPath(self: *const EditorUI) []const u8 {
        return self.sample_browser.getPath();
    }

    /// Set sample browser error
    pub fn setSampleBrowserError(self: *EditorUI, msg: []const u8) void {
        self.sample_browser.setError(msg);
    }

    /// Get sample browser error
    pub fn getSampleBrowserError(self: *const EditorUI) []const u8 {
        return self.sample_browser.getError();
    }

    /// Clear sample browser error
    pub fn clearSampleBrowserError(self: *EditorUI) void {
        self.sample_browser.clearError();
    }

    /// Clear sample browser file list
    pub fn clearSampleBrowserFiles(self: *EditorUI) void {
        self.sample_browser.file_count = 0;
        self.sample_browser.selected = 0;
        self.sample_browser.scroll = 0;
    }

    /// Get selected sample file entry
    pub fn getSelectedSampleFile(self: *const EditorUI) ?*const SampleFileEntry {
        return self.sample_browser.getSelectedFile();
    }

    /// Open sample browser (initializes path to home directory if not set)
    pub fn openSampleBrowser(self: *EditorUI) void {
        self.sample_browser.initializeDefaultPath();
        self.show_sample_browser = true;
    }

    /// Close sample browser
    pub fn closeSampleBrowser(self: *EditorUI) void {
        self.show_sample_browser = false;
    }

    /// Open wave editor for a specific sample
    pub fn openWaveEditor(self: *EditorUI, wave_index: u16, sample: *const models.Sample) void {
        self.wave_editor.reset();
        self.wave_editor.wave_index = wave_index;
        self.wave_editor.start_point = sample.start_point;
        self.wave_editor.end_point = sample.end_point;
        self.wave_editor.tempo = sample.tempo;
        self.wave_editor.beat = sample.beat;
        self.wave_editor.measure = sample.measure;
        self.wave_editor.tag = sample.tag;
        self.wave_editor.sample_rate = sample.sample_rate;
        self.show_wave_editor = true;
    }

    /// Close wave editor
    pub fn closeWaveEditor(self: *EditorUI) void {
        self.show_wave_editor = false;
        self.wave_editor.reset();
    }

    /// Apply wave editor changes to sample
    pub fn applyWaveEditorChanges(self: *EditorUI, sample: *models.Sample) void {
        sample.start_point = self.wave_editor.start_point;
        sample.end_point = self.wave_editor.end_point;
        sample.tempo = self.wave_editor.tempo;
        sample.beat = self.wave_editor.beat;
        sample.measure = self.wave_editor.measure;
        sample.tag = self.wave_editor.tag;
    }

    /// Mark sample usage cache as dirty (call when pad samples change)
    pub fn invalidateSampleUsageCache(self: *EditorUI) void {
        self.sample_usage_dirty = true;
    }

    /// Update sample usage cache from project data
    pub fn updateSampleUsageCache(self: *EditorUI, project: *models.Project) void {
        if (!self.sample_usage_dirty) return;

        const library = &project.sample_library;

        // Clear cache
        @memset(&self.sample_usage_cache, false);

        // Mark all samples that are used by any pad
        var kit_idx: u8 = 0;
        while (kit_idx < project.kit_count) : (kit_idx += 1) {
            const kit = &project.kits[kit_idx];
            for (&kit.pads) |*pad| {
                if (pad.has_sample) {
                    const pad_path = pad.sample.getPath();
                    if (pad_path.len > 0) {
                        if (library.findByPath(pad_path)) |sample_idx| {
                            self.sample_usage_cache[sample_idx] = true;
                        }
                    }
                }
                if (pad.has_sub_sample) {
                    const sub_path = pad.sub_sample.getPath();
                    if (sub_path.len > 0) {
                        if (library.findByPath(sub_path)) |sample_idx| {
                            self.sample_usage_cache[sample_idx] = true;
                        }
                    }
                }
            }
        }

        self.sample_usage_dirty = false;
    }

    /// Check if a sample is used (uses cached value)
    pub fn isSampleUsed(self: *const EditorUI, sample_index: u16) bool {
        if (sample_index >= models.SampleLibrary.MAX_SAMPLES) return false;
        return self.sample_usage_cache[sample_index];
    }
};
