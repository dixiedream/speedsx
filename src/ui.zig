const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;
const models = @import("models.zig");

// Simple 4x6 embedded font (ASCII 32-126)
// Each character is stored as 3 bytes (24 bits for 4x6 grid)
const CHAR_WIDTH = 4;
const CHAR_HEIGHT = 6;
const CHAR_SPACING = 1;

// Font data: 4 columns x 6 rows, packed row-major into 3 bytes per char
const font_data = [95][3]u8{
    // Space (32)
    .{ 0x00, 0x00, 0x00 },
    // ! (33)
    .{ 0x44, 0x44, 0x04 },
    // " (34)
    .{ 0xAA, 0x00, 0x00 },
    // # (35)
    .{ 0xAF, 0xAF, 0xA0 },
    // $ (36)
    .{ 0x6C, 0x46, 0xC4 },
    // % (37)
    .{ 0x92, 0x44, 0x92 },
    // & (38)
    .{ 0x4A, 0x4A, 0x50 },
    // ' (39)
    .{ 0x44, 0x00, 0x00 },
    // ( (40)
    .{ 0x24, 0x44, 0x42 },
    // ) (41)
    .{ 0x42, 0x22, 0x24 },
    // * (42)
    .{ 0x0A, 0x4A, 0x00 },
    // + (43)
    .{ 0x04, 0xE4, 0x00 },
    // , (44)
    .{ 0x00, 0x00, 0x24 },
    // - (45)
    .{ 0x00, 0xE0, 0x00 },
    // . (46)
    .{ 0x00, 0x00, 0x04 },
    // / (47)
    .{ 0x12, 0x44, 0x80 },
    // 0 (48)
    .{ 0x6B, 0xDB, 0x60 },
    // 1 (49)
    .{ 0x26, 0x22, 0x27 },
    // 2 (50)
    .{ 0x69, 0x24, 0x8F },
    // 3 (51)
    .{ 0xE1, 0x21, 0x1E },
    // 4 (52)
    .{ 0x99, 0xF1, 0x10 },
    // 5 (53)
    .{ 0xF8, 0xE1, 0x1E },
    // 6 (54)
    .{ 0x68, 0xE9, 0x96 },
    // 7 (55)
    .{ 0xF1, 0x24, 0x44 },
    // 8 (56)
    .{ 0x69, 0x69, 0x96 },
    // 9 (57)
    .{ 0x69, 0x71, 0x16 },
    // : (58)
    .{ 0x04, 0x04, 0x00 },
    // ; (59)
    .{ 0x04, 0x04, 0x24 },
    // < (60)
    .{ 0x12, 0x42, 0x10 },
    // = (61)
    .{ 0x0E, 0x0E, 0x00 },
    // > (62)
    .{ 0x42, 0x12, 0x40 },
    // ? (63)
    .{ 0x69, 0x20, 0x02 },
    // @ (64)
    .{ 0x6B, 0xB8, 0x60 },
    // A (65)
    .{ 0x69, 0xF9, 0x90 },
    // B (66)
    .{ 0xE9, 0xE9, 0x9E },
    // C (67)
    .{ 0x68, 0x88, 0x86 },
    // D (68)
    .{ 0xE9, 0x99, 0x9E },
    // E (69)
    .{ 0xF8, 0xE8, 0x8F },
    // F (70)
    .{ 0xF8, 0xE8, 0x88 },
    // G (71)
    .{ 0x68, 0xB9, 0x96 },
    // H (72)
    .{ 0x99, 0xF9, 0x99 },
    // I (73)
    .{ 0xE4, 0x44, 0x4E },
    // J (74)
    .{ 0x71, 0x11, 0x96 },
    // K (75)
    .{ 0x9A, 0xCA, 0x99 },
    // L (76)
    .{ 0x88, 0x88, 0x8F },
    // M (77)
    .{ 0x9F, 0x99, 0x99 },
    // N (78)
    .{ 0x9D, 0xBB, 0x99 },
    // O (79)
    .{ 0x69, 0x99, 0x96 },
    // P (80)
    .{ 0xE9, 0x9E, 0x88 },
    // Q (81)
    .{ 0x69, 0x9B, 0x65 },
    // R (82)
    .{ 0xE9, 0x9E, 0xA9 },
    // S (83)
    .{ 0x78, 0x61, 0x1E },
    // T (84)
    .{ 0xE4, 0x44, 0x44 },
    // U (85)
    .{ 0x99, 0x99, 0x96 },
    // V (86)
    .{ 0x99, 0x99, 0x66 },
    // W (87)
    .{ 0x99, 0x99, 0xF9 },
    // X (88)
    .{ 0x99, 0x69, 0x99 },
    // Y (89)
    .{ 0x99, 0x64, 0x44 },
    // Z (90)
    .{ 0xF1, 0x24, 0x8F },
    // [ (91)
    .{ 0x64, 0x44, 0x46 },
    // \ (92)
    .{ 0x84, 0x42, 0x21 },
    // ] (93)
    .{ 0x62, 0x22, 0x26 },
    // ^ (94)
    .{ 0x4A, 0x00, 0x00 },
    // _ (95)
    .{ 0x00, 0x00, 0x0F },
    // ` (96)
    .{ 0x42, 0x00, 0x00 },
    // a (97)
    .{ 0x06, 0x99, 0x97 },
    // b (98)
    .{ 0x88, 0xE9, 0x9E },
    // c (99)
    .{ 0x06, 0x88, 0x86 },
    // d (100)
    .{ 0x11, 0x79, 0x97 },
    // e (101)
    .{ 0x06, 0x9E, 0x86 },
    // f (102)
    .{ 0x24, 0xE4, 0x44 },
    // g (103)
    .{ 0x07, 0x97, 0x16 },
    // h (104)
    .{ 0x88, 0xE9, 0x99 },
    // i (105)
    .{ 0x40, 0x44, 0x44 },
    // j (106)
    .{ 0x10, 0x11, 0x16 },
    // k (107)
    .{ 0x89, 0xAC, 0xA9 },
    // l (108)
    .{ 0x44, 0x44, 0x42 },
    // m (109)
    .{ 0x0F, 0x99, 0x99 },
    // n (110)
    .{ 0x0E, 0x99, 0x99 },
    // o (111)
    .{ 0x06, 0x99, 0x96 },
    // p (112)
    .{ 0x0E, 0x99, 0xE8 },
    // q (113)
    .{ 0x07, 0x99, 0x71 },
    // r (114)
    .{ 0x0B, 0x48, 0x88 },
    // s (115)
    .{ 0x07, 0x86, 0x1E },
    // t (116)
    .{ 0x4E, 0x44, 0x42 },
    // u (117)
    .{ 0x09, 0x99, 0x97 },
    // v (118)
    .{ 0x09, 0x99, 0x66 },
    // w (119)
    .{ 0x09, 0x99, 0x9F },
    // x (120)
    .{ 0x09, 0x66, 0x99 },
    // y (121)
    .{ 0x09, 0x97, 0x16 },
    // z (122)
    .{ 0x0F, 0x24, 0x8F },
    // { (123)
    .{ 0x24, 0x84, 0x42 },
    // | (124)
    .{ 0x44, 0x44, 0x44 },
    // } (125)
    .{ 0x42, 0x14, 0x24 },
    // ~ (126)
    .{ 0x05, 0xA0, 0x00 },
};

// Color scheme (dark theme)
pub const Colors = struct {
    pub const background: u32 = 0xFF1A1A1E; // Dark background
    pub const panel: u32 = 0xFF252528; // Dark panel
    pub const panel_light: u32 = 0xFF303035; // Slightly lighter panel
    pub const accent: u32 = 0xFF5090E0; // Blue accent
    pub const accent_hover: u32 = 0xFF70B0FF;
    pub const accent_dark: u32 = 0xFF3070C0;
    pub const text: u32 = 0xFFE8E8EC; // Light text
    pub const text_dim: u32 = 0xFF808088; // Dimmed text
    pub const pad_empty: u32 = 0xFF2A2A30; // Empty pad
    pub const pad_loaded: u32 = 0xFFA02828; // Loaded pad (dark red)
    pub const pad_playing: u32 = 0xFF28A028; // Playing flash (green)
    pub const pad_selected: u32 = 0xFFE04040; // Selected pad border (red)
    pub const border: u32 = 0xFF404048; // Dark border
    pub const slider_bg: u32 = 0xFF1E1E22; // Slider background
    pub const slider_fill: u32 = 0xFF4080D0; // Slider fill (blue)
    pub const button_green: u32 = 0xFF2A8A2A; // Green button (Open)

    pub fn setRenderColor(renderer: *c.SDL_Renderer, col: u32) void {
        _ = c.SDL_SetRenderDrawColor(
            renderer,
            @truncate((col >> 16) & 0xFF),
            @truncate((col >> 8) & 0xFF),
            @truncate(col & 0xFF),
            @truncate((col >> 24) & 0xFF),
        );
    }
};

/// Text field identifiers
pub const TextFieldId = enum {
    none,
    kit_name,
    kit_sub_name,
    kit_tempo,
    startup_path,
    sample_browser_path,
};

/// Drag and drop types
pub const DragType = enum {
    none,
    wave, // Dragging a wave/sample
};

/// Drop target type
pub const DropTarget = enum {
    none,
    pad_main, // Drop as main wave
    pad_sub, // Drop as sub wave
};

/// Application state enum
pub const AppState = enum {
    startup, // Startup screen - choose configuration path
    editor, // Main editor view
};

/// UI state for the editor
pub const EditorUI = struct {
    // Application state
    app_state: AppState = .startup,
    startup_path: [256]u8 = [_]u8{0} ** 256,
    startup_path_len: u16 = 0,
    startup_error: [128]u8 = [_]u8{0} ** 128,
    startup_error_len: u8 = 0,

    selected_pad: u8 = 0,
    selected_kit: u8 = 0,
    selected_wave: u16 = 0, // Selected wave in wave list
    show_kit_browser: bool = true,
    show_sample_browser: bool = false,
    show_settings: bool = false,
    show_midi_config: bool = false,
    show_wave_list: bool = true,
    show_kit_list: bool = true,
    show_device_view: bool = true,
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,
    mouse_down: bool = false,
    mouse_clicked: bool = false,
    mouse_right_clicked: bool = false,
    pad_flash: [9]f32 = [_]f32{0} ** 9,
    is_playing: bool = false,
    wave_list_scroll: i32 = 0,
    kit_list_scroll: i32 = 0,

    // Text input state
    focused_field: TextFieldId = .none,
    input_buffer: [64]u8 = [_]u8{0} ** 64,
    input_len: u8 = 0,
    cursor_pos: u8 = 0,
    cursor_blink: f32 = 0,
    text_field_clicked_this_frame: bool = false,

    // Drag and drop state
    drag_type: DragType = .none,
    drag_wave_index: u16 = 0,
    drag_wave_name: [64]u8 = [_]u8{0} ** 64,
    drag_wave_name_len: u8 = 0,
    drag_start_x: i32 = 0,
    drag_start_y: i32 = 0,
    is_dragging: bool = false,
    drop_target: DropTarget = .none,
    drop_target_pad: u8 = 0,

    // Scroll bounds (set by list panels during draw)
    wave_list_bounds: ScrollBounds = .{},
    kit_list_bounds: ScrollBounds = .{},
    wave_list_max_scroll: i32 = 0,
    kit_list_max_scroll: i32 = 0,

    // Context menu state
    context_menu_open: bool = false,
    context_menu_x: i32 = 0,
    context_menu_y: i32 = 0,
    context_menu_pad: u8 = 0,

    // Pad clipboard
    clipboard_pad: ?models.Pad = null,
    clipboard_has_data: bool = false,

    // Sample browser state
    sample_browser_path: [256]u8 = [_]u8{0} ** 256,
    sample_browser_path_len: u16 = 0,
    sample_browser_files: [128]SampleFileEntry = undefined,
    sample_browser_file_count: u16 = 0,
    sample_browser_selected: u16 = 0,
    sample_browser_scroll: i32 = 0,
    sample_browser_max_scroll: i32 = 0,
    sample_browser_scanning: bool = false,
    sample_browser_error: [64]u8 = [_]u8{0} ** 64,
    sample_browser_error_len: u8 = 0,

    pub const SampleFileEntry = struct {
        name: [64]u8 = [_]u8{0} ** 64,
        name_len: u8 = 0,
        path: [256]u8 = [_]u8{0} ** 256,
        path_len: u16 = 0,

        pub fn getName(self: *const SampleFileEntry) []const u8 {
            return self.name[0..self.name_len];
        }

        pub fn getPath(self: *const SampleFileEntry) []const u8 {
            return self.path[0..self.path_len];
        }
    };

    pub const ScrollBounds = struct {
        x: i32 = 0,
        y: i32 = 0,
        w: i32 = 0,
        h: i32 = 0,
    };

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
        self.cursor_blink += delta * 2.0;
        if (self.cursor_blink > 1.0) {
            self.cursor_blink -= 1.0;
        }
    }

    pub fn triggerPadFlash(self: *EditorUI, pad_index: u8) void {
        if (pad_index < 9) {
            self.pad_flash[pad_index] = 1.0;
        }
    }

    pub fn isHovered(self: *const EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
        return self.mouse_x >= x and self.mouse_x < x + w and
            self.mouse_y >= y and self.mouse_y < y + h;
    }

    pub fn isClicked(self: *const EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
        return self.mouse_clicked and self.isHovered(x, y, w, h);
    }

    pub fn togglePlay(self: *EditorUI) void {
        self.is_playing = !self.is_playing;
    }

    pub fn stop(self: *EditorUI) void {
        self.is_playing = false;
    }

    /// Start editing a text field
    pub fn startTextInput(self: *EditorUI, field: TextFieldId, initial_text: []const u8) void {
        self.focused_field = field;
        const len = @min(initial_text.len, 63);
        @memcpy(self.input_buffer[0..len], initial_text[0..len]);
        self.input_len = @intCast(len);
        self.cursor_pos = @intCast(len);
        self.cursor_blink = 0;
    }

    /// Stop editing and return the input text
    pub fn finishTextInput(self: *EditorUI) []const u8 {
        const result = self.input_buffer[0..self.input_len];
        self.focused_field = .none;
        return result;
    }

    /// Cancel editing without saving
    pub fn cancelTextInput(self: *EditorUI) void {
        self.focused_field = .none;
        self.input_len = 0;
        self.cursor_pos = 0;
    }

    /// Get current input text
    pub fn getInputText(self: *const EditorUI) []const u8 {
        return self.input_buffer[0..self.input_len];
    }

    /// Handle a character input
    pub fn handleCharInput(self: *EditorUI, char: u8) void {
        if (self.focused_field == .none) return;
        if (char < 32 or char > 126) return; // Only printable ASCII
        if (self.input_len >= 63) return; // Buffer full

        // Insert character at cursor position
        if (self.cursor_pos < self.input_len) {
            // Shift characters to the right
            var i: u8 = self.input_len;
            while (i > self.cursor_pos) : (i -= 1) {
                self.input_buffer[i] = self.input_buffer[i - 1];
            }
        }
        self.input_buffer[self.cursor_pos] = char;
        self.input_len += 1;
        self.cursor_pos += 1;
        self.cursor_blink = 0;
    }

    /// Handle backspace
    pub fn handleBackspace(self: *EditorUI) void {
        if (self.focused_field == .none) return;
        if (self.cursor_pos == 0) return;

        // Remove character before cursor
        if (self.cursor_pos < self.input_len) {
            var i: u8 = self.cursor_pos - 1;
            while (i < self.input_len - 1) : (i += 1) {
                self.input_buffer[i] = self.input_buffer[i + 1];
            }
        }
        self.input_len -= 1;
        self.cursor_pos -= 1;
        self.cursor_blink = 0;
    }

    /// Handle delete key
    pub fn handleDelete(self: *EditorUI) void {
        if (self.focused_field == .none) return;
        if (self.cursor_pos >= self.input_len) return;

        // Remove character at cursor
        var i: u8 = self.cursor_pos;
        while (i < self.input_len - 1) : (i += 1) {
            self.input_buffer[i] = self.input_buffer[i + 1];
        }
        self.input_len -= 1;
        self.cursor_blink = 0;
    }

    /// Move cursor left
    pub fn moveCursorLeft(self: *EditorUI) void {
        if (self.cursor_pos > 0) {
            self.cursor_pos -= 1;
            self.cursor_blink = 0;
        }
    }

    /// Move cursor right
    pub fn moveCursorRight(self: *EditorUI) void {
        if (self.cursor_pos < self.input_len) {
            self.cursor_pos += 1;
            self.cursor_blink = 0;
        }
    }

    /// Move cursor to start
    pub fn moveCursorHome(self: *EditorUI) void {
        self.cursor_pos = 0;
        self.cursor_blink = 0;
    }

    /// Move cursor to end
    pub fn moveCursorEnd(self: *EditorUI) void {
        self.cursor_pos = self.input_len;
        self.cursor_blink = 0;
    }

    /// Check if currently editing text
    pub fn isEditingText(self: *const EditorUI) bool {
        return self.focused_field != .none;
    }

    /// Reset per-frame state (call at start of frame)
    pub fn beginFrame(self: *EditorUI) void {
        self.text_field_clicked_this_frame = false;
        self.mouse_right_clicked = false;
    }

    /// Check if we should unfocus text field (call after all UI drawing)
    pub fn shouldUnfocusTextField(self: *const EditorUI) bool {
        return self.focused_field != .none and
            self.mouse_clicked and
            !self.text_field_clicked_this_frame;
    }

    /// Start dragging a wave
    pub fn startDragWave(self: *EditorUI, wave_index: u16, wave_name: []const u8) void {
        self.drag_type = .wave;
        self.drag_wave_index = wave_index;
        self.drag_start_x = self.mouse_x;
        self.drag_start_y = self.mouse_y;
        self.is_dragging = false; // Will become true after moving threshold

        const len = @min(wave_name.len, 63);
        @memcpy(self.drag_wave_name[0..len], wave_name[0..len]);
        self.drag_wave_name_len = @intCast(len);
    }

    /// Get the name of the wave being dragged
    pub fn getDragWaveName(self: *const EditorUI) []const u8 {
        return self.drag_wave_name[0..self.drag_wave_name_len];
    }

    /// Update drag state (call during mouse motion)
    pub fn updateDrag(self: *EditorUI) void {
        if (self.drag_type == .none) return;

        // Start actual dragging after moving a threshold distance
        if (!self.is_dragging) {
            const dx = self.mouse_x - self.drag_start_x;
            const dy = self.mouse_y - self.drag_start_y;
            const dist_sq = dx * dx + dy * dy;
            if (dist_sq > 25) { // 5 pixel threshold
                self.is_dragging = true;
            }
        }
    }

    /// Cancel drag operation
    pub fn cancelDrag(self: *EditorUI) void {
        self.drag_type = .none;
        self.is_dragging = false;
        self.drop_target = .none;
        self.drop_target_pad = 0;
    }

    /// Complete drag operation and return if a drop occurred
    pub fn endDrag(self: *EditorUI) bool {
        const was_dragging = self.is_dragging and self.drop_target != .none;
        if (!was_dragging) {
            self.cancelDrag();
        }
        return was_dragging;
    }

    /// Set drop target for current drag
    pub fn setDropTarget(self: *EditorUI, target: DropTarget, pad_index: u8) void {
        self.drop_target = target;
        self.drop_target_pad = pad_index;
    }

    /// Clear drop target
    pub fn clearDropTarget(self: *EditorUI) void {
        self.drop_target = .none;
        self.drop_target_pad = 0;
    }

    /// Check if currently dragging
    pub fn isDragging(self: *const EditorUI) bool {
        return self.is_dragging;
    }

    /// Handle mouse wheel scroll
    pub fn handleMouseWheel(self: *EditorUI, scroll_y: i32) void {
        const scroll_speed: i32 = 28; // 2 items per scroll tick (14px per item)

        // If sample browser is open, handle its scrolling
        if (self.show_sample_browser and self.sample_browser_max_scroll > 0) {
            self.sample_browser_scroll -= scroll_y * scroll_speed;
            self.sample_browser_scroll = std.math.clamp(self.sample_browser_scroll, 0, self.sample_browser_max_scroll);
            return;
        }

        // Check if mouse is over wave list
        if (self.isInBounds(self.wave_list_bounds)) {
            self.wave_list_scroll -= scroll_y * scroll_speed;
            self.wave_list_scroll = std.math.clamp(self.wave_list_scroll, 0, self.wave_list_max_scroll);
            return;
        }

        // Check if mouse is over kit list
        if (self.isInBounds(self.kit_list_bounds)) {
            self.kit_list_scroll -= scroll_y * scroll_speed;
            self.kit_list_scroll = std.math.clamp(self.kit_list_scroll, 0, self.kit_list_max_scroll);
            return;
        }
    }

    /// Check if mouse is within given bounds
    fn isInBounds(self: *const EditorUI, bounds: ScrollBounds) bool {
        return self.mouse_x >= bounds.x and self.mouse_x < bounds.x + bounds.w and
            self.mouse_y >= bounds.y and self.mouse_y < bounds.y + bounds.h;
    }

    /// Open context menu at current mouse position
    pub fn openContextMenu(self: *EditorUI, pad_index: u8) void {
        self.context_menu_open = true;
        self.context_menu_x = self.mouse_x;
        self.context_menu_y = self.mouse_y;
        self.context_menu_pad = pad_index;
    }

    /// Close context menu
    pub fn closeContextMenu(self: *EditorUI) void {
        self.context_menu_open = false;
    }

    /// Copy pad to clipboard
    pub fn copyPad(self: *EditorUI, pad: *const models.Pad) void {
        self.clipboard_pad = pad.*;
        self.clipboard_has_data = true;
    }

    /// Paste clipboard to pad
    pub fn pastePad(self: *EditorUI, pad: *models.Pad) void {
        if (self.clipboard_pad) |clipboard| {
            pad.* = clipboard;
        }
    }

    /// Check if clipboard has data
    pub fn hasClipboardData(self: *const EditorUI) bool {
        return self.clipboard_has_data and self.clipboard_pad != null;
    }

    /// Set the startup path
    pub fn setStartupPath(self: *EditorUI, path: []const u8) void {
        const len = @min(path.len, 255);
        @memcpy(self.startup_path[0..len], path[0..len]);
        self.startup_path_len = @intCast(len);
    }

    /// Get the startup path
    pub fn getStartupPath(self: *const EditorUI) []const u8 {
        return self.startup_path[0..self.startup_path_len];
    }

    /// Set startup error message
    pub fn setStartupError(self: *EditorUI, msg: []const u8) void {
        const len = @min(msg.len, 127);
        @memcpy(self.startup_error[0..len], msg[0..len]);
        self.startup_error_len = @intCast(len);
    }

    /// Get startup error message
    pub fn getStartupError(self: *const EditorUI) []const u8 {
        return self.startup_error[0..self.startup_error_len];
    }

    /// Clear startup error
    pub fn clearStartupError(self: *EditorUI) void {
        self.startup_error_len = 0;
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

    /// Set sample browser path
    pub fn setSampleBrowserPath(self: *EditorUI, path: []const u8) void {
        const len = @min(path.len, 255);
        @memcpy(self.sample_browser_path[0..len], path[0..len]);
        self.sample_browser_path_len = @intCast(len);
    }

    /// Get sample browser path
    pub fn getSampleBrowserPath(self: *const EditorUI) []const u8 {
        return self.sample_browser_path[0..self.sample_browser_path_len];
    }

    /// Set sample browser error
    pub fn setSampleBrowserError(self: *EditorUI, msg: []const u8) void {
        const len = @min(msg.len, 63);
        @memcpy(self.sample_browser_error[0..len], msg[0..len]);
        self.sample_browser_error_len = @intCast(len);
    }

    /// Get sample browser error
    pub fn getSampleBrowserError(self: *const EditorUI) []const u8 {
        return self.sample_browser_error[0..self.sample_browser_error_len];
    }

    /// Clear sample browser error
    pub fn clearSampleBrowserError(self: *EditorUI) void {
        self.sample_browser_error_len = 0;
    }

    /// Clear sample browser file list
    pub fn clearSampleBrowserFiles(self: *EditorUI) void {
        self.sample_browser_file_count = 0;
        self.sample_browser_selected = 0;
        self.sample_browser_scroll = 0;
    }

    /// Add a file to sample browser list
    pub fn addSampleBrowserFile(self: *EditorUI, name: []const u8, path: []const u8) bool {
        if (self.sample_browser_file_count >= 128) return false;

        var entry = &self.sample_browser_files[self.sample_browser_file_count];
        const name_len = @min(name.len, 63);
        @memcpy(entry.name[0..name_len], name[0..name_len]);
        entry.name_len = @intCast(name_len);

        const path_len = @min(path.len, 255);
        @memcpy(entry.path[0..path_len], path[0..path_len]);
        entry.path_len = @intCast(path_len);

        self.sample_browser_file_count += 1;
        return true;
    }

    /// Get selected sample file entry
    pub fn getSelectedSampleFile(self: *const EditorUI) ?*const SampleFileEntry {
        if (self.sample_browser_selected >= self.sample_browser_file_count) return null;
        return &self.sample_browser_files[self.sample_browser_selected];
    }
};

/// SDL2 Renderer wrapper with bitmap font
pub const Renderer = struct {
    sdl_renderer: *c.SDL_Renderer,

    pub fn init(sdl_renderer: *c.SDL_Renderer) Renderer {
        return .{ .sdl_renderer = sdl_renderer };
    }

    pub fn deinit(self: *Renderer) void {
        _ = self;
    }

    pub fn clear(self: *Renderer) void {
        Colors.setRenderColor(self.sdl_renderer, Colors.background);
        _ = c.SDL_RenderClear(self.sdl_renderer);
    }

    pub fn present(self: *Renderer) void {
        c.SDL_RenderPresent(self.sdl_renderer);
    }

    pub fn fillRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, col: u32) void {
        Colors.setRenderColor(self.sdl_renderer, col);
        const rect = c.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = c.SDL_RenderFillRect(self.sdl_renderer, &rect);
    }

    pub fn drawRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, col: u32) void {
        Colors.setRenderColor(self.sdl_renderer, col);
        const rect = c.SDL_Rect{ .x = x, .y = y, .w = w, .h = h };
        _ = c.SDL_RenderDrawRect(self.sdl_renderer, &rect);
    }

    pub fn drawRoundedRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, col: u32, filled: bool) void {
        if (filled) {
            self.fillRect(x, y, w, h, col);
        } else {
            self.drawRect(x, y, w, h, col);
        }
    }

    /// Draw a character using embedded bitmap font
    fn drawChar(self: *Renderer, char: u8, x: i32, y: i32, col: u32, scale: i32) void {
        if (char < 32 or char > 126) return;

        const char_index: usize = char - 32;
        const data = font_data[char_index];

        Colors.setRenderColor(self.sdl_renderer, col);

        // Decode the 3 bytes into 4x6 pixel grid
        // Each nibble represents one column of 6 pixels
        var bit_index: usize = 0;
        for (0..CHAR_HEIGHT) |row| {
            for (0..CHAR_WIDTH) |column| {
                const byte_idx = bit_index / 8;
                const bit_pos: u3 = @truncate(7 - (bit_index % 8));

                if (byte_idx < 3 and ((data[byte_idx] >> bit_pos) & 1) == 1) {
                    const px = x + @as(i32, @intCast(column)) * scale;
                    const py = y + @as(i32, @intCast(row)) * scale;
                    const rect = c.SDL_Rect{ .x = px, .y = py, .w = scale, .h = scale };
                    _ = c.SDL_RenderFillRect(self.sdl_renderer, &rect);
                }
                bit_index += 1;
            }
        }
    }

    pub fn drawText(self: *Renderer, text: []const u8, x: i32, y: i32, col: u32) void {
        self.drawTextScaled(text, x, y, col, 2);
    }

    pub fn drawTextSmall(self: *Renderer, text: []const u8, x: i32, y: i32, col: u32) void {
        self.drawTextScaled(text, x, y, col, 1);
    }

    pub fn drawTextLarge(self: *Renderer, text: []const u8, x: i32, y: i32, col: u32) void {
        self.drawTextScaled(text, x, y, col, 3);
    }

    fn drawTextScaled(self: *Renderer, text: []const u8, x: i32, y: i32, col: u32, scale: i32) void {
        var cursor_x = x;
        for (text) |char| {
            self.drawChar(char, cursor_x, y, col, scale);
            cursor_x += (CHAR_WIDTH + CHAR_SPACING) * scale;
        }
    }

    pub fn measureText(self: *Renderer, text: []const u8) i32 {
        _ = self;
        return @intCast(text.len * (CHAR_WIDTH + CHAR_SPACING) * 2);
    }

    pub fn measureTextSmall(self: *Renderer, text: []const u8) i32 {
        _ = self;
        return @intCast(text.len * (CHAR_WIDTH + CHAR_SPACING));
    }
};

/// Draw a styled button
pub fn drawButton(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, text: []const u8, enabled: bool) bool {
    const hovered = ui.isHovered(x, y, w, h);
    const clicked = enabled and ui.isClicked(x, y, w, h);

    var bg_color = if (enabled) Colors.panel_light else Colors.panel;
    if (hovered and enabled) bg_color = Colors.accent_dark;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);

    const text_color = if (enabled) Colors.text else Colors.text_dim;
    const text_width = r.measureTextSmall(text);
    r.drawTextSmall(text, x + @divFloor(w - text_width, 2), y + @divFloor(h - 6, 2), text_color);

    return clicked;
}

/// Draw a slider
pub fn drawSlider(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, value: *u8, min_val: u8, max_val: u8, label: []const u8) void {
    r.drawTextSmall(label, x, y - 10, Colors.text_dim);
    r.drawRoundedRect(x, y, w, h, Colors.slider_bg, true);

    const range: f32 = @floatFromInt(max_val - min_val);
    const normalized = @as(f32, @floatFromInt(value.* - min_val)) / range;
    const fill_width: i32 = @intFromFloat(normalized * @as(f32, @floatFromInt(w)));

    if (fill_width > 0) {
        r.fillRect(x, y, fill_width, h, Colors.slider_fill);
    }

    if (ui.isHovered(x, y, w, h) and ui.mouse_down) {
        const relative_x: f32 = @floatFromInt(ui.mouse_x - x);
        const new_normalized = std.math.clamp(relative_x / @as(f32, @floatFromInt(w)), 0, 1);
        value.* = @intFromFloat(new_normalized * range + @as(f32, @floatFromInt(min_val)));
    }

    var buf: [8]u8 = undefined;
    const val_str = std.fmt.bufPrint(&buf, "{d}", .{value.*}) catch "?";
    r.drawTextSmall(val_str, x + w + 8, y + 2, Colors.text);
}

/// Draw signed slider
pub fn drawSignedSlider(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, value: *i8, min_val: i8, max_val: i8, label: []const u8) void {
    r.drawTextSmall(label, x, y - 10, Colors.text_dim);
    r.drawRoundedRect(x, y, w, h, Colors.slider_bg, true);

    const center_x = x + @divFloor(w, 2);
    r.fillRect(center_x, y + 2, 1, h - 4, Colors.border);

    const range: f32 = @floatFromInt(max_val - min_val);
    const normalized = (@as(f32, @floatFromInt(value.*)) - @as(f32, @floatFromInt(min_val))) / range;
    const pos_x: i32 = x + @as(i32, @intFromFloat(normalized * @as(f32, @floatFromInt(w))));

    const fill_x = @min(center_x, pos_x);
    const fill_w = @max(center_x, pos_x) - fill_x;
    if (fill_w > 0) {
        r.fillRect(fill_x, y, fill_w, h, Colors.slider_fill);
    }

    if (ui.isHovered(x, y, w, h) and ui.mouse_down) {
        const relative_x: f32 = @floatFromInt(ui.mouse_x - x);
        const new_normalized = std.math.clamp(relative_x / @as(f32, @floatFromInt(w)), 0, 1);
        value.* = @intFromFloat(new_normalized * range + @as(f32, @floatFromInt(min_val)));
    }

    var buf: [8]u8 = undefined;
    const val_str = std.fmt.bufPrint(&buf, "{d}", .{value.*}) catch "?";
    r.drawTextSmall(val_str, x + w + 8, y + 2, Colors.text);
}

/// Draw dropdown
pub fn drawDropdown(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, current_text: []const u8, label: []const u8) bool {
    r.drawTextSmall(label, x, y - 10, Colors.text_dim);

    const hovered = ui.isHovered(x, y, w, h);
    const bg_color = if (hovered) Colors.panel_light else Colors.panel;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);
    r.drawTextSmall(current_text, x + 6, y + @divFloor(h - 6, 2), Colors.text);
    r.drawTextSmall("v", x + w - 10, y + @divFloor(h - 6, 2), Colors.text_dim);

    return ui.isClicked(x, y, w, h);
}

/// Draw toggle
pub fn drawToggle(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, value: *bool, label: []const u8) void {
    const toggle_w: i32 = 36;
    const toggle_h: i32 = 16;

    r.drawTextSmall(label, x + toggle_w + 8, y + 4, Colors.text);

    if (ui.isClicked(x, y, toggle_w, toggle_h)) {
        value.* = !value.*;
    }

    const bg_color = if (value.*) Colors.accent else Colors.slider_bg;
    r.drawRoundedRect(x, y, toggle_w, toggle_h, bg_color, true);

    const knob_x: i32 = if (value.*) x + toggle_w - toggle_h + 2 else x + 2;
    r.fillRect(knob_x, y + 2, toggle_h - 4, toggle_h - 4, Colors.text);
}

/// Draw a single pad with drag and drop support
pub fn drawPad(r: *Renderer, ui: *EditorUI, x: i32, y: i32, size: i32, pad: *const models.Pad, index: u8) bool {
    const hovered = ui.isHovered(x, y, size, size);
    const clicked = ui.isClicked(x, y, size, size);
    const right_clicked = ui.mouse_right_clicked and hovered;
    const is_selected = ui.selected_pad == index;

    // Handle right-click to open context menu
    if (right_clicked and !ui.context_menu_open) {
        ui.openContextMenu(index);
    }

    // Check if this pad is a drop target
    const is_drop_target = ui.isDragging() and hovered;
    const half_size = @divFloor(size, 2);

    // Determine if hovering over main (top) or sub (bottom) drop zone
    const in_main_zone = ui.mouse_y < y + half_size;
    const current_drop_type: DropTarget = if (is_drop_target)
        (if (in_main_zone) .pad_main else .pad_sub)
    else
        .none;

    // Update drop target in UI state
    if (is_drop_target) {
        ui.setDropTarget(current_drop_type, index);
    }

    var bg_color = if (pad.has_sample) Colors.pad_loaded else Colors.pad_empty;

    if (ui.pad_flash[index] > 0) {
        bg_color = lerpColor(bg_color, Colors.pad_playing, ui.pad_flash[index]);
    }

    if (hovered and !ui.isDragging()) {
        bg_color = lightenColor(bg_color, 0.15);
    }

    r.drawRoundedRect(x, y, size, size, bg_color, true);

    // Draw drop zone indicators when dragging over this pad
    if (is_drop_target) {
        // Main wave zone (top half)
        const main_zone_color: u32 = if (in_main_zone) Colors.accent else Colors.panel_light;
        r.fillRect(x + 2, y + 2, size - 4, half_size - 4, main_zone_color);
        r.drawTextSmall("MAIN", x + @divFloor(size, 2) - 12, y + @divFloor(half_size, 2) - 3, Colors.text);

        // Sub wave zone (bottom half)
        const sub_zone_color: u32 = if (!in_main_zone) Colors.accent else Colors.panel_light;
        r.fillRect(x + 2, y + half_size + 2, size - 4, half_size - 4, sub_zone_color);
        r.drawTextSmall("SUB", x + @divFloor(size, 2) - 10, y + half_size + @divFloor(half_size, 2) - 3, Colors.text);

        // Divider line
        r.fillRect(x + 4, y + half_size, size - 8, 2, Colors.border);
    } else {
        // Normal pad content
        var num_buf: [4]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{index + 1}) catch "?";
        r.drawText(num_str, x + 6, y + 6, Colors.text);

        if (pad.has_sample) {
            const name = pad.sample.getName();
            const display_len = @min(name.len, 10);
            r.drawTextSmall(name[0..display_len], x + 6, y + size - 24, Colors.text_dim);
        } else {
            r.drawTextSmall("Empty", x + 6, y + size - 24, Colors.text_dim);
        }

        // Show sub sample indicator if present
        if (pad.has_sub_sample) {
            const sub_name = pad.sub_sample.getName();
            const sub_display_len = @min(sub_name.len, 8);
            r.drawTextSmall("S:", x + 6, y + size - 12, Colors.text_dim);
            r.drawTextSmall(sub_name[0..sub_display_len], x + 18, y + size - 12, Colors.accent_dark);
        }

        const vol_height: i32 = @intFromFloat(@as(f32, @floatFromInt(size - 16)) * (@as(f32, @floatFromInt(pad.volume)) / 127.0));
        r.fillRect(x + size - 8, y + size - 6 - vol_height, 4, vol_height, Colors.accent);

        const mode_icon = switch (pad.play_mode) {
            .single => ">",
            .phrase => "X",
            .loop => "O",
        };
        r.drawTextSmall(mode_icon, x + size - 12, y + 6, Colors.text_dim);
    }

    // Border
    const border_col = if (is_selected) Colors.pad_selected else if (is_drop_target) Colors.accent else Colors.border;
    const border_w: i32 = if (is_selected or is_drop_target) 3 else 1;
    for (0..@intCast(border_w)) |i| {
        const offset: i32 = @intCast(i);
        r.drawRect(x + offset, y + offset, size - 2 * offset, size - 2 * offset, border_col);
    }

    return clicked;
}

/// Draw pad grid
pub fn drawPadGrid(r: *Renderer, ui: *EditorUI, x: i32, y: i32, kit: *models.Kit) void {
    const pad_size: i32 = 90;
    const gap: i32 = 8;

    // Show drag hint when dragging
    if (ui.isDragging()) {
        r.drawTextSmall("Drop on pad (top=Main, bottom=Sub)", x, y - 14, Colors.accent);
    }

    // SPD-SX pad layout: enumeration starts from top row
    // Top row: pads 1,2,3 | Middle row: pads 4,5,6 | Bottom row: pads 7,8,9
    const pad_order = [9]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8 };

    // Track if any pad is hovered during drag
    var any_pad_hovered = false;

    for (0..3) |row| {
        for (0..3) |col| {
            const visual_index = row * 3 + col;
            const pad_index = pad_order[visual_index];
            const pad_x = x + @as(i32, @intCast(col)) * (pad_size + gap);
            const pad_y = y + @as(i32, @intCast(row)) * (pad_size + gap);

            // Check if this pad is hovered
            if (ui.isHovered(pad_x, pad_y, pad_size, pad_size)) {
                any_pad_hovered = true;
            }

            if (drawPad(r, ui, pad_x, pad_y, pad_size, kit.getPad(pad_index), pad_index)) {
                ui.selected_pad = pad_index;
            }
        }
    }

    // Clear drop target if not hovering over any pad
    if (ui.isDragging() and !any_pad_hovered) {
        ui.clearDropTarget();
    }
}

/// Draw pad settings panel
pub fn drawPadSettings(r: *Renderer, ui: *EditorUI, x: i32, y: i32, pad: *models.Pad) void {
    const panel_w: i32 = 240;
    const panel_h: i32 = 420;

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    r.drawText("PAD SETTINGS", x + 12, y + 10, Colors.text);

    var current_y = y + 38;
    const slider_x = x + 12;
    const slider_w: i32 = 150;

    if (pad.has_sample) {
        const name = pad.sample.getName();
        const display_len = @min(name.len, 20);
        r.drawTextSmall(name[0..display_len], slider_x, current_y, Colors.accent);
    } else {
        r.drawTextSmall("No sample loaded", slider_x, current_y, Colors.text_dim);
    }
    current_y += 20;

    drawSlider(r, ui, slider_x, current_y, slider_w, 10, &pad.volume, 0, 127, "Volume");
    current_y += 30;

    drawSignedSlider(r, ui, slider_x, current_y, slider_w, 10, &pad.pan, -64, 63, "Pan");
    current_y += 30;

    drawSignedSlider(r, ui, slider_x, current_y, slider_w, 10, &pad.pitch, -24, 24, "Pitch");
    current_y += 30;

    drawSlider(r, ui, slider_x, current_y, slider_w, 10, &pad.decay, 0, 100, "Decay");
    current_y += 40;

    if (drawDropdown(r, ui, slider_x, current_y, slider_w, 20, pad.play_mode.toString(), "Play Mode")) {
        pad.play_mode = @enumFromInt((@intFromEnum(pad.play_mode) + 1) % 3);
    }
    current_y += 40;

    if (drawDropdown(r, ui, slider_x, current_y, slider_w, 20, pad.mute_group.toString(), "Mute Group")) {
        pad.mute_group = @enumFromInt((@intFromEnum(pad.mute_group) + 1) % 10);
    }
    current_y += 40;

    var midi_buf: [16]u8 = undefined;
    const midi_str = std.fmt.bufPrint(&midi_buf, "MIDI: {d}", .{pad.midi_note}) catch "?";
    r.drawTextSmall(midi_str, slider_x, current_y, Colors.text);
    current_y += 20;

    drawToggle(r, ui, slider_x, current_y, &pad.enabled, "Enabled");
    current_y += 30;

    if (pad.has_sample) {
        if (drawButton(r, ui, slider_x, current_y, slider_w, 22, "Clear Sample", true)) {
            pad.clearSample();
        }
    }
}

/// Draw kit browser
pub fn drawKitBrowser(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const panel_w: i32 = 180;
    const panel_h: i32 = 330;

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    r.drawText("KITS", x + 12, y + 10, Colors.text);

    if (drawButton(r, ui, x + panel_w - 35, y + 6, 24, 20, "+", project.kit_count < models.Project.MAX_KITS)) {
        _ = project.addKit();
    }

    var list_y = y + 38;
    const item_h: i32 = 26;

    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        const kit = &project.kits[i];
        const is_selected = project.current_kit_index == i;
        const hovered = ui.isHovered(x + 6, list_y, panel_w - 12, item_h);

        var bg_color = if (is_selected) Colors.accent_dark else Colors.panel_light;
        if (hovered and !is_selected) {
            bg_color = lightenColor(bg_color, 0.1);
        }

        r.drawRoundedRect(x + 6, list_y, panel_w - 12, item_h, bg_color, true);

        if (ui.isClicked(x + 6, list_y, panel_w - 12, item_h)) {
            project.selectKit(i);
            ui.selected_kit = i;
        }

        const name = kit.getName();
        const display_len = @min(name.len, 16);
        r.drawTextSmall(name[0..display_len], x + 12, list_y + 8, Colors.text);

        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d:0>2}", .{i + 1}) catch "??";
        r.drawTextSmall(num_str, x + panel_w - 24, list_y + 8, Colors.text_dim);

        list_y += item_h + 3;
        if (list_y + item_h > y + panel_h - 38) break;
    }

    if (drawButton(r, ui, x + 6, y + panel_h - 32, panel_w - 12, 22, "Delete Kit", project.kit_count > 1)) {
        _ = project.deleteKit(project.current_kit_index);
    }
}

/// Draw toolbar
pub fn drawToolbar(r: *Renderer, ui: *EditorUI, y: i32, width: i32) void {
    const toolbar_h: i32 = 40;

    r.fillRect(0, y, width, toolbar_h, Colors.panel);
    r.fillRect(0, y + toolbar_h - 1, width, 1, Colors.border);

    r.drawTextLarge("SpeedSX", 12, y + 8, Colors.accent);

    var btn_x: i32 = width - 320;

    if (drawButton(r, ui, btn_x, y + 6, 60, 26, "Kits", true)) {
        ui.show_kit_browser = !ui.show_kit_browser;
    }
    btn_x += 68;

    if (drawButton(r, ui, btn_x, y + 6, 60, 26, "MIDI", true)) {
        ui.show_midi_config = !ui.show_midi_config;
    }
    btn_x += 68;

    if (drawButton(r, ui, btn_x, y + 6, 60, 26, "Settings", true)) {
        ui.show_settings = !ui.show_settings;
    }
}

/// Sample browser action result
pub const SampleBrowserAction = struct {
    scan_path: bool = false,
    play_selected: bool = false,
    load_selected: bool = false,
    close: bool = false,
};

/// Draw sample browser modal
pub fn drawSampleBrowser(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32) SampleBrowserAction {
    var action = SampleBrowserAction{};

    const modal_w: i32 = 500;
    const modal_h: i32 = 420;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    // Dim background
    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    // Modal background
    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    // Title
    r.drawTextLarge("LOAD SAMPLE", x + 12, y + 10, Colors.text);

    // Close button
    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        action.close = true;
    }

    var current_y = y + 42;

    // Path input section
    r.drawTextSmall("Sample Folder Path:", x + 12, current_y, Colors.text);
    current_y += 14;

    // Draw path input field
    const path_input_w = modal_w - 110;
    _ = drawSampleBrowserPathInput(r, ui, x + 12, current_y, path_input_w, 24);

    // Scan button
    if (drawButton(r, ui, x + path_input_w + 20, current_y, 70, 24, "Scan", true)) {
        action.scan_path = true;
    }

    current_y += 32;

    // Show error if any
    const error_msg = ui.getSampleBrowserError();
    if (error_msg.len > 0) {
        r.drawTextSmall(error_msg, x + 12, current_y, 0xFFE04040);
        current_y += 14;
    }

    // File list area
    const list_x = x + 12;
    const list_y = current_y + 4;
    const list_w = modal_w - 24;
    const list_h: i32 = 240;
    const item_h: i32 = 18;

    r.fillRect(list_x, list_y, list_w, list_h, Colors.slider_bg);
    r.drawRect(list_x, list_y, list_w, list_h, Colors.border);

    if (ui.sample_browser_file_count == 0) {
        // No files message
        r.drawText("No samples found", list_x + @divFloor(list_w, 2) - 70, list_y + @divFloor(list_h, 2) - 6, Colors.text_dim);
        r.drawTextSmall("Enter a folder path and click Scan", list_x + @divFloor(list_w, 2) - 80, list_y + @divFloor(list_h, 2) + 10, Colors.text_dim);
    } else {
        // Calculate scroll
        const visible_items = @divFloor(list_h, item_h);
        const total_items: i32 = @intCast(ui.sample_browser_file_count);
        const total_content_height = total_items * item_h;
        ui.sample_browser_max_scroll = @max(0, total_content_height - list_h);

        // Draw scrollbar if needed
        if (ui.sample_browser_max_scroll > 0) {
            drawScrollbar(r, list_x + list_w - 6, list_y + 2, 4, list_h - 4, ui.sample_browser_scroll, ui.sample_browser_max_scroll);
        }

        // Draw file list
        var i: u16 = 0;
        while (i < ui.sample_browser_file_count) : (i += 1) {
            const item_y = list_y + @as(i32, @intCast(i)) * item_h - ui.sample_browser_scroll;

            // Skip items outside visible area
            if (item_y + item_h < list_y or item_y >= list_y + list_h) continue;

            const file = &ui.sample_browser_files[i];
            const is_selected = ui.sample_browser_selected == i;
            const item_hovered = ui.isHovered(list_x + 2, item_y, list_w - 12, item_h) and
                item_y >= list_y and item_y + item_h <= list_y + list_h;

            // Draw selection/hover background
            if (is_selected) {
                r.fillRect(list_x + 2, item_y, list_w - 12, item_h, Colors.accent_dark);
            } else if (item_hovered) {
                r.fillRect(list_x + 2, item_y, list_w - 12, item_h, Colors.panel_light);
            }

            // Draw file icon
            r.drawTextSmall("~", list_x + 6, item_y + 4, Colors.accent);

            // Draw filename
            const file_name = file.getName();
            const display_len = @min(file_name.len, 50);
            const text_color = if (is_selected) Colors.text else Colors.text;
            r.drawTextSmall(file_name[0..display_len], list_x + 18, item_y + 4, text_color);

            // Handle click
            if (item_hovered and ui.isClicked(list_x + 2, item_y, list_w - 12, item_h)) {
                ui.sample_browser_selected = i;
            }

            // Handle double-click (check for quick second click)
            if (item_hovered and is_selected and ui.mouse_clicked) {
                // This could be extended to track double-click timing
            }
        }

        // Handle scroll wheel
        if (ui.isHovered(list_x, list_y, list_w, list_h)) {
            // Scroll handling is done in main loop via handleMouseWheel
            // Store bounds for scroll detection
            _ = visible_items;
        }
    }

    current_y = list_y + list_h + 10;

    // Action buttons
    const btn_w: i32 = 90;
    const btn_h: i32 = 28;
    const btn_gap: i32 = 10;
    const total_btn_w = btn_w * 3 + btn_gap * 2;
    const btn_x = x + @divFloor(modal_w - total_btn_w, 2);

    // Play button
    const has_selection = ui.sample_browser_file_count > 0 and ui.sample_browser_selected < ui.sample_browser_file_count;
    if (drawGreenButton(r, ui, btn_x, current_y, btn_w, btn_h, "Play", has_selection)) {
        action.play_selected = true;
    }

    // Load button (add to library)
    if (drawButton(r, ui, btn_x + btn_w + btn_gap, current_y, btn_w, btn_h, "Load", has_selection)) {
        action.load_selected = true;
    }

    // Cancel button
    if (drawButton(r, ui, btn_x + (btn_w + btn_gap) * 2, current_y, btn_w, btn_h, "Cancel", true)) {
        action.close = true;
    }

    current_y += btn_h + 10;

    // Help text
    r.drawTextSmall("Supported: WAV, AIFF", x + 12, current_y, Colors.text_dim);

    return action;
}

/// Draw a green button (for primary actions like Play)
fn drawGreenButton(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, text: []const u8, enabled: bool) bool {
    const hovered = ui.isHovered(x, y, w, h);
    const clicked = enabled and ui.isClicked(x, y, w, h);

    var bg_color: u32 = if (enabled) 0xFF2A8A2A else Colors.panel;
    if (hovered and enabled) bg_color = 0xFF3A9A3A;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);

    const text_color = if (enabled) Colors.text else Colors.text_dim;
    const text_width = r.measureTextSmall(text);
    r.drawTextSmall(text, x + @divFloor(w - text_width, 2), y + @divFloor(h - 6, 2), text_color);

    return clicked;
}

/// Draw the sample browser path input field
fn drawSampleBrowserPathInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
    const field_id = TextFieldId.sample_browser_path;
    const is_focused = ui.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);
    const current_value = ui.getSampleBrowserPath();

    // Background color based on state
    var bg_color = Colors.slider_bg;
    var border_color = Colors.border;
    if (is_focused) {
        bg_color = Colors.panel_light;
        border_color = Colors.accent;
    } else if (hovered) {
        bg_color = Colors.panel_light;
    }

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, border_color, false);
    if (is_focused) {
        r.drawRect(x + 1, y + 1, w - 2, h - 2, border_color);
    }

    // Determine what text to display
    const display_text = if (is_focused) ui.getInputText() else current_value;
    const max_chars: usize = @intCast(@divFloor(w - 16, 5));
    const display_len = @min(display_text.len, max_chars);

    // Draw text
    const text_y = y + @divFloor(h - 6, 2);
    if (display_text.len > 0) {
        r.drawTextSmall(display_text[0..display_len], x + 8, text_y, Colors.text);
    } else {
        r.drawTextSmall("/path/to/samples", x + 8, text_y, Colors.text_dim);
    }

    // Draw cursor when focused
    if (is_focused and ui.cursor_blink < 0.5) {
        const cursor_x = x + 8 + @as(i32, ui.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 4, 1, h - 8, Colors.text);
    }

    // Handle click to focus
    if (ui.isClicked(x, y, w, h)) {
        ui.text_field_clicked_this_frame = true;
        if (!is_focused) {
            ui.startTextInput(field_id, current_value);
        }
        return false;
    }

    return false;
}

/// Apply sample browser path from text input
pub fn applySampleBrowserPathInput(ui: *EditorUI) void {
    if (ui.focused_field == .sample_browser_path) {
        const text = ui.finishTextInput();
        ui.setSampleBrowserPath(text);
    }
}

/// Draw MIDI config modal
pub fn drawMidiConfig(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32, config: *models.MidiConfig) void {
    const modal_w: i32 = 320;
    const modal_h: i32 = 260;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    r.drawTextLarge("MIDI CONFIG", x + 12, y + 10, Colors.text);

    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        ui.show_midi_config = false;
    }

    var current_y = y + 48;
    const slider_x = x + 16;

    drawSlider(r, ui, slider_x, current_y, 160, 10, &config.input_channel, 0, 16, "Input Ch (0=Omni)");
    current_y += 35;

    drawSlider(r, ui, slider_x, current_y, 160, 10, &config.output_channel, 0, 15, "Output Channel");
    current_y += 35;

    drawToggle(r, ui, slider_x, current_y, &config.local_control, "Local Control");
    current_y += 25;

    drawToggle(r, ui, slider_x, current_y, &config.send_program_change, "Send PC");
    current_y += 25;

    drawToggle(r, ui, slider_x, current_y, &config.receive_program_change, "Receive PC");
}

/// Draw settings modal
pub fn drawSettings(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32, project: *models.Project) void {
    const modal_w: i32 = 320;
    const modal_h: i32 = 220;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    r.drawTextLarge("SETTINGS", x + 12, y + 10, Colors.text);

    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        ui.show_settings = false;
    }

    const kit = project.currentKit();
    var current_y = y + 48;
    const slider_x = x + 16;

    var tempo_low: u8 = @truncate(kit.tempo & 0xFF);
    drawSlider(r, ui, slider_x, current_y, 160, 10, &tempo_low, 40, 255, "Tempo (BPM)");
    kit.tempo = tempo_low;
    current_y += 35;

    drawSlider(r, ui, slider_x, current_y, 160, 10, &kit.master_volume, 0, 127, "Master Volume");
    current_y += 35;

    drawSlider(r, ui, slider_x, current_y, 160, 10, &kit.master_fx_send, 0, 100, "Master FX Send");
    current_y += 42;

    if (drawButton(r, ui, slider_x, current_y, 80, 22, "Save", true)) {}
    if (drawButton(r, ui, slider_x + 90, current_y, 80, 22, "Load", true)) {}
}

/// Draw status bar
pub fn drawStatusBar(r: *Renderer, y: i32, width: i32, project: *models.Project, ui_state: *const EditorUI) void {
    const bar_h: i32 = 22;

    r.fillRect(0, y, width, bar_h, Colors.panel);
    r.fillRect(0, y, width, 1, Colors.border);

    var kit_buf: [32]u8 = undefined;
    const kit_str = std.fmt.bufPrint(&kit_buf, "Kits: {d}/{d}", .{ project.kit_count, models.Project.MAX_KITS }) catch "?";
    r.drawTextSmall(kit_str, 12, y + 7, Colors.text_dim);

    var pad_buf: [32]u8 = undefined;
    const pad_str = std.fmt.bufPrint(&pad_buf, "Pad: {d}", .{ui_state.selected_pad + 1}) catch "?";
    r.drawTextSmall(pad_str, 110, y + 7, Colors.text_dim);

    var tempo_buf: [32]u8 = undefined;
    const tempo_str = std.fmt.bufPrint(&tempo_buf, "BPM: {d}", .{project.currentKit().tempo}) catch "?";
    r.drawTextSmall(tempo_str, 180, y + 7, Colors.text_dim);

    r.drawTextSmall("v0.1.0", width - 42, y + 7, Colors.text_dim);
}

/// Draw Kit Settings panel (left side - Kit info, Main, Mode, Sub sections)
pub fn drawKitSettingsPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, kit: *models.Kit, pad: *models.Pad) void {
    const panel_w: i32 = 200;

    // Kit section
    r.drawTextSmall("Kit", x, y, Colors.text);
    var current_y = y + 26;

    // Kit Name (editable)
    _ = drawTextInput(r, ui, x, current_y, panel_w - 10, 20, .kit_name, kit.getName(), "Kit Name");
    current_y += 38;

    // KitSub Name (editable)
    _ = drawTextInput(r, ui, x, current_y, panel_w - 10, 20, .kit_sub_name, kit.getSubName(), "KitSub Name");
    current_y += 38;

    // Volume
    drawSlider(r, ui, x, current_y + 10, panel_w - 50, 8, &kit.master_volume, 0, 100, "Volume");
    current_y += 35;

    // Kit Tempo (editable)
    var tempo_buf: [16]u8 = undefined;
    const tempo_str = std.fmt.bufPrint(&tempo_buf, "{d}.{d}", .{ kit.tempo, kit.tempo_decimal }) catch "120.0";
    _ = drawTextInput(r, ui, x + panel_w - 80, current_y + 10, 70, 20, .kit_tempo, tempo_str, "Kit Tempo (Bpm)");
    current_y += 38;

    // Pad Link
    if (drawDropdown(r, ui, x, current_y + 10, 60, 18, kit.pad_link.toString(), "Pad Link")) {
        kit.pad_link = @enumFromInt((@intFromEnum(kit.pad_link) + 1) % 16);
    }
    if (drawDropdown(r, ui, x + 70, current_y + 10, 60, 18, kit.pad_link_target.toString(), "")) {
        kit.pad_link_target = @enumFromInt((@intFromEnum(kit.pad_link_target) + 1) % 16);
    }
    current_y += 45;

    // Main section
    r.fillRect(x - 5, current_y, panel_w, 1, Colors.border);
    current_y += 8;
    r.drawTextSmall("Main", x, current_y, Colors.text);
    current_y += 16;

    // Wave
    r.drawTextSmall("Wave", x, current_y, Colors.text_dim);
    current_y += 10;
    const wave_name = if (pad.has_sample) pad.sample.getName() else "";
    drawTextBox(r, ui, x, current_y, panel_w - 10, 20, wave_name);
    current_y += 28;

    // Pad Volume
    drawSlider(r, ui, x, current_y + 10, panel_w - 50, 8, &pad.volume, 0, 100, "Pad Volume");
    current_y += 35;

    // Pan (using signed slider simulation)
    r.drawTextSmall("Pan", x, current_y, Colors.text_dim);
    const pan_text = if (pad.pan == 0) "CENTER" else if (pad.pan < 0) "L" else "R";
    r.drawTextSmall(pan_text, x + panel_w - 60, current_y, Colors.text);
    current_y += 10;
    drawSignedSlider(r, ui, x, current_y, panel_w - 50, 8, &pad.pan, -64, 63, "");
    current_y += 25;

    // Mute Group
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.mute_group.toString(), "Mute Group")) {
        pad.mute_group = @enumFromInt((@intFromEnum(pad.mute_group) + 1) % 10);
    }
    current_y += 38;

    // TempoSync
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.tempo_sync.toString(), "TempoSync")) {
        pad.tempo_sync = @enumFromInt((@intFromEnum(pad.tempo_sync) + 1) % 2);
    }
    current_y += 45;

    // Mode section
    r.fillRect(x - 5, current_y, panel_w, 1, Colors.border);
    current_y += 8;
    r.drawTextSmall("Mode", x, current_y, Colors.text);
    current_y += 16;

    // Loop mode
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.loop_mode.toString(), "Loop")) {
        pad.loop_mode = @enumFromInt((@intFromEnum(pad.loop_mode) + 1) % 5);
    }
    current_y += 38;

    // Trigger Type
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.trigger_mode.toString(), "Trigger Type")) {
        pad.trigger_mode = @enumFromInt((@intFromEnum(pad.trigger_mode) + 1) % 2);
    }
    current_y += 38;

    // Dynamics
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.dynamics.toString(), "Dynamics")) {
        pad.dynamics = @enumFromInt((@intFromEnum(pad.dynamics) + 1) % 2);
    }
    current_y += 38;

    // PolyMono
    if (drawDropdown(r, ui, x, current_y + 10, 80, 18, pad.poly_mono.toString(), "PolyMono")) {
        pad.poly_mono = @enumFromInt((@intFromEnum(pad.poly_mono) + 1) % 2);
    }
    current_y += 38;

    // Output Assign
    if (drawDropdown(r, ui, x, current_y + 10, 100, 18, pad.output_assign.toString(), "Output Assign")) {
        pad.output_assign = @enumFromInt((@intFromEnum(pad.output_assign) + 1) % 5);
    }
    current_y += 45;

    // Sub section
    r.fillRect(x - 5, current_y, panel_w, 1, Colors.border);
    current_y += 8;
    r.drawTextSmall("Sub", x, current_y, Colors.text);
    current_y += 16;

    // SubWave
    r.drawTextSmall("SubWave", x, current_y, Colors.text_dim);
    current_y += 10;
    const sub_wave_name = if (pad.has_sub_sample) pad.sub_sample.getName() else "";
    drawTextBox(r, ui, x, current_y, panel_w - 10, 20, sub_wave_name);
    current_y += 28;

    // SubPad Volume
    drawSlider(r, ui, x, current_y + 10, panel_w - 50, 8, &pad.sub_volume, 0, 100, "SubPad Volume");
    current_y += 35;

    // SubPan
    r.drawTextSmall("SubPan", x, current_y, Colors.text_dim);
    const sub_pan_text = if (pad.sub_pan == 0) "CENTER" else if (pad.sub_pan < 0) "L" else "R";
    r.drawTextSmall(sub_pan_text, x + panel_w - 60, current_y, Colors.text);
    current_y += 10;
    drawSignedSlider(r, ui, x, current_y, panel_w - 50, 8, &pad.sub_pan, -64, 63, "");
}

/// Draw a text box (read-only display)
fn drawTextBox(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, text: []const u8) void {
    const hovered = ui.isHovered(x, y, w, h);
    const bg_color = if (hovered) Colors.panel_light else Colors.slider_bg;
    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);
    const display_len = @min(text.len, 20);
    r.drawTextSmall(if (text.len > 0) text[0..display_len] else "", x + 4, y + @divFloor(h - 6, 2), Colors.text);
}

/// Draw an editable text input field
pub fn drawTextInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, field_id: TextFieldId, current_value: []const u8, label: []const u8) bool {
    const is_focused = ui.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);

    // Draw label
    if (label.len > 0) {
        r.drawTextSmall(label, x, y - 12, Colors.text_dim);
    }

    // Background color based on state
    var bg_color = Colors.slider_bg;
    var border_color = Colors.border;
    if (is_focused) {
        bg_color = Colors.panel_light;
        border_color = Colors.accent;
    } else if (hovered) {
        bg_color = Colors.panel_light;
    }

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, border_color, false);
    if (is_focused) {
        // Draw second border for focused state
        r.drawRect(x + 1, y + 1, w - 2, h - 2, border_color);
    }

    // Determine what text to display
    const display_text = if (is_focused) ui.getInputText() else current_value;
    const max_chars: usize = @intCast(@divFloor(w - 8, 5)); // Approximate chars that fit
    const display_len = @min(display_text.len, max_chars);

    // Draw text
    const text_y = y + @divFloor(h - 6, 2);
    r.drawTextSmall(if (display_text.len > 0) display_text[0..display_len] else "", x + 4, text_y, Colors.text);

    // Draw cursor when focused
    if (is_focused and ui.cursor_blink < 0.5) {
        const cursor_x = x + 4 + @as(i32, ui.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 3, 1, h - 6, Colors.text);
    }

    // Handle click to focus
    if (ui.isClicked(x, y, w, h)) {
        ui.text_field_clicked_this_frame = true;
        if (!is_focused) {
            ui.startTextInput(field_id, current_value);
        }
        return false;
    }

    // Return true if Enter was pressed to confirm (handled externally)
    return false;
}

/// Apply text input to kit name
pub fn applyTextInputToKit(ui: *EditorUI, kit: *models.Kit) void {
    if (ui.focused_field == .kit_name) {
        const text = ui.finishTextInput();
        kit.setName(text);
    } else if (ui.focused_field == .kit_sub_name) {
        const text = ui.finishTextInput();
        kit.setSubName(text);
    } else if (ui.focused_field == .kit_tempo) {
        const text = ui.finishTextInput();
        // Parse tempo value
        var tempo: u16 = 0;
        var decimal: u8 = 0;
        var seen_dot = false;
        for (text) |char| {
            if (char == '.') {
                seen_dot = true;
            } else if (char >= '0' and char <= '9') {
                if (seen_dot) {
                    decimal = char - '0';
                    break; // Only one decimal place
                } else {
                    tempo = tempo * 10 + @as(u16, char - '0');
                }
            }
        }
        if (tempo >= 20 and tempo <= 300) {
            kit.tempo = tempo;
            kit.tempo_decimal = decimal;
        }
        ui.focused_field = .none;
    }
}

/// Check if a sample is used by any pad in the project
fn isSampleUsed(project: *models.Project, sample_index: u16) bool {
    const library = &project.sample_library;
    if (sample_index >= library.count) return false;

    const sample = &library.samples[sample_index];
    const sample_path = sample.getPath();
    if (sample_path.len == 0) return false;

    // Check all kits and pads
    var kit_idx: u8 = 0;
    while (kit_idx < project.kit_count) : (kit_idx += 1) {
        const kit = &project.kits[kit_idx];
        for (&kit.pads) |*pad| {
            // Check main sample
            if (pad.has_sample) {
                if (std.mem.eql(u8, pad.sample.getPath(), sample_path)) {
                    return true;
                }
            }
            // Check sub sample
            if (pad.has_sub_sample) {
                if (std.mem.eql(u8, pad.sub_sample.getPath(), sample_path)) {
                    return true;
                }
            }
        }
    }
    return false;
}

/// Draw Wave/Sample list panel (right side)
pub fn drawWaveListPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const panel_w: i32 = 140;
    const panel_h: i32 = 360;
    const header_h: i32 = 18;
    const item_h: i32 = 14;
    const list_padding: i32 = 8;

    // Store bounds for scroll detection
    ui.wave_list_bounds = .{ .x = x, .y = y, .w = panel_w, .h = panel_h };

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    // Title with count
    const library = &project.sample_library;
    var title_buf: [32]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Waves ({d})", .{library.count}) catch "Waves";
    r.drawTextSmall(title, x + 4, y + 4, Colors.text_dim);

    const total_items: i32 = @intCast(library.count);
    const visible_height = panel_h - header_h - list_padding;
    const total_content_height = @max(1, total_items) * item_h;
    ui.wave_list_max_scroll = @max(0, total_content_height - visible_height);

    // Calculate visible range
    const list_top = y + header_h;
    const list_bottom = y + panel_h - list_padding;

    // Draw scrollbar if needed
    if (ui.wave_list_max_scroll > 0) {
        drawScrollbar(r, x + panel_w - 6, list_top, 4, visible_height, ui.wave_list_scroll, ui.wave_list_max_scroll);
    }

    // Show empty state if no samples
    if (library.count == 0) {
        r.drawTextSmall("No waves", x + 30, y + panel_h / 2 - 6, Colors.text_dim);
        return;
    }

    var i: u16 = 0;
    while (i < library.count) : (i += 1) {
        const item_y = list_top + @as(i32, @intCast(i)) * item_h - ui.wave_list_scroll;

        // Skip items outside visible area
        if (item_y + item_h < list_top or item_y >= list_bottom) continue;

        const sample = &library.samples[i];
        const sample_name = sample.getName();
        const is_used = isSampleUsed(project, i);
        const is_selected = ui.selected_wave == i;
        const item_hovered = ui.isHovered(x + 4, item_y, panel_w - 12, item_h) and item_y >= list_top and item_y + item_h <= list_bottom;

        // Highlight on hover
        if (item_hovered and !ui.isDragging()) {
            r.fillRect(x + 2, item_y - 1, panel_w - 10, item_h, Colors.panel_light);
        }

        // Color indicator: red if used, gray if not used
        const indicator_color: u32 = if (is_used) 0xFFA02828 else Colors.text_dim;
        r.fillRect(x + 4, item_y + 2, 8, 8, indicator_color);

        // Number (1-based absolute index)
        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i + 1}) catch "?";
        r.drawTextSmall(num_str, x + 16, item_y + 1, Colors.text_dim);

        // Name
        const display_len = @min(sample_name.len, 12);
        const text_color = if (is_selected) Colors.accent else Colors.text;
        r.drawTextSmall(sample_name[0..display_len], x + 34, item_y + 1, text_color);

        // Handle click to select (only if fully visible)
        if (item_hovered and ui.isClicked(x + 4, item_y, panel_w - 12, item_h)) {
            ui.selected_wave = i;
        }

        // Handle mouse down to start drag
        if (item_hovered and ui.mouse_down and ui.drag_type == .none and sample_name.len > 0) {
            ui.startDragWave(i, sample_name);
        }
    }
}

/// Draw Kit list panel (right side, below wave list)
pub fn drawKitListPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const panel_w: i32 = 150;
    const panel_h: i32 = 260;
    const header_h: i32 = 18;
    const item_h: i32 = 14;
    const list_padding: i32 = 8;

    // Store bounds for scroll detection
    ui.kit_list_bounds = .{ .x = x, .y = y, .w = panel_w, .h = panel_h };

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    r.drawTextSmall("Kits", x + 4, y + 4, Colors.text_dim);

    const total_items: i32 = @intCast(project.kit_count);
    const visible_height = panel_h - header_h - list_padding;
    const total_content_height = total_items * item_h;
    ui.kit_list_max_scroll = @max(0, total_content_height - visible_height);

    // Calculate visible range
    const list_top = y + header_h;
    const list_bottom = y + panel_h - list_padding;

    // Draw scrollbar if needed
    if (ui.kit_list_max_scroll > 0) {
        drawScrollbar(r, x + panel_w - 6, list_top, 4, visible_height, ui.kit_list_scroll, ui.kit_list_max_scroll);
    }

    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        const item_y = list_top + @as(i32, i) * item_h - ui.kit_list_scroll;

        // Skip items outside visible area
        if (item_y + item_h < list_top or item_y >= list_bottom) continue;

        const kit = &project.kits[i];
        const is_selected = project.current_kit_index == i;
        const item_hovered = ui.isHovered(x + 4, item_y, panel_w - 12, item_h) and item_y >= list_top and item_y + item_h <= list_bottom;

        // Highlight on hover
        if (item_hovered) {
            r.fillRect(x + 2, item_y - 1, panel_w - 10, item_h, Colors.panel_light);
        }

        // Number
        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i + 1}) catch "?";
        r.drawTextSmall(num_str, x + 6, item_y + 1, Colors.text_dim);

        // Name
        const name = kit.getName();
        const display_len = @min(name.len, 16);
        const text_color = if (is_selected) Colors.accent else Colors.text;
        r.drawTextSmall(name[0..display_len], x + 24, item_y + 1, text_color);

        // Handle click (only if fully visible)
        if (item_hovered and ui.isClicked(x + 4, item_y, panel_w - 12, item_h)) {
            project.selectKit(i);
            ui.selected_kit = i;
        }
    }
}

/// Draw action buttons panel
pub fn drawActionButtons(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const btn_w: i32 = 65;
    const btn_h: i32 = 22;
    const gap: i32 = 4;

    var btn_x = x;
    var btn_y = y;

    // Row 1: Play, Stop, Init Kit, Up
    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Play", true)) {
        ui.togglePlay();
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Stop", true)) {
        ui.stop();
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Init Kit", true)) {
        project.initKit(project.current_kit_index);
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Up", project.current_kit_index > 0)) {
        _ = project.moveKitUp(project.current_kit_index);
    }

    // Row 2: Import wav, Delete wav, Delete Kit, Down
    btn_x = x;
    btn_y += btn_h + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Import wav", true)) {
        ui.show_sample_browser = true;
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Delete wav", true)) {
        // Delete selected wave from current pad
        const pad = project.currentKit().getPad(ui.selected_pad);
        pad.clearSample();
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Delete Kit", project.kit_count > 1)) {
        _ = project.deleteKit(project.current_kit_index);
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Down", project.current_kit_index < project.kit_count - 1)) {
        _ = project.moveKitDown(project.current_kit_index);
    }

    // Row 3: Duplicate, Add new Kit
    btn_x = x;
    btn_y += btn_h + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Duplicate", project.kit_count < models.Project.MAX_KITS)) {
        _ = project.duplicateKit(project.current_kit_index);
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Add new Kit", project.kit_count < models.Project.MAX_KITS)) {
        _ = project.addKit();
    }
}

/// Draw device visualization (SPD-SX mockup)
pub fn drawDeviceView(r: *Renderer, ui: *EditorUI, x: i32, y: i32) void {
    const device_w: i32 = 280;
    const device_h: i32 = 50;

    // Device body
    r.drawRoundedRect(x, y, device_w, device_h, 0xFF2A2A2A, true);
    r.drawRoundedRect(x, y, device_w, device_h, Colors.border, false);

    // Trigger buttons row
    const trig_y = y + 6;
    const trig_w: i32 = 40;
    const trig_h: i32 = 18;

    var trig_x = x + 60;
    const trig_labels = [_][]const u8{ "Trig 1", "Trig 2", "Trig 3", "Trig 4" };

    for (trig_labels, 0..) |label, i| {
        const hovered = ui.isHovered(trig_x, trig_y, trig_w, trig_h);
        const bg = if (hovered) Colors.panel_light else Colors.panel;
        r.drawRoundedRect(trig_x, trig_y, trig_w, trig_h, bg, true);
        r.drawRoundedRect(trig_x, trig_y, trig_w, trig_h, Colors.border, false);
        r.drawTextSmall(label, trig_x + 4, trig_y + 5, Colors.text_dim);

        if (ui.isClicked(trig_x, trig_y, trig_w, trig_h)) {
            ui.triggerPadFlash(@intCast(i));
        }

        trig_x += trig_w + 6;
    }

    // FS buttons
    const fs_y = y + 32;
    const fs_w: i32 = 36;
    const fs_h: i32 = 14;

    r.drawRoundedRect(x + 90, fs_y, fs_w, fs_h, Colors.panel, true);
    r.drawRoundedRect(x + 90, fs_y, fs_w, fs_h, Colors.border, false);
    r.drawTextSmall("FS 1", x + 94, fs_y + 3, Colors.text_dim);

    r.drawRoundedRect(x + 134, fs_y, fs_w, fs_h, Colors.panel, true);
    r.drawRoundedRect(x + 134, fs_y, fs_w, fs_h, Colors.border, false);
    r.drawTextSmall("FS 2", x + 138, fs_y + 3, Colors.text_dim);
}

/// File bar action result
pub const FileBarAction = struct {
    needs_open: bool = false,
    needs_save: bool = false,
};

/// Draw file path bar and Open/Save buttons
pub fn drawFileBar(r: *Renderer, ui: *EditorUI, x: i32, y: i32, width: i32, project: *models.Project) FileBarAction {
    var action = FileBarAction{};
    const bar_h: i32 = 28;
    const btn_w: i32 = 60;

    r.fillRect(x, y, width, bar_h, Colors.panel);
    r.fillRect(x, y, width, 1, Colors.border);

    // File path
    const path = project.getFilePath();
    const path_display = if (path.len > 0) path else "/Volumes/SPD-SX_/Roland";
    r.drawTextSmall(path_display, x + 10, y + 10, Colors.text_dim);

    // Open button (green)
    const open_x = x + width - 140;
    if (ui.isHovered(open_x, y + 4, btn_w, 20)) {
        r.fillRect(open_x, y + 4, btn_w, 20, 0xFF3A8A3A);
    } else {
        r.fillRect(open_x, y + 4, btn_w, 20, 0xFF2A7A2A);
    }
    r.drawTextSmall("Open", open_x + 16, y + 10, Colors.text);
    if (ui.isClicked(open_x, y + 4, btn_w, 20)) {
        action.needs_open = true;
    }

    // Save button
    const save_x = x + width - 70;
    if (drawButton(r, ui, save_x, y + 4, btn_w, 20, "Save", true)) {
        action.needs_save = true;
    }

    return action;
}

/// Draw context menu for pads
pub fn drawPadContextMenu(r: *Renderer, ui: *EditorUI, kit: *models.Kit) bool {
    if (!ui.context_menu_open) return false;

    const menu_w: i32 = 100;
    const item_h: i32 = 22;
    const menu_items = 4; // Copy, Paste, Clear, Cancel
    const menu_h: i32 = item_h * menu_items + 2;

    const x = ui.context_menu_x;
    const y = ui.context_menu_y;

    // Draw menu background with shadow
    r.fillRect(x + 2, y + 2, menu_w, menu_h, 0x80000000); // Shadow
    r.fillRect(x, y, menu_w, menu_h, Colors.panel);
    r.drawRect(x, y, menu_w, menu_h, Colors.accent);

    var item_y = y + 1;
    var menu_clicked = false;
    const pad = kit.getPad(ui.context_menu_pad);

    // Copy option
    const copy_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (copy_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Copy", x + 8, item_y + 6, Colors.text);
    if (pad.has_sample) {
        r.drawTextSmall("Ctrl+C", x + menu_w - 42, item_y + 6, Colors.text_dim);
    }
    if (copy_hovered and ui.mouse_clicked) {
        ui.copyPad(pad);
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

    // Paste option
    const paste_enabled = ui.hasClipboardData();
    const paste_hovered = ui.isHovered(x, item_y, menu_w, item_h) and paste_enabled;
    if (paste_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    const paste_color = if (paste_enabled) Colors.text else Colors.text_dim;
    r.drawTextSmall("Paste", x + 8, item_y + 6, paste_color);
    if (paste_enabled) {
        r.drawTextSmall("Ctrl+V", x + menu_w - 42, item_y + 6, Colors.text_dim);
    }
    if (paste_hovered and ui.mouse_clicked) {
        ui.pastePad(pad);
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

    // Clear option
    const clear_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (clear_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Clear", x + 8, item_y + 6, Colors.text);
    if (clear_hovered and ui.mouse_clicked) {
        pad.reset();
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

    // Separator line
    r.fillRect(x + 4, item_y - 1, menu_w - 8, 1, Colors.border);

    // Cancel option
    const cancel_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (cancel_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Cancel", x + 8, item_y + 6, Colors.text_dim);
    if (cancel_hovered and ui.mouse_clicked) {
        ui.closeContextMenu();
        menu_clicked = true;
    }

    // Close menu if clicked outside
    if (ui.mouse_clicked and !ui.isHovered(x, y, menu_w, menu_h)) {
        ui.closeContextMenu();
        menu_clicked = true;
    }

    return menu_clicked;
}

/// Draw the drag indicator when dragging a wave
pub fn drawDragIndicator(r: *Renderer, ui: *const EditorUI) void {
    if (!ui.isDragging()) return;

    const wave_name = ui.getDragWaveName();
    if (wave_name.len == 0) return;

    // Draw a floating label following the cursor
    const label_w: i32 = @as(i32, @intCast(wave_name.len)) * 5 + 16;
    const label_h: i32 = 18;
    const label_x = ui.mouse_x + 12;
    const label_y = ui.mouse_y + 12;

    // Background with slight transparency effect
    r.fillRect(label_x, label_y, label_w, label_h, Colors.accent_dark);
    r.drawRect(label_x, label_y, label_w, label_h, Colors.accent);

    // Wave icon
    r.drawTextSmall("~", label_x + 4, label_y + 5, Colors.text);

    // Wave name
    const display_len = @min(wave_name.len, 16);
    r.drawTextSmall(wave_name[0..display_len], label_x + 12, label_y + 5, Colors.text);
}

/// Apply the drop - assign wave to pad (uses sample library)
pub fn applyDropFromLibrary(ui: *EditorUI, kit: *models.Kit, library: *models.SampleLibrary) bool {
    if (!ui.isDragging() or ui.drop_target == .none) {
        ui.cancelDrag();
        return false;
    }

    // Get sample from library by index
    const sample = library.getSample(ui.drag_wave_index) orelse {
        ui.cancelDrag();
        return false;
    };

    const pad = kit.getPad(ui.drop_target_pad);
    const wave_name = sample.getName();
    const wave_path = sample.getPath();

    switch (ui.drop_target) {
        .pad_main => {
            pad.loadSample(wave_name, wave_path);
        },
        .pad_sub => {
            pad.loadSubSample(wave_name, wave_path);
        },
        .none => {},
    }

    // Reset drag state
    ui.cancelDrag();
    return true;
}

/// Draw a scrollbar
fn drawScrollbar(r: *Renderer, x: i32, y: i32, w: i32, h: i32, scroll_pos: i32, max_scroll: i32) void {
    if (max_scroll <= 0) return;

    // Track background
    r.fillRect(x, y, w, h, Colors.slider_bg);

    // Calculate thumb size and position
    const content_ratio = @as(f32, @floatFromInt(h)) / @as(f32, @floatFromInt(h + max_scroll));
    const thumb_h: i32 = @max(20, @as(i32, @intFromFloat(@as(f32, @floatFromInt(h)) * content_ratio)));
    const available_track = h - thumb_h;
    const scroll_ratio = @as(f32, @floatFromInt(scroll_pos)) / @as(f32, @floatFromInt(max_scroll));
    const thumb_y = y + @as(i32, @intFromFloat(@as(f32, @floatFromInt(available_track)) * scroll_ratio));

    // Draw thumb
    r.fillRect(x, thumb_y, w, thumb_h, Colors.accent_dark);
}

// Helpers
fn lerpColor(a: u32, b: u32, t: f32) u32 {
    const ar: f32 = @floatFromInt((a >> 16) & 0xFF);
    const ag: f32 = @floatFromInt((a >> 8) & 0xFF);
    const ab: f32 = @floatFromInt(a & 0xFF);
    const aa: f32 = @floatFromInt((a >> 24) & 0xFF);

    const br: f32 = @floatFromInt((b >> 16) & 0xFF);
    const bg_val: f32 = @floatFromInt((b >> 8) & 0xFF);
    const bb: f32 = @floatFromInt(b & 0xFF);
    const ba: f32 = @floatFromInt((b >> 24) & 0xFF);

    const rr: u32 = @intFromFloat(ar + (br - ar) * t);
    const rg: u32 = @intFromFloat(ag + (bg_val - ag) * t);
    const rb: u32 = @intFromFloat(ab + (bb - ab) * t);
    const ra: u32 = @intFromFloat(aa + (ba - aa) * t);

    return (ra << 24) | (rr << 16) | (rg << 8) | rb;
}

fn lightenColor(col: u32, amount: f32) u32 {
    const r_val: u32 = @min(255, @as(u32, @intFromFloat(@as(f32, @floatFromInt((col >> 16) & 0xFF)) * (1 + amount))));
    const g_val: u32 = @min(255, @as(u32, @intFromFloat(@as(f32, @floatFromInt((col >> 8) & 0xFF)) * (1 + amount))));
    const b_val: u32 = @min(255, @as(u32, @intFromFloat(@as(f32, @floatFromInt(col & 0xFF)) * (1 + amount))));
    return (col & 0xFF000000) | (r_val << 16) | (g_val << 8) | b_val;
}

/// Startup screen action result
pub const StartupAction = enum {
    none,
    open_project, // User clicked Open - load from path
    new_project, // User clicked New Project - start fresh
};

/// Draw the startup screen where user chooses configuration path
pub fn drawStartupScreen(r: *Renderer, ui: *EditorUI, width: i32, height: i32) StartupAction {
    var action = StartupAction.none;

    // Fill background
    r.fillRect(0, 0, width, height, Colors.background);

    // Center the dialog
    const dialog_w: i32 = 500;
    const dialog_h: i32 = 320;
    const x = @divFloor(width - dialog_w, 2);
    const y = @divFloor(height - dialog_h, 2);

    // Draw dialog background
    r.drawRoundedRect(x, y, dialog_w, dialog_h, Colors.panel, true);
    r.drawRect(x, y, dialog_w, dialog_h, Colors.accent);
    r.drawRect(x + 1, y + 1, dialog_w - 2, dialog_h - 2, Colors.accent);

    // Title
    r.drawTextLarge("SpeedSX", x + @divFloor(dialog_w, 2) - 42, y + 20, Colors.accent);
    r.drawText("Configuration Editor", x + @divFloor(dialog_w, 2) - 95, y + 50, Colors.text_dim);

    // Instructions
    r.drawTextSmall("Enter the path to your SPD-SX configuration folder:", x + 20, y + 90, Colors.text);
    r.drawTextSmall("(e.g., /Volumes/SPD-SX_/Roland or /media/usb/Roland)", x + 20, y + 105, Colors.text_dim);

    // Path input field
    const input_x = x + 20;
    const input_y = y + 130;
    const input_w = dialog_w - 40;
    const input_h: i32 = 28;

    // Draw the text input for startup path
    const current_path = ui.getStartupPath();
    _ = drawStartupPathInput(r, ui, input_x, input_y, input_w, input_h, current_path);

    // Show error message if any
    const error_msg = ui.getStartupError();
    if (error_msg.len > 0) {
        r.drawTextSmall(error_msg, x + 20, y + 170, 0xFFE04040); // Red error color
    }

    // Buttons
    const btn_w: i32 = 140;
    const btn_h: i32 = 32;
    const btn_y = y + 200;
    const btn_gap: i32 = 20;
    const total_btn_w = btn_w * 2 + btn_gap;
    const btn_start_x = x + @divFloor(dialog_w - total_btn_w, 2);

    // Open button (green, primary action)
    const open_x = btn_start_x;
    const open_hovered = ui.isHovered(open_x, btn_y, btn_w, btn_h);
    const open_color: u32 = if (open_hovered) 0xFF3A9A3A else 0xFF2A8A2A;
    r.drawRoundedRect(open_x, btn_y, btn_w, btn_h, open_color, true);
    r.drawRoundedRect(open_x, btn_y, btn_w, btn_h, Colors.border, false);
    r.drawText("Open", open_x + @divFloor(btn_w - 40, 2), btn_y + 8, Colors.text);

    if (ui.isClicked(open_x, btn_y, btn_w, btn_h)) {
        action = .open_project;
    }

    // New Project button
    const new_x = btn_start_x + btn_w + btn_gap;
    if (drawButton(r, ui, new_x, btn_y, btn_w, btn_h, "New Project", true)) {
        action = .new_project;
    }

    // Help text at bottom
    r.drawTextSmall("Tip: Connect your SPD-SX via USB and it will appear as a drive.", x + 20, y + 260, Colors.text_dim);
    r.drawTextSmall("The configuration is usually in the 'Roland' folder.", x + 20, y + 275, Colors.text_dim);

    // Keyboard shortcut hints
    r.drawTextSmall("Press Enter to Open, Escape for New Project", x + 20, y + dialog_h - 20, Colors.text_dim);

    return action;
}

/// Draw the startup path input field (specialized version for startup screen)
fn drawStartupPathInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, current_value: []const u8) bool {
    const field_id = TextFieldId.startup_path;
    const is_focused = ui.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);

    // Background color based on state
    var bg_color = Colors.slider_bg;
    var border_color = Colors.border;
    if (is_focused) {
        bg_color = Colors.panel_light;
        border_color = Colors.accent;
    } else if (hovered) {
        bg_color = Colors.panel_light;
    }

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, border_color, false);
    if (is_focused) {
        r.drawRect(x + 1, y + 1, w - 2, h - 2, border_color);
    }

    // Determine what text to display
    const display_text = if (is_focused) ui.getInputText() else current_value;
    const max_chars: usize = @intCast(@divFloor(w - 16, 5));
    const display_len = @min(display_text.len, max_chars);

    // Draw text
    const text_y = y + @divFloor(h - 6, 2);
    if (display_text.len > 0) {
        r.drawTextSmall(display_text[0..display_len], x + 8, text_y, Colors.text);
    } else {
        // Placeholder text
        r.drawTextSmall("Enter path here...", x + 8, text_y, Colors.text_dim);
    }

    // Draw cursor when focused
    if (is_focused and ui.cursor_blink < 0.5) {
        const cursor_x = x + 8 + @as(i32, ui.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 4, 1, h - 8, Colors.text);
    }

    // Handle click to focus
    if (ui.isClicked(x, y, w, h)) {
        ui.text_field_clicked_this_frame = true;
        if (!is_focused) {
            ui.startTextInput(field_id, current_value);
        }
        return false;
    }

    return false;
}

/// Apply startup path from text input
pub fn applyStartupPathInput(ui: *EditorUI) void {
    if (ui.focused_field == .startup_path) {
        const text = ui.finishTextInput();
        ui.setStartupPath(text);
    }
}
