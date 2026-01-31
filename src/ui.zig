/// UI Module - Main entry point
/// Imports types and components from ui/ submodules
const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;
const models = @import("models.zig");

// Import from ui/ submodules
pub const types = @import("ui/types.zig");
pub const renderer = @import("ui/renderer.zig");
pub const state = @import("ui/state.zig");
pub const widgets = @import("ui/widgets.zig");

// Re-export types for backwards compatibility
pub const Layout = types.Layout;
pub const Colors = types.Colors;
pub const TextFieldId = types.TextFieldId;
pub const DragType = types.DragType;
pub const DropTarget = types.DropTarget;
pub const AppState = types.AppState;
pub const InputState = types.InputState;
pub const TextInputState = types.TextInputState;
pub const DragDropState = types.DragDropState;
pub const ScrollState = types.ScrollState;
pub const ScrollBounds = types.ScrollBounds;
pub const ContextMenuState = types.ContextMenuState;
pub const ClipboardState = types.ClipboardState;
pub const SampleFileEntry = types.SampleFileEntry;
pub const SampleBrowserState = types.SampleBrowserState;
pub const SampleBrowserAction = types.SampleBrowserAction;
pub const KitChainAction = types.KitChainAction;
pub const ActionButtonsResult = types.ActionButtonsResult;
pub const FileBarAction = types.FileBarAction;
pub const StartupAction = types.StartupAction;
pub const FileDropState = types.FileDropState;

// Re-export Renderer and EditorUI
pub const Renderer = renderer.Renderer;
pub const EditorUI = state.EditorUI;

// Re-export widget functions
pub const drawButton = widgets.drawButton;
pub const drawSlider = widgets.drawSlider;
pub const drawSliderNoValue = widgets.drawSliderNoValue;
pub const drawSignedSlider = widgets.drawSignedSlider;
pub const drawDropdown = widgets.drawDropdown;
pub const drawToggle = widgets.drawToggle;
pub const lerpColor = widgets.lerpColor;
pub const lightenColor = widgets.lightenColor;

// Private widget helpers used in this file
const drawTextBox = widgets.drawTextBox;

/// Draw a single pad with drag and drop support
pub fn drawPad(r: *Renderer, ui: *EditorUI, x: i32, y: i32, size: i32, pad: *const models.Pad, index: u8) bool {
    const modal_blocking = ui.isModalOpen();
    const hovered = ui.isHovered(x, y, size, size) and !modal_blocking;
    const clicked = ui.isClicked(x, y, size, size) and !modal_blocking;
    const right_clicked = ui.input.mouse_right_clicked and hovered and !modal_blocking;
    const is_selected = ui.selected_pad == index;

    if (right_clicked and !ui.context_menu.open) {
        ui.openContextMenu(index);
    }

    const is_drop_target = ui.isDragging() and hovered;
    const half_size = @divFloor(size, 2);
    const in_main_zone = ui.input.mouse_y < y + half_size;
    const current_drop_type: DropTarget = if (is_drop_target)
        (if (in_main_zone) .pad_main else .pad_sub)
    else
        .none;

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

    if (is_drop_target) {
        const main_zone_color: u32 = if (in_main_zone) Colors.accent else Colors.panel_light;
        r.fillRect(x + 2, y + 2, size - 4, half_size - 4, main_zone_color);
        r.drawTextSmall("MAIN", x + @divFloor(size, 2) - 12, y + @divFloor(half_size, 2) - 3, Colors.text);

        const sub_zone_color: u32 = if (!in_main_zone) Colors.accent else Colors.panel_light;
        r.fillRect(x + 2, y + half_size + 2, size - 4, half_size - 4, sub_zone_color);
        r.drawTextSmall("SUB", x + @divFloor(size, 2) - 10, y + half_size + @divFloor(half_size, 2) - 3, Colors.text);

        r.fillRect(x + 4, y + half_size, size - 8, 2, Colors.border);
    } else {
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
    const pad_size = Layout.pad_size;
    const gap = Layout.pad_gap;

    if (ui.isDragging()) {
        r.drawTextSmall("Drop on pad (top=Main, bottom=Sub)", x, y - 14, Colors.accent);
    } else {
        r.drawTextSmall("Drag audio files onto pads to assign", x, y - 14, Colors.text_dim);
    }

    const pad_order = [9]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8 };
    var any_pad_hovered = false;

    for (0..3) |row| {
        for (0..3) |col| {
            const visual_index = row * 3 + col;
            const pad_index = pad_order[visual_index];
            const pad_x = x + @as(i32, @intCast(col)) * (pad_size + gap);
            const pad_y = y + @as(i32, @intCast(row)) * (pad_size + gap);

            if (ui.isHovered(pad_x, pad_y, pad_size, pad_size)) {
                any_pad_hovered = true;
            }

            if (drawPad(r, ui, pad_x, pad_y, pad_size, kit.getPad(pad_index), pad_index)) {
                ui.selected_pad = pad_index;
            }
        }
    }

    if (ui.isDragging() and !any_pad_hovered) {
        ui.clearDropTarget();
    }
}

/// Draw a smaller auxiliary pad
pub fn drawAuxPad(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, pad: *const models.Pad, index: u8, label: []const u8) bool {
    const modal_blocking = ui.isModalOpen();
    const hovered = ui.isHovered(x, y, w, h) and !modal_blocking;
    const clicked = ui.isClicked(x, y, w, h) and !modal_blocking;
    const right_clicked = ui.input.mouse_right_clicked and hovered and !modal_blocking;
    const is_selected = ui.selected_pad == index;

    if (right_clicked and !ui.context_menu.open) {
        ui.openContextMenu(index);
    }

    const is_drop_target = ui.isDragging() and hovered;

    if (is_drop_target) {
        ui.setDropTarget(.pad_main, index);
    }

    var bg_color = if (pad.has_sample) Colors.pad_loaded else Colors.pad_empty;

    if (ui.pad_flash[index] > 0) {
        bg_color = lerpColor(bg_color, Colors.pad_playing, ui.pad_flash[index]);
    }

    if (hovered and !ui.isDragging()) {
        bg_color = lightenColor(bg_color, 0.15);
    }

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawTextSmall(label, x + 4, y + 3, Colors.text);

    if (pad.has_sample) {
        r.fillRect(x + w - 8, y + 4, 4, 4, Colors.accent);
    }

    const vol_height: i32 = @intFromFloat(@as(f32, @floatFromInt(h - 8)) * (@as(f32, @floatFromInt(pad.volume)) / 127.0));
    r.fillRect(x + w - 4, y + h - 2 - vol_height, 2, vol_height, Colors.accent);

    const border_col = if (is_selected) Colors.pad_selected else if (is_drop_target) Colors.accent else Colors.border;
    const border_w: i32 = if (is_selected or is_drop_target) 2 else 1;
    for (0..@intCast(border_w)) |i| {
        const offset: i32 = @intCast(i);
        r.drawRect(x + offset, y + offset, w - 2 * offset, h - 2 * offset, border_col);
    }

    return clicked;
}

/// Draw auxiliary pads section
pub fn drawAuxPadSection(r: *Renderer, ui: *EditorUI, x: i32, y: i32, kit: *models.Kit) void {
    const aux_pad_w = Layout.aux_pad_width;
    const aux_pad_h = Layout.aux_pad_height;
    const gap = Layout.aux_pad_gap;

    var current_y = y + 14;

    const trig_labels = [_][]const u8{ "TRIG1", "TRIG2", "TRIG3", "TRIG4" };
    var trig_x = x;
    for (0..4) |i| {
        const pad_index: u8 = @intCast(models.Kit.NUM_MAIN_PADS + i);
        if (drawAuxPad(r, ui, trig_x, current_y, aux_pad_w, aux_pad_h, kit.getPad(pad_index), pad_index, trig_labels[i])) {
            ui.selected_pad = pad_index;
        }
        trig_x += aux_pad_w + gap;
    }

    current_y += aux_pad_h + gap;

    const fs_labels = [_][]const u8{ "FS 1", "FS 2" };
    var fs_x = x;
    for (0..2) |i| {
        const pad_index: u8 = @intCast(models.Kit.NUM_MAIN_PADS + models.Kit.NUM_TRIGGERS + i);
        if (drawAuxPad(r, ui, fs_x, current_y, aux_pad_w, aux_pad_h, kit.getPad(pad_index), pad_index, fs_labels[i])) {
            ui.selected_pad = pad_index;
        }
        fs_x += aux_pad_w + gap;
    }
}

/// Draw toolbar
pub fn drawToolbar(r: *Renderer, ui: *EditorUI, y: i32, width: i32) void {
    const toolbar_h: i32 = 40;

    r.fillRect(0, y, width, toolbar_h, Colors.panel);
    r.fillRect(0, y + toolbar_h - 1, width, 1, Colors.border);

    r.drawTextLarge("SpeedSX", 12, y + 8, Colors.accent);

    var btn_x: i32 = width - 400;

    if (drawButton(r, ui, btn_x, y + 6, 60, 26, "Kits", true)) {
        ui.show_kit_browser = !ui.show_kit_browser;
    }
    btn_x += 68;

    if (drawButton(r, ui, btn_x, y + 6, 60, 26, "Chains", true)) {
        ui.show_kit_chain = !ui.show_kit_chain;
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

/// Draw status bar
pub fn drawStatusBar(r: *Renderer, y: i32, width: i32, project: *models.Project, ui_state: *const EditorUI) void {
    const bar_h: i32 = 22;

    r.fillRect(0, y, width, bar_h, Colors.panel);
    r.fillRect(0, y, width, 1, Colors.border);

    const status_msg = ui_state.getStatusMessage();
    if (status_msg.len > 0) {
        const status_color: u32 = if (ui_state.isStatusError()) 0xFFE04040 else 0xFF40E040;
        r.drawTextSmall(status_msg, 12, y + 7, status_color);
    } else {
        var kit_buf: [32]u8 = undefined;
        const kit_str = std.fmt.bufPrint(&kit_buf, "Kits: {d}/{d}", .{ project.kit_count, models.Project.MAX_KITS }) catch "?";
        r.drawTextSmall(kit_str, 12, y + 7, Colors.text_dim);

        var pad_buf: [32]u8 = undefined;
        const pad_str = std.fmt.bufPrint(&pad_buf, "Pad: {d}", .{ui_state.selected_pad + 1}) catch "?";
        r.drawTextSmall(pad_str, 110, y + 7, Colors.text_dim);

        var tempo_buf: [32]u8 = undefined;
        const tempo_str = std.fmt.bufPrint(&tempo_buf, "BPM: {d}", .{project.currentKit().tempo}) catch "?";
        r.drawTextSmall(tempo_str, 180, y + 7, Colors.text_dim);
    }
}

/// Draw Kit Settings panel (scrollable)
pub fn drawKitSettingsPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, panel_height: i32, kit: *models.Kit, pad: *models.Pad) void {
    const panel_w: i32 = 200;
    const content_height: i32 = 1350;

    // Store bounds for scroll detection
    ui.scroll.left_panel_bounds = .{ .x = x - 5, .y = y, .w = panel_w + 10, .h = panel_height };
    ui.scroll.left_panel_max_scroll = @max(0, content_height - panel_height);

    // Clamp scroll position
    ui.scroll.left_panel_scroll = std.math.clamp(ui.scroll.left_panel_scroll, 0, ui.scroll.left_panel_max_scroll);

    const scroll_offset = ui.scroll.left_panel_scroll;

    // Helper to check if element is visible
    const isVisible = struct {
        fn check(elem_y: i32, elem_h: i32, view_y: i32, view_h: i32) bool {
            return elem_y + elem_h > view_y and elem_y < view_y + view_h;
        }
    }.check;

    // Draw scrollbar if needed
    if (ui.scroll.left_panel_max_scroll > 0) {
        widgets.drawScrollbar(r, x + panel_w - 2, y, 4, panel_height, scroll_offset, ui.scroll.left_panel_max_scroll);
    }

    var content_y: i32 = 0; // Virtual Y position in content

    // === Kit Section ===
    var draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 20, y, panel_height)) {
        r.drawTextSmall("Kit", x, draw_y, Colors.text);
    }
    content_y += 26;

    // Kit Name
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 32, y, panel_height)) {
        _ = drawTextInput(r, ui, x, draw_y, panel_w - 10, 20, .kit_name, kit.getName(), "Kit Name");
    }
    content_y += 38;

    // Kit Sub Name
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 32, y, panel_height)) {
        _ = drawTextInput(r, ui, x, draw_y, panel_w - 10, 20, .kit_sub_name, kit.getSubName(), "KitSub Name");
    }
    content_y += 38;

    // Volume
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        drawSlider(r, ui, x, draw_y + 10, panel_w - 50, 8, &kit.master_volume, 0, 100, "Volume");
    }
    content_y += 35;

    // Kit Tempo
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 32, y, panel_height)) {
        var tempo_buf: [16]u8 = undefined;
        const tempo_str = std.fmt.bufPrint(&tempo_buf, "{d}.{d}", .{ kit.tempo, kit.tempo_decimal }) catch "120.0";
        _ = drawTextInput(r, ui, x + panel_w - 80, draw_y + 10, 70, 20, .kit_tempo, tempo_str, "Kit Tempo (Bpm)");
    }
    content_y += 38;

    // Pad Link
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 60, 18, kit.pad_link.toString(), "Pad Link")) {
            kit.pad_link = @enumFromInt((@intFromEnum(kit.pad_link) + 1) % 16);
        }
        if (drawDropdown(r, ui, x + 70, draw_y + 10, 60, 18, kit.pad_link_target.toString(), "")) {
            kit.pad_link_target = @enumFromInt((@intFromEnum(kit.pad_link_target) + 1) % 16);
        }
    }
    content_y += 45;

    // === Main Section ===
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 8, y, panel_height)) {
        r.fillRect(x - 5, draw_y, panel_w, 1, Colors.border);
    }
    content_y += 8;

    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 16, y, panel_height)) {
        r.drawTextSmall("Main", x, draw_y, Colors.text);
    }
    content_y += 16;

    // Wave
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 38, y, panel_height)) {
        r.drawTextSmall("Wave", x, draw_y, Colors.text_dim);
        const wave_name = if (pad.has_sample) pad.sample.getName() else "";
        drawTextBox(r, ui, x, draw_y + 10, panel_w - 10, 20, wave_name);
    }
    content_y += 38;

    // Pad Volume
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        drawSlider(r, ui, x, draw_y + 10, panel_w - 50, 8, &pad.volume, 0, 100, "Pad Volume");
    }
    content_y += 35;

    // Pan
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 35, y, panel_height)) {
        r.drawTextSmall("Pan", x, draw_y, Colors.text_dim);
        const pan_text = if (pad.pan == 0) "CENTER" else if (pad.pan < 0) "L" else "R";
        r.drawTextSmall(pan_text, x + panel_w - 60, draw_y, Colors.text);
        drawSignedSlider(r, ui, x, draw_y + 10, panel_w - 50, 8, &pad.pan, -64, 63, "");
    }
    content_y += 35;

    // Mute Group
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.mute_group.toString(), "Mute Group")) {
            pad.mute_group = @enumFromInt((@intFromEnum(pad.mute_group) + 1) % 10);
        }
    }
    content_y += 38;

    // TempoSync
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.tempo_sync.toString(), "TempoSync")) {
            pad.tempo_sync = @enumFromInt((@intFromEnum(pad.tempo_sync) + 1) % 2);
        }
    }
    content_y += 45;

    // === Mode Section ===
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 8, y, panel_height)) {
        r.fillRect(x - 5, draw_y, panel_w, 1, Colors.border);
    }
    content_y += 8;

    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 16, y, panel_height)) {
        r.drawTextSmall("Mode", x, draw_y, Colors.text);
    }
    content_y += 16;

    // Loop
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.loop_mode.toString(), "Loop")) {
            pad.loop_mode = @enumFromInt((@intFromEnum(pad.loop_mode) + 1) % 5);
        }
    }
    content_y += 38;

    // Trigger Type
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.trigger_mode.toString(), "Trigger Type")) {
            pad.trigger_mode = @enumFromInt((@intFromEnum(pad.trigger_mode) + 1) % 2);
        }
    }
    content_y += 38;

    // Dynamics
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.dynamics.toString(), "Dynamics")) {
            pad.dynamics = @enumFromInt((@intFromEnum(pad.dynamics) + 1) % 2);
        }
    }
    content_y += 38;

    // PolyMono
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, pad.poly_mono.toString(), "PolyMono")) {
            pad.poly_mono = @enumFromInt((@intFromEnum(pad.poly_mono) + 1) % 2);
        }
    }
    content_y += 38;

    // Output Assign
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 100, 18, pad.output_assign.toString(), "Output Assign")) {
            pad.output_assign = @enumFromInt((@intFromEnum(pad.output_assign) + 1) % 5);
        }
    }
    content_y += 38;

    // Reverse
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        const reverse_text = if (pad.reverse) "ON" else "OFF";
        if (drawDropdown(r, ui, x, draw_y + 10, 60, 18, reverse_text, "Reverse")) {
            pad.reverse = !pad.reverse;
        }
    }
    content_y += 45;

    // === Sub Section ===
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 8, y, panel_height)) {
        r.fillRect(x - 5, draw_y, panel_w, 1, Colors.border);
    }
    content_y += 8;

    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 16, y, panel_height)) {
        r.drawTextSmall("Sub", x, draw_y, Colors.text);
    }
    content_y += 16;

    // SubWave
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 38, y, panel_height)) {
        r.drawTextSmall("SubWave", x, draw_y, Colors.text_dim);
        const sub_wave_name = if (pad.has_sub_sample) pad.sub_sample.getName() else "";
        drawTextBox(r, ui, x, draw_y + 10, panel_w - 10, 20, sub_wave_name);
    }
    content_y += 38;

    // Sub Volume
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        drawSlider(r, ui, x, draw_y + 10, panel_w - 50, 8, &pad.sub_volume, 0, 100, "Sub Volume");
    }
    content_y += 35;

    // Sub
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 35, y, panel_height)) {
        r.drawTextSmall("Sub Pan", x, draw_y, Colors.text_dim);
        const sub_pan_text = if (pad.sub_pan == 0) "CENTER" else if (pad.sub_pan < 0) "L" else "R";
        r.drawTextSmall(sub_pan_text, x + panel_w - 60, draw_y, Colors.text);
        drawSignedSlider(r, ui, x, draw_y + 10, panel_w - 50, 8, &pad.sub_pan, -64, 63, "");
    }
    content_y += 45;

    // === MIDI Section ===
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 8, y, panel_height)) {
        r.fillRect(x - 5, draw_y, panel_w, 1, Colors.border);
    }
    content_y += 8;

    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 16, y, panel_height)) {
        r.drawTextSmall("MIDI", x, draw_y, Colors.text);
    }
    content_y += 16;

    // MIDI Channel (GLOBAL or 1-16)
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 70, 18, pad.midi_channel.toString(), "Channel")) {
            pad.midi_channel = @enumFromInt((@intFromEnum(pad.midi_channel) + 1) % 17);
        }
    }
    content_y += 38;

    // MIDI Note (OFF or 0-127)
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        var note_buf: [8]u8 = undefined;
        const note_label = if (pad.midi_note < 0) "OFF" else std.fmt.bufPrint(&note_buf, "{d}", .{pad.midi_note}) catch "?";
        r.drawTextSmall("Note", x, draw_y, Colors.text_dim);
        r.drawTextSmall(note_label, x + panel_w - 50, draw_y, Colors.text);
        // Slider for note: internally -1 to 127, display as 0 to 128 where 0 = OFF
        var note_slider_val: u8 = if (pad.midi_note < 0) 0 else @intCast(pad.midi_note + 1);
        drawSliderNoValue(r, ui, x, draw_y + 10, panel_w - 50, 8, &note_slider_val, 0, 128, "");
        pad.midi_note = if (note_slider_val == 0) -1 else @as(i16, note_slider_val) - 1;
    }
    content_y += 35;

    // Ext Ctrl (OFF or ON)
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        const ext_label = if (pad.midi_ext_ctrl) "ON" else "OFF";
        if (drawDropdown(r, ui, x, draw_y + 10, 50, 18, ext_label, "Ext Ctrl")) {
            pad.midi_ext_ctrl = !pad.midi_ext_ctrl;
        }
    }
    content_y += 35;

    // Gate Time (OFF, ALT, or 0.1s-8.0s)
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 25, y, panel_height)) {
        var gate_buf: [16]u8 = undefined;
        const gate_label = if (pad.midi_gate_time == 0)
            "OFF"
        else if (pad.midi_gate_time == 1)
            "ALT"
        else blk: {
            const seconds = @as(f32, @floatFromInt(pad.midi_gate_time - 1)) * 0.1;
            break :blk std.fmt.bufPrint(&gate_buf, "{d:.1}s", .{seconds}) catch "?";
        };
        r.drawTextSmall("Gate", x, draw_y, Colors.text_dim);
        r.drawTextSmall(gate_label, x + panel_w - 50, draw_y, Colors.text);
        drawSliderNoValue(r, ui, x, draw_y + 10, panel_w - 50, 8, &pad.midi_gate_time, 0, 81, "");
    }
    content_y += 45;

    // === FX Section ===
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 8, y, panel_height)) {
        r.fillRect(x - 5, draw_y, panel_w, 1, Colors.border);
    }
    content_y += 8;

    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 16, y, panel_height)) {
        r.drawTextSmall("FX", x, draw_y, Colors.text);
    }
    content_y += 20;

    // FX1 Switch
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        const fx1_sw_text = if (kit.fx1_switch) "ON" else "OFF";
        if (drawDropdown(r, ui, x, draw_y + 10, 50, 18, fx1_sw_text, "FX1")) {
            kit.fx1_switch = !kit.fx1_switch;
        }
    }
    content_y += 38;

    // FX1 Type
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 120, 18, kit.fx1_type.toString(), "FX1 Type")) {
            kit.fx1_type = @enumFromInt((@intFromEnum(kit.fx1_type) + 1) % 20);
        }
    }
    content_y += 38;

    // FX2 Switch
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        const fx2_sw_text = if (kit.fx2_switch) "ON" else "OFF";
        if (drawDropdown(r, ui, x, draw_y + 10, 50, 18, fx2_sw_text, "FX2")) {
            kit.fx2_switch = !kit.fx2_switch;
        }
    }
    content_y += 38;

    // FX2 Type
    draw_y = y + content_y - scroll_offset;
    if (isVisible(draw_y, 30, y, panel_height)) {
        if (drawDropdown(r, ui, x, draw_y + 10, 100, 18, kit.fx2_type.toString(), "FX2 Type")) {
            kit.fx2_type = @enumFromInt((@intFromEnum(kit.fx2_type) + 1) % 7);
        }
    }
    content_y += 38;

    // FX2 Assign
    // draw_y = y + content_y - scroll_offset;
    // if (isVisible(draw_y, 30, y, panel_height)) {
    //     if (drawDropdown(r, ui, x, draw_y + 10, 80, 18, kit.fx2_assign.toString(), "FX2 Assign")) {
    //         kit.fx2_assign = @enumFromInt((@intFromEnum(kit.fx2_assign) + 1) % 16);
    //     }
    // }
    // content_y tracking ends here - used for scroll bounds calculation
}

/// Draw an editable text input field
pub fn drawTextInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, field_id: TextFieldId, current_value: []const u8, label: []const u8) bool {
    const is_focused = ui.text_input.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);

    if (label.len > 0) {
        r.drawTextSmall(label, x, y - 12, Colors.text_dim);
    }

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

    const display_text = if (is_focused) ui.getInputText() else current_value;
    const max_chars: usize = @intCast(@divFloor(w - 8, 5));
    const display_len = @min(display_text.len, max_chars);

    const text_y = y + @divFloor(h - 6, 2);
    r.drawTextSmall(if (display_text.len > 0) display_text[0..display_len] else "", x + 4, text_y, Colors.text);

    if (is_focused and ui.text_input.cursor_blink < 0.5) {
        const cursor_x = x + 4 + @as(i32, ui.text_input.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 3, 1, h - 6, Colors.text);
    }

    if (ui.isClicked(x, y, w, h)) {
        ui.text_input.text_field_clicked_this_frame = true;
        if (!is_focused) {
            ui.startTextInput(field_id, current_value);
        }
        return false;
    }

    return false;
}

/// Apply text input to kit
pub fn applyTextInputToKit(ui: *EditorUI, kit: *models.Kit) void {
    if (ui.text_input.focused_field == .kit_name) {
        const text = ui.finishTextInput();
        kit.setName(text);
    } else if (ui.text_input.focused_field == .kit_sub_name) {
        const text = ui.finishTextInput();
        kit.setSubName(text);
    } else if (ui.text_input.focused_field == .kit_tempo) {
        const text = ui.finishTextInput();
        var tempo: u16 = 0;
        var decimal: u8 = 0;
        var seen_dot = false;
        for (text) |char| {
            if (char == '.') {
                seen_dot = true;
            } else if (char >= '0' and char <= '9') {
                if (seen_dot) {
                    decimal = char - '0';
                    break;
                } else {
                    tempo = tempo * 10 + @as(u16, char - '0');
                }
            }
        }
        if (tempo >= 20 and tempo <= 300) {
            kit.tempo = tempo;
            kit.tempo_decimal = decimal;
        }
        ui.text_input.focused_field = .none;
    }
}

// Re-export remaining drawing functions from drawing.zig
const drawing = @import("ui/drawing.zig");

pub const drawWaveListPanel = drawing.drawWaveListPanel;
pub const drawKitListPanel = drawing.drawKitListPanel;
pub const drawActionButtons = drawing.drawActionButtons;
pub const drawFileBar = drawing.drawFileBar;
pub const drawSampleBrowser = drawing.drawSampleBrowser;
pub const applySampleBrowserPathInput = drawing.applySampleBrowserPathInput;
pub const drawMidiConfig = drawing.drawMidiConfig;
pub const drawSettings = drawing.drawSettings;
pub const drawKitChainEditor = drawing.drawKitChainEditor;
pub const applyKitChainNameInput = drawing.applyKitChainNameInput;
pub const drawPadContextMenu = drawing.drawPadContextMenu;
pub const drawWaveContextMenu = drawing.drawWaveContextMenu;
pub const drawWaveEditor = drawing.drawWaveEditor;
pub const drawDragIndicator = drawing.drawDragIndicator;
pub const applyDropFromLibrary = drawing.applyDropFromLibrary;
pub const drawStartupScreen = drawing.drawStartupScreen;
pub const applyStartupPathInput = drawing.applyStartupPathInput;
