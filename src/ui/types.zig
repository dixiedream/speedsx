/// UI type definitions and constants
const std = @import("std");
const sdl = @import("../sdl.zig");
const c = sdl.c;
const models = @import("../models.zig");

/// Layout constants for consistent UI sizing
pub const Layout = struct {
    // Window and content
    pub const toolbar_height: i32 = 40;
    pub const status_bar_height: i32 = 22;
    pub const file_bar_height: i32 = 50;
    pub const content_y: i32 = 50;

    // Main pad grid
    pub const pad_size: i32 = 90;
    pub const pad_gap: i32 = 8;
    pub const pad_grid_width: i32 = pad_size * 3 + pad_gap * 2; // 286
    pub const pad_grid_height: i32 = pad_size * 3 + pad_gap * 2; // 286
    pub const grid_offset_x: i32 = 30; // Gap between left panel and grid
    pub const grid_offset_y: i32 = 45; // Gap from content_y to grid

    // Auxiliary pads (triggers & footswitches)
    pub const aux_pad_width: i32 = 60;
    pub const aux_pad_height: i32 = 24;
    pub const aux_pad_gap: i32 = 6;

    // Panels
    pub const left_panel_x: i32 = 15;
    pub const left_panel_width: i32 = 200;
    pub const wave_list_width: i32 = 140;
    pub const kit_list_width: i32 = 150;
    pub const right_panel_gap: i32 = 34; // Gap between grid and right panels

    // Buttons
    pub const button_height: i32 = 22;
    pub const button_gap: i32 = 4;

    // List items
    pub const list_item_height: i32 = 14;
    pub const list_header_height: i32 = 18;
    pub const list_padding: i32 = 8;

    // Sliders
    pub const slider_height: i32 = 10;

    // Modals
    pub const modal_padding: i32 = 12;

    // Action buttons position (relative to content_y)
    pub const action_buttons_y: i32 = 380;
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
    kit_chain_name,
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

/// Mouse and input state
pub const InputState = struct {
    mouse_x: i32 = 0,
    mouse_y: i32 = 0,
    mouse_down: bool = false,
    mouse_clicked: bool = false,
    mouse_right_clicked: bool = false,
};

/// Text input/editing state
pub const TextInputState = struct {
    focused_field: TextFieldId = .none,
    input_buffer: [64]u8 = [_]u8{0} ** 64,
    input_len: u8 = 0,
    cursor_pos: u8 = 0,
    cursor_blink: f32 = 0,
    text_field_clicked_this_frame: bool = false,
};

/// Drag and drop state
pub const DragDropState = struct {
    drag_type: DragType = .none,
    drag_wave_index: u16 = 0,
    drag_wave_name: [64]u8 = [_]u8{0} ** 64,
    drag_wave_name_len: u8 = 0,
    drag_start_x: i32 = 0,
    drag_start_y: i32 = 0,
    is_dragging: bool = false,
    drop_target: DropTarget = .none,
    drop_target_pad: u8 = 0,
};

/// Scroll state for lists
pub const ScrollState = struct {
    wave_list_scroll: i32 = 0,
    kit_list_scroll: i32 = 0,
    kit_chain_scroll: i32 = 0,
    left_panel_scroll: i32 = 0,
    wave_list_bounds: ScrollBounds = .{},
    kit_list_bounds: ScrollBounds = .{},
    left_panel_bounds: ScrollBounds = .{},
    wave_list_max_scroll: i32 = 0,
    kit_list_max_scroll: i32 = 0,
    left_panel_max_scroll: i32 = 0,
};

/// Scroll bounds rectangle
pub const ScrollBounds = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,
};

/// Context menu type
pub const ContextMenuType = enum {
    none,
    pad,
    wave,
};

/// Context menu state
pub const ContextMenuState = struct {
    open: bool = false,
    menu_type: ContextMenuType = .none,
    x: i32 = 0,
    y: i32 = 0,
    pad: u8 = 0,
    wave: u16 = 0,
};

/// Clipboard state for copy/paste
pub const ClipboardState = struct {
    pad: ?models.Pad = null,
};

/// Sample file entry for browser
pub const SampleFileEntry = struct {
    name: models.BoundedString(64) = .{},
    path: models.BoundedString(256) = .{},

    pub fn getName(self: *const SampleFileEntry) []const u8 {
        return self.name.get();
    }

    pub fn getPath(self: *const SampleFileEntry) []const u8 {
        return self.path.get();
    }

    pub fn setName(self: *SampleFileEntry, new_name: []const u8) void {
        self.name.set(new_name);
    }

    pub fn setPath(self: *SampleFileEntry, new_path: []const u8) void {
        self.path.set(new_path);
    }
};

/// Sample browser modal state
pub const SampleBrowserState = struct {
    path: models.BoundedString(256) = .{},
    files: [128]SampleFileEntry = undefined,
    file_count: u16 = 0,
    selected: u16 = 0,
    scroll: i32 = 0,
    max_scroll: i32 = 0,
    scanning: bool = false,
    error_msg: models.BoundedString(64) = .{},
    path_initialized: bool = false,

    pub fn getPath(self: *const SampleBrowserState) []const u8 {
        return self.path.get();
    }

    pub fn setPath(self: *SampleBrowserState, new_path: []const u8) void {
        self.path.set(new_path);
        self.path_initialized = true;
    }

    pub fn getError(self: *const SampleBrowserState) []const u8 {
        return self.error_msg.get();
    }

    pub fn setError(self: *SampleBrowserState, msg: []const u8) void {
        self.error_msg.set(msg);
    }

    pub fn clearError(self: *SampleBrowserState) void {
        self.error_msg.clear();
    }

    pub fn addFile(self: *SampleBrowserState, name: []const u8, file_path: []const u8) bool {
        if (self.file_count >= 128) return false;

        var entry = &self.files[self.file_count];
        entry.setName(name);
        entry.setPath(file_path);

        self.file_count += 1;
        return true;
    }

    pub fn getSelectedFile(self: *const SampleBrowserState) ?*const SampleFileEntry {
        if (self.selected >= self.file_count) return null;
        return &self.files[self.selected];
    }

    /// Initialize path with home directory if not already set
    pub fn initializeDefaultPath(self: *SampleBrowserState) void {
        if (self.path_initialized) return;

        // Try to get home directory from environment
        // Linux/macOS: HOME, Windows: USERPROFILE
        const home = std.posix.getenv("HOME") orelse
            std.posix.getenv("USERPROFILE") orelse
            "/";

        self.path.set(home);
        self.path_initialized = true;
    }
};

/// Action result types
pub const SampleBrowserAction = struct {
    scan_path: bool = false,
    play_selected: bool = false,
    load_selected: bool = false,
    close: bool = false,
};

pub const KitChainAction = struct {
    close: bool = false,
};

pub const ActionButtonsResult = struct {
    play_sample: bool = false,
    stop_sample: bool = false,
    import_sample: bool = false,
    delete_wave: bool = false,
    wave_to_delete: u16 = 0,
};

pub const FileBarAction = struct {
    needs_open: bool = false, // Open a different folder (go to startup)
    needs_reload: bool = false, // Reload current configuration
    needs_save: bool = false,
};

pub const StartupAction = enum {
    none,
    open_project, // User clicked Open - load from path
    new_project, // User clicked New Project - start fresh
};

/// Wave editor modal state
pub const WaveEditorState = struct {
    wave_index: u16 = 0, // Index in sample library
    waveform_data: [512]i16 = [_]i16{0} ** 512, // Downsampled waveform for display
    waveform_loaded: bool = false,
    total_samples: u32 = 0, // Total samples in the file
    sample_rate: u32 = 44100,
    channels: u8 = 2,

    // Editable parameters
    start_point: u32 = 0, // Start point in samples
    end_point: u32 = 0, // End point in samples
    tempo: u16 = 0, // BPM * 10 (0 = not set)
    beat: u8 = 0,
    measure: u8 = 0,
    tag: u8 = 1, // Tag category (1-12)

    // UI state
    dragging_start: bool = false,
    dragging_end: bool = false,
    zoom_level: u8 = 1, // 1 = full view, higher = zoomed in
    scroll_offset: u32 = 0, // For zoomed view

    pub fn reset(self: *WaveEditorState) void {
        self.wave_index = 0;
        self.waveform_loaded = false;
        self.total_samples = 0;
        self.start_point = 0;
        self.end_point = 0;
        self.tempo = 0;
        self.beat = 0;
        self.measure = 0;
        self.tag = 1;
        self.dragging_start = false;
        self.dragging_end = false;
        self.zoom_level = 1;
        self.scroll_offset = 0;
        @memset(&self.waveform_data, 0);
    }

    /// Get start point as a normalized position (0.0 to 1.0)
    pub fn getStartNormalized(self: *const WaveEditorState) f32 {
        if (self.total_samples == 0) return 0.0;
        return @as(f32, @floatFromInt(self.start_point)) / @as(f32, @floatFromInt(self.total_samples));
    }

    /// Get end point as a normalized position (0.0 to 1.0)
    pub fn getEndNormalized(self: *const WaveEditorState) f32 {
        if (self.total_samples == 0) return 1.0;
        return @as(f32, @floatFromInt(self.end_point)) / @as(f32, @floatFromInt(self.total_samples));
    }

    /// Set start point from normalized position
    pub fn setStartFromNormalized(self: *WaveEditorState, norm: f32) void {
        const clamped = std.math.clamp(norm, 0.0, 1.0);
        self.start_point = @intFromFloat(clamped * @as(f32, @floatFromInt(self.total_samples)));
        // Ensure start < end
        if (self.start_point >= self.end_point and self.end_point > 0) {
            self.start_point = self.end_point - 1;
        }
    }

    /// Set end point from normalized position
    pub fn setEndFromNormalized(self: *WaveEditorState, norm: f32) void {
        const clamped = std.math.clamp(norm, 0.0, 1.0);
        self.end_point = @intFromFloat(clamped * @as(f32, @floatFromInt(self.total_samples)));
        // Ensure end > start
        if (self.end_point <= self.start_point) {
            self.end_point = self.start_point + 1;
        }
    }

    /// Get duration in milliseconds
    pub fn getDurationMs(self: *const WaveEditorState) u32 {
        if (self.sample_rate == 0 or self.total_samples == 0) return 0;
        const samples = if (self.end_point > self.start_point)
            self.end_point - self.start_point
        else
            self.total_samples;
        return @intCast((@as(u64, samples) * 1000) / self.sample_rate);
    }
};

/// Wave editor action results
pub const WaveEditorAction = struct {
    close: bool = false,
    save: bool = false, // Apply changes to the sample
    play_preview: bool = false, // Play the sample with current start/end
};

/// Wave context menu action result
pub const WaveContextMenuAction = struct {
    open_editor: bool = false,
    delete_wave: bool = false,
    wave_to_delete: u16 = 0,
};

/// File drop from host OS state
pub const FileDropState = struct {
    /// Whether a file was just dropped this frame
    has_drop: bool = false,
    /// The path of the dropped file
    path: models.BoundedString(512) = .{},
    /// Mouse position when drop occurred
    drop_x: i32 = 0,
    drop_y: i32 = 0,

    /// Record a file drop event
    pub fn recordDrop(self: *FileDropState, file_path: []const u8, mouse_x: i32, mouse_y: i32) void {
        self.has_drop = true;
        self.path.set(file_path);
        self.drop_x = mouse_x;
        self.drop_y = mouse_y;
    }

    /// Get the dropped file path
    pub fn getPath(self: *const FileDropState) []const u8 {
        return self.path.get();
    }

    /// Clear the drop state (call after handling)
    pub fn clear(self: *FileDropState) void {
        self.has_drop = false;
        self.path.clear();
    }

    /// Check if the dropped file is a directory (for configuration path)
    pub fn isDirectory(self: *const FileDropState) bool {
        const path = self.getPath();
        if (path.len == 0) return false;

        // Try to open as directory
        var dir = std.fs.cwd().openDir(path, .{}) catch return false;
        dir.close();
        return true;
    }

    /// Check if the dropped file is an audio file
    pub fn isAudioFile(self: *const FileDropState) bool {
        const path = self.getPath();
        if (path.len == 0) return false;

        // Check file extension
        const lower_check = struct {
            fn check(p: []const u8, ext: []const u8) bool {
                if (p.len < ext.len) return false;
                const suffix = p[p.len - ext.len ..];
                for (suffix, ext) |c1, c2| {
                    const lower1 = if (c1 >= 'A' and c1 <= 'Z') c1 + 32 else c1;
                    if (lower1 != c2) return false;
                }
                return true;
            }
        }.check;

        return lower_check(path, ".wav") or
            lower_check(path, ".aiff") or
            lower_check(path, ".aif");
    }

    /// Get the filename from the path
    pub fn getFilename(self: *const FileDropState) []const u8 {
        const path = self.getPath();
        if (path.len == 0) return "";

        // Find last separator
        var last_sep: usize = 0;
        for (path, 0..) |ch, i| {
            if (ch == '/' or ch == '\\') {
                last_sep = i + 1;
            }
        }

        if (last_sep >= path.len) return "";
        return path[last_sep..];
    }
};
