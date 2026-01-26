/// Additional drawing functions for UI panels, modals, and complex components
const std = @import("std");
const models = @import("../models.zig");
const types = @import("types.zig");
const renderer = @import("renderer.zig");
const state = @import("state.zig");
const widgets = @import("widgets.zig");

const Colors = types.Colors;
const Layout = types.Layout;
const TextFieldId = types.TextFieldId;
const Renderer = renderer.Renderer;
const EditorUI = state.EditorUI;
const drawButton = widgets.drawButton;
const drawSlider = widgets.drawSlider;
const drawSignedSlider = widgets.drawSignedSlider;
const drawDropdown = widgets.drawDropdown;
const drawToggle = widgets.drawToggle;
const drawScrollbar = widgets.drawScrollbar;
const drawGreenButton = widgets.drawGreenButton;
const lerpColor = widgets.lerpColor;
const lightenColor = widgets.lightenColor;

/// Draw Wave/Sample list panel
pub fn drawWaveListPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const panel_w: i32 = 140;
    const panel_h: i32 = 360;
    const header_h: i32 = 18;
    const item_h: i32 = 14;
    const list_padding: i32 = 8;

    ui.scroll.wave_list_bounds = .{ .x = x, .y = y, .w = panel_w, .h = panel_h };

    // Update sample usage cache if dirty
    ui.updateSampleUsageCache(project);

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    const library = &project.sample_library;
    var title_buf: [32]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Waves ({d})", .{library.count}) catch "Waves";
    r.drawTextSmall(title, x + 4, y + 4, Colors.text_dim);

    const total_items: i32 = @intCast(library.count);
    const visible_height = panel_h - header_h - list_padding;
    const total_content_height = @max(1, total_items) * item_h;
    ui.scroll.wave_list_max_scroll = @max(0, total_content_height - visible_height);

    const list_top = y + header_h;
    const list_bottom = y + panel_h - list_padding;

    if (ui.scroll.wave_list_max_scroll > 0) {
        drawScrollbar(r, x + panel_w - 6, list_top, 4, visible_height, ui.scroll.wave_list_scroll, ui.scroll.wave_list_max_scroll);
    }

    if (library.count == 0) {
        r.drawTextSmall("No waves", x + 30, y + panel_h / 2 - 12, Colors.text_dim);
        r.drawTextSmall("Drop audio", x + 26, y + panel_h / 2 + 2, Colors.text_dim);
        r.drawTextSmall("files here", x + 30, y + panel_h / 2 + 14, Colors.text_dim);
        return;
    }

    var i: u16 = 0;
    while (i < library.count) : (i += 1) {
        const item_y = list_top + @as(i32, @intCast(i)) * item_h - ui.scroll.wave_list_scroll;

        if (item_y + item_h < list_top or item_y >= list_bottom) continue;

        const sample = &library.samples[i];
        const sample_name = sample.getName();
        const is_used = ui.isSampleUsed(i);
        const is_selected = ui.selected_wave == i;
        const item_hovered = ui.isHovered(x + 4, item_y, panel_w - 12, item_h) and item_y >= list_top and item_y + item_h <= list_bottom;

        if (item_hovered and !ui.isDragging() and !ui.isModalOpen()) {
            r.fillRect(x + 2, item_y - 1, panel_w - 10, item_h, Colors.panel_light);
        }

        const indicator_color: u32 = if (is_used) 0xFFA02828 else Colors.text_dim;
        r.fillRect(x + 4, item_y + 2, 8, 8, indicator_color);

        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i + 1}) catch "?";
        r.drawTextSmall(num_str, x + 16, item_y + 1, Colors.text_dim);

        const display_len = @min(sample_name.len, 12);
        const text_color = if (is_selected) Colors.accent else Colors.text;
        r.drawTextSmall(sample_name[0..display_len], x + 34, item_y + 1, text_color);

        if (!ui.isModalOpen() and item_hovered and ui.isClicked(x + 4, item_y, panel_w - 12, item_h)) {
            ui.selected_wave = i;
        }

        // Right-click to open context menu
        if (!ui.isModalOpen() and item_hovered and ui.input.mouse_right_clicked) {
            ui.selected_wave = i;
            ui.openWaveContextMenu(i);
        }

        if (!ui.isModalOpen() and item_hovered and ui.input.mouse_down and ui.drag.drag_type == .none and sample_name.len > 0) {
            ui.startDragWave(i, sample_name);
        }
    }
}

/// Draw Kit list panel
pub fn drawKitListPanel(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) void {
    const panel_w: i32 = 150;
    const panel_h: i32 = 260;
    const header_h: i32 = 18;
    const item_h: i32 = 14;
    const list_padding: i32 = 8;

    ui.scroll.kit_list_bounds = .{ .x = x, .y = y, .w = panel_w, .h = panel_h };

    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.panel, true);
    r.drawRoundedRect(x, y, panel_w, panel_h, Colors.border, false);

    r.drawTextSmall("Kits", x + 4, y + 4, Colors.text_dim);

    const total_items: i32 = @intCast(project.kit_count);
    const visible_height = panel_h - header_h - list_padding;
    const total_content_height = total_items * item_h;
    ui.scroll.kit_list_max_scroll = @max(0, total_content_height - visible_height);

    const list_top = y + header_h;
    const list_bottom = y + panel_h - list_padding;

    if (ui.scroll.kit_list_max_scroll > 0) {
        drawScrollbar(r, x + panel_w - 6, list_top, 4, visible_height, ui.scroll.kit_list_scroll, ui.scroll.kit_list_max_scroll);
    }

    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        const item_y = list_top + @as(i32, i) * item_h - ui.scroll.kit_list_scroll;

        if (item_y + item_h < list_top or item_y >= list_bottom) continue;

        const kit = &project.kits[i];
        const is_selected = project.current_kit_index == i;
        const item_hovered = ui.isHovered(x + 4, item_y, panel_w - 12, item_h) and item_y >= list_top and item_y + item_h <= list_bottom;

        if (item_hovered and !ui.isModalOpen()) {
            r.fillRect(x + 2, item_y - 1, panel_w - 10, item_h, Colors.panel_light);
        }

        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{i + 1}) catch "?";
        r.drawTextSmall(num_str, x + 6, item_y + 1, Colors.text_dim);

        const name = kit.getName();
        const display_len = @min(name.len, 16);
        const text_color = if (is_selected) Colors.accent else Colors.text;
        r.drawTextSmall(name[0..display_len], x + 24, item_y + 1, text_color);

        if (!ui.isModalOpen() and item_hovered and ui.isClicked(x + 4, item_y, panel_w - 12, item_h)) {
            project.selectKit(i);
            ui.selected_kit = i;
        }
    }
}

/// Draw action buttons panel
pub fn drawActionButtons(r: *Renderer, ui: *EditorUI, x: i32, y: i32, project: *models.Project) types.ActionButtonsResult {
    var result = types.ActionButtonsResult{};
    const btn_w: i32 = 65;
    const btn_h: i32 = 22;
    const gap: i32 = 4;

    const modal_blocking = ui.isModalOpen();

    var btn_x = x;
    var btn_y = y;

    const current_pad = project.currentKit().getPad(ui.selected_pad);
    const has_sample = current_pad.has_sample and !modal_blocking;

    if (drawGreenButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Play", has_sample)) {
        result.play_sample = true;
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Stop", !modal_blocking)) {
        result.stop_sample = true;
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Init Kit", !modal_blocking)) {
        project.initKit(project.current_kit_index);
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Up", !modal_blocking and project.current_kit_index > 0)) {
        _ = project.moveKitUp(project.current_kit_index);
    }

    btn_x = x;
    btn_y += btn_h + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Import wav", !modal_blocking)) {
        ui.openSampleBrowser();
    }
    btn_x += btn_w + gap;

    // Delete the selected wave from the sample library (handled by main.zig for file deletion)
    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Delete wav", !modal_blocking and project.sample_library.count > 0)) {
        result.delete_wave = true;
        result.wave_to_delete = ui.selected_wave;
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Delete Kit", !modal_blocking and project.kit_count > 1)) {
        _ = project.deleteKit(project.current_kit_index);
        ui.invalidateSampleUsageCache();
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Down", !modal_blocking and project.current_kit_index < project.kit_count - 1)) {
        _ = project.moveKitDown(project.current_kit_index);
    }

    btn_x = x;
    btn_y += btn_h + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Duplicate", !modal_blocking and project.kit_count < models.Project.MAX_KITS)) {
        _ = project.duplicateKit(project.current_kit_index);
    }
    btn_x += btn_w + gap;

    if (drawButton(r, ui, btn_x, btn_y, btn_w, btn_h, "Add new Kit", !modal_blocking and project.kit_count < models.Project.MAX_KITS)) {
        _ = project.addKit();
    }

    return result;
}

/// Draw file bar
pub fn drawFileBar(r: *Renderer, ui: *EditorUI, x: i32, y: i32, width: i32, project: *models.Project) types.FileBarAction {
    var action = types.FileBarAction{};
    const bar_h: i32 = 28;
    const btn_w: i32 = 60;

    r.fillRect(x, y, width, bar_h, Colors.panel);
    r.fillRect(x, y, width, 1, Colors.border);

    const path = project.getFilePath();
    const path_display = if (path.len > 0) path else "/Volumes/SPD-SX_/Roland";
    r.drawTextSmall(path_display, x + 10, y + 10, Colors.text_dim);

    // Open button (select different folder)
    const open_x = x + width - 210;
    if (ui.isHovered(open_x, y + 4, btn_w, 20)) {
        r.fillRect(open_x, y + 4, btn_w, 20, 0xFF3A8A3A);
    } else {
        r.fillRect(open_x, y + 4, btn_w, 20, 0xFF2A7A2A);
    }
    r.drawTextSmall("Open", open_x + 16, y + 10, Colors.text);
    if (ui.isClicked(open_x, y + 4, btn_w, 20)) {
        action.needs_open = true;
    }

    // Reload button (reload current configuration)
    const reload_x = x + width - 140;
    if (drawButton(r, ui, reload_x, y + 4, btn_w, 20, "Reload", true)) {
        action.needs_reload = true;
    }

    const save_x = x + width - 70;
    if (drawButton(r, ui, save_x, y + 4, btn_w, 20, "Save", true)) {
        action.needs_save = true;
    }

    return action;
}

/// Draw sample browser modal
pub fn drawSampleBrowser(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32) types.SampleBrowserAction {
    var action = types.SampleBrowserAction{};

    const modal_w: i32 = 500;
    const modal_h: i32 = 420;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    r.drawTextLarge("LOAD SAMPLE", x + 12, y + 10, Colors.text);

    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        action.close = true;
    }

    var current_y = y + 42;

    r.drawTextSmall("Sample Folder Path:", x + 12, current_y, Colors.text);
    current_y += 14;

    const path_input_w = modal_w - 110;
    _ = drawSampleBrowserPathInput(r, ui, x + 12, current_y, path_input_w, 24);

    if (drawButton(r, ui, x + path_input_w + 20, current_y, 70, 24, "Scan", true)) {
        action.scan_path = true;
    }

    current_y += 32;

    const error_msg = ui.getSampleBrowserError();
    if (error_msg.len > 0) {
        r.drawTextSmall(error_msg, x + 12, current_y, 0xFFE04040);
        current_y += 14;
    }

    const list_x = x + 12;
    const list_y = current_y + 4;
    const list_w = modal_w - 24;
    const list_h: i32 = 240;
    const item_h: i32 = 18;

    r.fillRect(list_x, list_y, list_w, list_h, Colors.slider_bg);
    r.drawRect(list_x, list_y, list_w, list_h, Colors.border);

    if (ui.sample_browser.file_count == 0) {
        r.drawText("No samples found", list_x + @divFloor(list_w, 2) - 70, list_y + @divFloor(list_h, 2) - 6, Colors.text_dim);
        r.drawTextSmall("Enter a folder path and click Scan", list_x + @divFloor(list_w, 2) - 80, list_y + @divFloor(list_h, 2) + 10, Colors.text_dim);
    } else {
        const total_items: i32 = @intCast(ui.sample_browser.file_count);
        const total_content_height = total_items * item_h;
        ui.sample_browser.max_scroll = @max(0, total_content_height - list_h);

        if (ui.sample_browser.max_scroll > 0) {
            drawScrollbar(r, list_x + list_w - 6, list_y + 2, 4, list_h - 4, ui.sample_browser.scroll, ui.sample_browser.max_scroll);
        }

        var i: u16 = 0;
        while (i < ui.sample_browser.file_count) : (i += 1) {
            const fitem_y = list_y + @as(i32, @intCast(i)) * item_h - ui.sample_browser.scroll;

            if (fitem_y + item_h < list_y or fitem_y >= list_y + list_h) continue;

            const file = &ui.sample_browser.files[i];
            const is_selected = ui.sample_browser.selected == i;
            const item_hovered = ui.isHovered(list_x + 2, fitem_y, list_w - 12, item_h) and
                fitem_y >= list_y and fitem_y + item_h <= list_y + list_h;

            if (is_selected) {
                r.fillRect(list_x + 2, fitem_y, list_w - 12, item_h, Colors.accent_dark);
            } else if (item_hovered) {
                r.fillRect(list_x + 2, fitem_y, list_w - 12, item_h, Colors.panel_light);
            }

            r.drawTextSmall("~", list_x + 6, fitem_y + 4, Colors.accent);

            const file_name = file.getName();
            const display_len = @min(file_name.len, 50);
            r.drawTextSmall(file_name[0..display_len], list_x + 18, fitem_y + 4, Colors.text);

            if (item_hovered and ui.isClicked(list_x + 2, fitem_y, list_w - 12, item_h)) {
                ui.sample_browser.selected = i;
            }
        }
    }

    current_y = list_y + list_h + 10;

    const btn_w: i32 = 90;
    const btn_h: i32 = 28;
    const btn_gap: i32 = 10;
    const total_btn_w = btn_w * 3 + btn_gap * 2;
    const btn_x = x + @divFloor(modal_w - total_btn_w, 2);

    const has_selection = ui.sample_browser.file_count > 0 and ui.sample_browser.selected < ui.sample_browser.file_count;
    if (drawGreenButton(r, ui, btn_x, current_y, btn_w, btn_h, "Play", has_selection)) {
        action.play_selected = true;
    }

    if (drawButton(r, ui, btn_x + btn_w + btn_gap, current_y, btn_w, btn_h, "Load", has_selection)) {
        action.load_selected = true;
    }

    if (drawButton(r, ui, btn_x + (btn_w + btn_gap) * 2, current_y, btn_w, btn_h, "Cancel", true)) {
        action.close = true;
    }

    current_y += btn_h + 10;

    r.drawTextSmall("Supported: WAV, AIFF | Drag & drop files to import directly", x + 12, current_y, Colors.text_dim);

    return action;
}

fn drawSampleBrowserPathInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32) bool {
    const field_id = TextFieldId.sample_browser_path;
    const is_focused = ui.text_input.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);
    const current_value = ui.getSampleBrowserPath();

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
    const max_chars: usize = @intCast(@divFloor(w - 16, 5));
    const display_len = @min(display_text.len, max_chars);

    const text_y = y + @divFloor(h - 6, 2);
    if (display_text.len > 0) {
        r.drawTextSmall(display_text[0..display_len], x + 8, text_y, Colors.text);
    } else {
        r.drawTextSmall("/path/to/samples", x + 8, text_y, Colors.text_dim);
    }

    if (is_focused and ui.text_input.cursor_blink < 0.5) {
        const cursor_x = x + 8 + @as(i32, ui.text_input.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 4, 1, h - 8, Colors.text);
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

/// Apply sample browser path input
pub fn applySampleBrowserPathInput(ui: *EditorUI) void {
    if (ui.text_input.focused_field == .sample_browser_path) {
        const text = ui.finishTextInput();
        ui.setSampleBrowserPath(text);
    }
}

/// Draw kit chain name input field
fn drawKitChainNameInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, chain: *models.KitChain) bool {
    const field_id = TextFieldId.kit_chain_name;
    const is_focused = ui.text_input.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);
    const current_value = chain.getName();

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
    const max_chars: usize = @intCast(@divFloor(w - 16, 5));
    const display_len = @min(display_text.len, max_chars);

    const text_y = y + @divFloor(h - 6, 2);
    if (display_text.len > 0) {
        r.drawTextSmall(display_text[0..display_len], x + 6, text_y, Colors.accent);
    } else {
        r.drawTextSmall("Enter chain name...", x + 6, text_y, Colors.text_dim);
    }

    if (is_focused and ui.text_input.cursor_blink < 0.5) {
        const cursor_x = x + 6 + @as(i32, ui.text_input.cursor_pos) * 5;
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

/// Apply kit chain name input
pub fn applyKitChainNameInput(ui: *EditorUI, project: *models.Project) void {
    if (ui.text_input.focused_field == .kit_chain_name) {
        const text = ui.finishTextInput();
        if (ui.selected_chain < project.kit_chain_library.count) {
            project.kit_chain_library.chains[ui.selected_chain].setName(text);
        }
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

/// Draw wave editor modal
pub fn drawWaveEditor(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32, sample: *models.Sample) types.WaveEditorAction {
    var action = types.WaveEditorAction{};

    const modal_w: i32 = 600;
    const modal_h: i32 = 420;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    // Dim background
    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    // Modal panel
    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    // Title
    const sample_name = sample.getName();
    var title_buf: [80]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Wave Editor: {s}", .{sample_name}) catch "Wave Editor";
    r.drawTextLarge(title, x + 12, y + 10, Colors.text);

    // Close button
    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        action.close = true;
    }

    var current_y = y + 40;

    // Waveform display area
    const waveform_x = x + 16;
    const waveform_y = current_y;
    const waveform_w = modal_w - 32;
    const waveform_h: i32 = 150;

    // Waveform background
    r.fillRect(waveform_x, waveform_y, waveform_w, waveform_h, Colors.slider_bg);
    r.drawRect(waveform_x, waveform_y, waveform_w, waveform_h, Colors.border);

    // Draw center line
    const center_line_y = waveform_y + @divFloor(waveform_h, 2);
    r.fillRect(waveform_x, center_line_y, waveform_w, 1, Colors.border);

    // Draw waveform
    if (ui.wave_editor.waveform_loaded) {
        const data = &ui.wave_editor.waveform_data;
        const num_points = @min(data.len, @as(usize, @intCast(waveform_w)));
        const half_height = @divFloor(waveform_h, 2) - 4;

        var i: usize = 0;
        while (i < num_points) : (i += 1) {
            const sample_val = data[i * data.len / num_points];
            const normalized = @as(f32, @floatFromInt(sample_val)) / 32768.0;
            const bar_height: i32 = @intFromFloat(@abs(normalized) * @as(f32, @floatFromInt(half_height)));

            if (bar_height > 0) {
                const bar_x = waveform_x + @as(i32, @intCast(i));
                r.fillRect(bar_x, center_line_y - bar_height, 1, bar_height * 2, Colors.slider_fill);
            }
        }
    } else {
        r.drawTextSmall("Loading waveform...", waveform_x + waveform_w / 2 - 50, center_line_y - 6, Colors.text_dim);
    }

    // Draw start marker
    if (ui.wave_editor.total_samples > 0) {
        const start_norm = ui.wave_editor.getStartNormalized();
        const start_x = waveform_x + @as(i32, @intFromFloat(start_norm * @as(f32, @floatFromInt(waveform_w))));
        r.fillRect(start_x, waveform_y, 2, waveform_h, 0xFF40E040); // Green

        // Start handle (draggable)
        const start_handle_y = waveform_y + waveform_h - 12;
        r.fillRect(start_x - 4, start_handle_y, 10, 12, 0xFF40E040);
        r.drawTextSmall("S", start_x - 2, start_handle_y + 2, 0xFF000000);

        // Handle dragging
        if (ui.isHovered(start_x - 6, waveform_y, 14, waveform_h) and ui.input.mouse_down) {
            ui.wave_editor.dragging_start = true;
        }
    }

    // Draw end marker
    if (ui.wave_editor.total_samples > 0) {
        const end_norm = ui.wave_editor.getEndNormalized();
        const end_x = waveform_x + @as(i32, @intFromFloat(end_norm * @as(f32, @floatFromInt(waveform_w))));
        r.fillRect(end_x - 1, waveform_y, 2, waveform_h, 0xFFE04040); // Red

        // End handle (draggable)
        const end_handle_y = waveform_y;
        r.fillRect(end_x - 5, end_handle_y, 10, 12, 0xFFE04040);
        r.drawTextSmall("E", end_x - 3, end_handle_y + 2, 0xFF000000);

        // Handle dragging
        if (ui.isHovered(end_x - 6, waveform_y, 14, waveform_h) and ui.input.mouse_down) {
            ui.wave_editor.dragging_end = true;
        }
    }

    // Handle marker dragging
    if (ui.wave_editor.dragging_start and ui.input.mouse_down) {
        const relative_x = @as(f32, @floatFromInt(ui.input.mouse_x - waveform_x)) / @as(f32, @floatFromInt(waveform_w));
        ui.wave_editor.setStartFromNormalized(relative_x);
    } else {
        ui.wave_editor.dragging_start = false;
    }

    if (ui.wave_editor.dragging_end and ui.input.mouse_down) {
        const relative_x = @as(f32, @floatFromInt(ui.input.mouse_x - waveform_x)) / @as(f32, @floatFromInt(waveform_w));
        ui.wave_editor.setEndFromNormalized(relative_x);
    } else {
        ui.wave_editor.dragging_end = false;
    }

    current_y += waveform_h + 16;

    // Info row
    const info_x = x + 16;
    var info_buf: [64]u8 = undefined;

    // Duration display
    const duration_ms = ui.wave_editor.getDurationMs();
    const duration_sec = @as(f32, @floatFromInt(duration_ms)) / 1000.0;
    const duration_text = std.fmt.bufPrint(&info_buf, "Duration: {d:.2}s", .{duration_sec}) catch "Duration: ?";
    r.drawTextSmall(duration_text, info_x, current_y, Colors.text);

    // Sample rate
    var sr_buf: [32]u8 = undefined;
    const sr_text = std.fmt.bufPrint(&sr_buf, "{d}Hz {d}ch", .{ ui.wave_editor.sample_rate, ui.wave_editor.channels }) catch "?";
    r.drawTextSmall(sr_text, info_x + 150, current_y, Colors.text_dim);

    current_y += 24;

    // Start/End point controls
    const ctrl_x = x + 16;
    const ctrl_w = (modal_w - 48) / 2;

    r.drawTextSmall("Start Point", ctrl_x, current_y, Colors.text_dim);
    var start_buf: [16]u8 = undefined;
    const start_text = std.fmt.bufPrint(&start_buf, "{d}", .{ui.wave_editor.start_point}) catch "0";
    r.drawTextSmall(start_text, ctrl_x + 80, current_y, Colors.text);

    r.drawTextSmall("End Point", ctrl_x + ctrl_w + 16, current_y, Colors.text_dim);
    var end_buf: [16]u8 = undefined;
    const end_text = std.fmt.bufPrint(&end_buf, "{d}", .{ui.wave_editor.end_point}) catch "0";
    r.drawTextSmall(end_text, ctrl_x + ctrl_w + 96, current_y, Colors.text);

    current_y += 28;

    // Tempo control
    r.drawTextSmall("Tempo", ctrl_x, current_y, Colors.text_dim);
    var tempo_slider_val: u8 = @intCast(@min(ui.wave_editor.tempo / 10, 255));
    drawSlider(r, ui, ctrl_x + 60, current_y, 120, 8, &tempo_slider_val, 0, 250, "");
    ui.wave_editor.tempo = @as(u16, tempo_slider_val) * 10;
    var tempo_buf: [16]u8 = undefined;
    const tempo_text = if (ui.wave_editor.tempo == 0)
        "OFF"
    else
        std.fmt.bufPrint(&tempo_buf, "{d}", .{ui.wave_editor.tempo / 10}) catch "?";
    r.drawTextSmall(tempo_text, ctrl_x + 190, current_y, Colors.text);

    current_y += 28;

    // Tag control
    r.drawTextSmall("Tag", ctrl_x, current_y, Colors.text_dim);
    drawSlider(r, ui, ctrl_x + 60, current_y, 120, 8, &ui.wave_editor.tag, 1, 12, "");
    var tag_buf: [8]u8 = undefined;
    const tag_text = std.fmt.bufPrint(&tag_buf, "{d}", .{ui.wave_editor.tag}) catch "?";
    r.drawTextSmall(tag_text, ctrl_x + 190, current_y, Colors.text);

    current_y += 36;

    // Action buttons
    const btn_w: i32 = 80;
    const btn_h: i32 = 28;
    const btn_gap: i32 = 12;
    var btn_x = x + @divFloor(modal_w - (btn_w * 3 + btn_gap * 2), 2);

    if (drawButton(r, ui, btn_x, current_y, btn_w, btn_h, "Preview", true)) {
        action.play_preview = true;
    }
    btn_x += btn_w + btn_gap;

    if (drawGreenButton(r, ui, btn_x, current_y, btn_w, btn_h, "Save", true)) {
        action.save = true;
        action.close = true;
    }
    btn_x += btn_w + btn_gap;

    if (drawButton(r, ui, btn_x, current_y, btn_w, btn_h, "Cancel", true)) {
        action.close = true;
    }

    return action;
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

/// Draw Kit Chain editor modal
pub fn drawKitChainEditor(r: *Renderer, ui: *EditorUI, center_x: i32, center_y: i32, project: *models.Project) types.KitChainAction {
    const action = types.KitChainAction{};

    const modal_w: i32 = 750;
    const modal_h: i32 = 480;
    const x = center_x - @divFloor(modal_w, 2);
    const y = center_y - @divFloor(modal_h, 2);

    r.fillRect(0, 0, 2000, 2000, 0xB0000000);

    r.drawRoundedRect(x, y, modal_w, modal_h, Colors.panel, true);
    r.drawRect(x, y, modal_w, modal_h, Colors.accent);
    r.drawRect(x + 1, y + 1, modal_w - 2, modal_h - 2, Colors.accent);

    r.drawTextLarge("KIT CHAINS", x + 12, y + 10, Colors.text);

    if (drawButton(r, ui, x + modal_w - 30, y + 8, 20, 18, "X", true)) {
        ui.show_kit_chain = false;
    }

    const library = &project.kit_chain_library;
    const content_y = y + 42;

    // === LEFT PANEL: Chain List ===
    const chain_list_x = x + 12;
    const chain_list_w: i32 = 160;
    const chain_list_h: i32 = 350;

    r.drawTextSmall("Chains", chain_list_x, content_y, Colors.text);

    const chain_list_y = content_y + 16;
    r.fillRect(chain_list_x, chain_list_y, chain_list_w, chain_list_h, Colors.slider_bg);
    r.drawRect(chain_list_x, chain_list_y, chain_list_w, chain_list_h, Colors.border);

    const item_h: i32 = 20;

    if (library.count == 0) {
        r.drawTextSmall("No chains", chain_list_x + 30, chain_list_y + chain_list_h / 2 - 6, Colors.text_dim);
    } else {
        var i: u8 = 0;
        while (i < library.count) : (i += 1) {
            const citem_y = chain_list_y + 2 + @as(i32, i) * item_h;
            if (citem_y + item_h > chain_list_y + chain_list_h - 2) break;

            const chain = &library.chains[i];
            const is_selected = ui.selected_chain == i;
            const item_hovered = ui.isHovered(chain_list_x + 2, citem_y, chain_list_w - 4, item_h);

            if (is_selected) {
                r.fillRect(chain_list_x + 2, citem_y, chain_list_w - 4, item_h, Colors.accent_dark);
            } else if (item_hovered) {
                r.fillRect(chain_list_x + 2, citem_y, chain_list_w - 4, item_h, Colors.panel_light);
            }

            var num_buf: [8]u8 = undefined;
            const num_str = std.fmt.bufPrint(&num_buf, "{d}.", .{i + 1}) catch "?";
            r.drawTextSmall(num_str, chain_list_x + 6, citem_y + 5, Colors.text_dim);

            const chain_name = chain.getName();
            const display_len = @min(chain_name.len, 14);
            const name_to_show = if (chain_name.len > 0) chain_name[0..display_len] else "Unnamed";
            r.drawTextSmall(name_to_show, chain_list_x + 24, citem_y + 5, Colors.text);

            var step_buf: [8]u8 = undefined;
            const step_str = std.fmt.bufPrint(&step_buf, "({d})", .{chain.step_count}) catch "";
            r.drawTextSmall(step_str, chain_list_x + chain_list_w - 28, citem_y + 5, Colors.text_dim);

            if (item_hovered and ui.isClicked(chain_list_x + 2, citem_y, chain_list_w - 4, item_h)) {
                ui.selected_chain = i;
                ui.selected_chain_step = 0;
            }
        }
    }

    // Chain list buttons
    const chain_btn_y = chain_list_y + chain_list_h + 8;
    const chain_btn_w: i32 = 50;
    const btn_h: i32 = 22;

    if (drawButton(r, ui, chain_list_x, chain_btn_y, chain_btn_w, btn_h, "New", library.count < models.KitChainLibrary.MAX_CHAINS)) {
        if (library.addChain()) |_| {
            ui.selected_chain = library.count - 1;
        }
    }

    if (drawButton(r, ui, chain_list_x + chain_btn_w + 4, chain_btn_y, chain_btn_w, btn_h, "Delete", library.count > 0)) {
        if (library.deleteChain(ui.selected_chain)) {
            if (ui.selected_chain >= library.count and library.count > 0) {
                ui.selected_chain = library.count - 1;
            }
        }
    }

    if (drawButton(r, ui, chain_list_x + (chain_btn_w + 4) * 2, chain_btn_y, chain_btn_w, btn_h, "Copy", library.count > 0 and library.count < models.KitChainLibrary.MAX_CHAINS)) {
        _ = library.duplicateChain(ui.selected_chain);
    }

    // === CENTER PANEL: Chain Steps ===
    const steps_x = chain_list_x + chain_list_w + 12;
    const steps_w: i32 = 240;
    const steps_h: i32 = 350;

    r.drawTextSmall("Chain Steps", steps_x, content_y, Colors.text);

    const steps_list_y = content_y + 16;
    r.fillRect(steps_x, steps_list_y, steps_w, steps_h, Colors.slider_bg);
    r.drawRect(steps_x, steps_list_y, steps_w, steps_h, Colors.border);

    if (library.count > 0 and ui.selected_chain < library.count) {
        const chain = &library.chains[ui.selected_chain];

        // Draw editable chain name at top of steps panel
        const name_input_w: i32 = steps_w - 8;
        const name_input_h: i32 = 20;
        _ = drawKitChainNameInput(r, ui, steps_x + 4, steps_list_y + 2, name_input_w, name_input_h, chain);

        const step_item_h: i32 = 20;
        const step_start_y = steps_list_y + 20;

        if (chain.step_count == 0) {
            r.drawTextSmall("No steps yet", steps_x + 70, steps_list_y + steps_h / 2 - 6, Colors.text_dim);
            r.drawTextSmall("Click a kit to add ->", steps_x + 50, steps_list_y + steps_h / 2 + 10, Colors.text_dim);
        } else {
            var s: u8 = 0;
            while (s < chain.step_count) : (s += 1) {
                const s_y = step_start_y + @as(i32, s) * step_item_h;
                if (s_y + step_item_h > steps_list_y + steps_h - 2) break;

                const is_step_selected = ui.selected_chain_step == s;
                const step_hovered = ui.isHovered(steps_x + 2, s_y, steps_w - 4, step_item_h);

                if (is_step_selected) {
                    r.fillRect(steps_x + 2, s_y, steps_w - 4, step_item_h, Colors.accent_dark);
                } else if (step_hovered) {
                    r.fillRect(steps_x + 2, s_y, steps_w - 4, step_item_h, Colors.panel_light);
                }

                var snum_buf: [8]u8 = undefined;
                const snum_str = std.fmt.bufPrint(&snum_buf, "{d}.", .{s + 1}) catch "?";
                r.drawTextSmall(snum_str, steps_x + 6, s_y + 5, Colors.text_dim);

                if (chain.getStep(s)) |kit_idx| {
                    if (kit_idx < project.kit_count) {
                        const kit = &project.kits[kit_idx];
                        const kit_name = kit.getName();
                        const kit_display = @min(kit_name.len, 20);
                        r.drawTextSmall(kit_name[0..kit_display], steps_x + 28, s_y + 5, Colors.text);

                        var knum_buf: [16]u8 = undefined;
                        const knum_str = std.fmt.bufPrint(&knum_buf, "(Kit {d})", .{kit_idx + 1}) catch "";
                        r.drawTextSmall(knum_str, steps_x + steps_w - 55, s_y + 5, Colors.text_dim);
                    } else {
                        r.drawTextSmall("<Invalid>", steps_x + 28, s_y + 5, 0xFFE04040);
                    }
                }

                if (step_hovered and ui.isClicked(steps_x + 2, s_y, steps_w - 4, step_item_h)) {
                    ui.selected_chain_step = s;
                }
            }
        }

        // Step manipulation buttons
        const step_btn_y = steps_list_y + steps_h + 8;
        const step_btn_w: i32 = 45;
        var step_btn_x = steps_x;

        if (drawButton(r, ui, step_btn_x, step_btn_y, step_btn_w, btn_h, "Remove", chain.step_count > 0)) {
            _ = chain.removeStep(ui.selected_chain_step);
            if (ui.selected_chain_step >= chain.step_count and chain.step_count > 0) {
                ui.selected_chain_step = chain.step_count - 1;
            }
        }
        step_btn_x += step_btn_w + 4;

        if (drawButton(r, ui, step_btn_x, step_btn_y, 30, btn_h, "Up", ui.selected_chain_step > 0)) {
            if (chain.moveStepUp(ui.selected_chain_step)) {
                ui.selected_chain_step -= 1;
            }
        }
        step_btn_x += 34;

        if (drawButton(r, ui, step_btn_x, step_btn_y, 30, btn_h, "Dn", ui.selected_chain_step < chain.step_count -| 1)) {
            if (chain.moveStepDown(ui.selected_chain_step)) {
                ui.selected_chain_step += 1;
            }
        }
        step_btn_x += 34;

        if (drawButton(r, ui, step_btn_x, step_btn_y, 45, btn_h, "Clear", chain.step_count > 0)) {
            chain.clear();
            ui.selected_chain_step = 0;
        }
    } else {
        r.drawTextSmall("Select a chain", steps_x + 70, steps_list_y + steps_h / 2 - 6, Colors.text_dim);
    }

    // === RIGHT PANEL: Available Kits ===
    const kits_x = steps_x + steps_w + 12;
    const kits_w: i32 = modal_w - kits_x + x - 12;
    const kits_h: i32 = 350;

    r.drawTextSmall("Available Kits (click to add)", kits_x, content_y, Colors.text);

    const kits_list_y = content_y + 16;
    r.fillRect(kits_x, kits_list_y, kits_w, kits_h, Colors.slider_bg);
    r.drawRect(kits_x, kits_list_y, kits_w, kits_h, Colors.border);

    const kit_item_h: i32 = 18;

    if (project.kit_count == 0) {
        r.drawTextSmall("No kits", kits_x + 50, kits_list_y + kits_h / 2 - 6, Colors.text_dim);
    } else {
        var k: u8 = 0;
        while (k < project.kit_count) : (k += 1) {
            const k_y = kits_list_y + 2 + @as(i32, k) * kit_item_h;
            if (k_y + kit_item_h > kits_list_y + kits_h - 2) break;

            const kit = &project.kits[k];
            const kit_hovered = ui.isHovered(kits_x + 2, k_y, kits_w - 4, kit_item_h);

            if (kit_hovered) {
                r.fillRect(kits_x + 2, k_y, kits_w - 4, kit_item_h, Colors.button_green);
            }

            // Kit number
            var knum_buf: [8]u8 = undefined;
            const knum_str = std.fmt.bufPrint(&knum_buf, "{d}.", .{k + 1}) catch "?";
            r.drawTextSmall(knum_str, kits_x + 6, k_y + 4, Colors.text_dim);

            // Kit name
            const kit_name = kit.getName();
            const kit_display = @min(kit_name.len, 18);
            r.drawTextSmall(kit_name[0..kit_display], kits_x + 26, k_y + 4, Colors.text);

            // Handle click to add kit to chain
            if (library.count > 0 and ui.selected_chain < library.count) {
                const chain = &library.chains[ui.selected_chain];
                if (kit_hovered and ui.isClicked(kits_x + 2, k_y, kits_w - 4, kit_item_h)) {
                    if (chain.step_count < models.KitChain.MAX_STEPS) {
                        _ = chain.addStep(k);
                    }
                }
            }
        }
    }

    // Help text at bottom
    r.drawTextSmall("Click a kit on the right to add it to the chain", kits_x, kits_list_y + kits_h + 8, Colors.text_dim);

    return action;
}

/// Draw context menu for pads
pub fn drawPadContextMenu(r: *Renderer, ui: *EditorUI, kit: *models.Kit) bool {
    if (!ui.context_menu.open or ui.context_menu.menu_type != .pad) return false;

    const menu_w: i32 = 100;
    const item_h: i32 = 22;
    const menu_items = 4;
    const menu_h: i32 = item_h * menu_items + 2;

    const x = ui.context_menu.x;
    const y = ui.context_menu.y;

    r.fillRect(x + 2, y + 2, menu_w, menu_h, 0x80000000);
    r.fillRect(x, y, menu_w, menu_h, Colors.panel);
    r.drawRect(x, y, menu_w, menu_h, Colors.accent);

    var item_y = y + 1;
    var menu_clicked = false;
    const pad = kit.getPad(ui.context_menu.pad);

    const copy_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (copy_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Copy", x + 8, item_y + 6, Colors.text);
    if (pad.has_sample) {
        r.drawTextSmall("Ctrl+C", x + menu_w - 42, item_y + 6, Colors.text_dim);
    }
    if (copy_hovered and ui.input.mouse_clicked) {
        ui.copyPad(pad);
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

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
    if (paste_hovered and ui.input.mouse_clicked) {
        ui.pastePad(pad);
        ui.invalidateSampleUsageCache();
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

    const clear_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (clear_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Clear", x + 8, item_y + 6, Colors.text);
    if (clear_hovered and ui.input.mouse_clicked) {
        pad.reset();
        ui.invalidateSampleUsageCache();
        ui.closeContextMenu();
        menu_clicked = true;
    }
    item_y += item_h;

    r.fillRect(x + 4, item_y - 1, menu_w - 8, 1, Colors.border);

    const cancel_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (cancel_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Cancel", x + 8, item_y + 6, Colors.text_dim);
    if (cancel_hovered and ui.input.mouse_clicked) {
        ui.closeContextMenu();
        menu_clicked = true;
    }

    if (ui.input.mouse_clicked and !ui.isHovered(x, y, menu_w, menu_h)) {
        ui.closeContextMenu();
        menu_clicked = true;
    }

    return menu_clicked;
}

/// Draw context menu for waves - returns actions to perform
pub fn drawWaveContextMenu(r: *Renderer, ui: *EditorUI, project: *const models.Project) types.WaveContextMenuAction {
    var action = types.WaveContextMenuAction{};

    if (!ui.context_menu.open or ui.context_menu.menu_type != .wave) return action;

    const menu_w: i32 = 100;
    const item_h: i32 = 22;
    const menu_items = 3;
    const menu_h: i32 = item_h * menu_items + 2;

    const x = ui.context_menu.x;
    const y = ui.context_menu.y;

    r.fillRect(x + 2, y + 2, menu_w, menu_h, 0x80000000);
    r.fillRect(x, y, menu_w, menu_h, Colors.panel);
    r.drawRect(x, y, menu_w, menu_h, Colors.accent);

    var item_y = y + 1;
    const wave_index = ui.context_menu.wave;
    const has_wave = wave_index < project.sample_library.count;

    // Edit Wave option
    const edit_hovered = ui.isHovered(x, item_y, menu_w, item_h) and has_wave;
    if (edit_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    const edit_color = if (has_wave) Colors.text else Colors.text_dim;
    r.drawTextSmall("Edit Wave", x + 8, item_y + 6, edit_color);
    if (edit_hovered and ui.input.mouse_clicked) {
        ui.closeContextMenu();
        action.open_editor = true;
    }
    item_y += item_h;

    // Delete option
    const delete_hovered = ui.isHovered(x, item_y, menu_w, item_h) and has_wave;
    if (delete_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    const delete_color = if (has_wave) 0xFFE04040 else Colors.text_dim;
    r.drawTextSmall("Delete", x + 8, item_y + 6, delete_color);
    if (delete_hovered and ui.input.mouse_clicked) {
        action.delete_wave = true;
        action.wave_to_delete = wave_index;
        ui.closeContextMenu();
    }
    item_y += item_h;

    // Separator and Cancel
    r.fillRect(x + 4, item_y - 1, menu_w - 8, 1, Colors.border);

    const cancel_hovered = ui.isHovered(x, item_y, menu_w, item_h);
    if (cancel_hovered) {
        r.fillRect(x + 1, item_y, menu_w - 2, item_h, Colors.accent_dark);
    }
    r.drawTextSmall("Cancel", x + 8, item_y + 6, Colors.text_dim);
    if (cancel_hovered and ui.input.mouse_clicked) {
        ui.closeContextMenu();
    }

    // Close if clicked outside
    if (ui.input.mouse_clicked and !ui.isHovered(x, y, menu_w, menu_h)) {
        ui.closeContextMenu();
    }

    return action;
}

/// Draw drag indicator
pub fn drawDragIndicator(r: *Renderer, ui: *const EditorUI) void {
    if (!ui.isDragging()) return;

    const wave_name = ui.getDragWaveName();
    if (wave_name.len == 0) return;

    const label_w: i32 = @as(i32, @intCast(wave_name.len)) * 5 + 16;
    const label_h: i32 = 18;
    const label_x = ui.input.mouse_x + 12;
    const label_y = ui.input.mouse_y + 12;

    r.fillRect(label_x, label_y, label_w, label_h, Colors.accent_dark);
    r.drawRect(label_x, label_y, label_w, label_h, Colors.accent);

    r.drawTextSmall("~", label_x + 4, label_y + 5, Colors.text);

    const display_len = @min(wave_name.len, 16);
    r.drawTextSmall(wave_name[0..display_len], label_x + 12, label_y + 5, Colors.text);
}

/// Apply drop from library
pub fn applyDropFromLibrary(ui: *EditorUI, kit: *models.Kit, library: *models.SampleLibrary) bool {
    if (!ui.isDragging() or ui.drag.drop_target == .none) {
        ui.cancelDrag();
        return false;
    }

    const sample = library.getSample(ui.drag.drag_wave_index) orelse {
        ui.cancelDrag();
        return false;
    };

    const pad = kit.getPad(ui.drag.drop_target_pad);
    const wave_name = sample.getName();
    const wave_path = sample.getPath();

    switch (ui.drag.drop_target) {
        .pad_main => {
            pad.loadSample(wave_name, wave_path);
            ui.invalidateSampleUsageCache();
        },
        .pad_sub => {
            pad.loadSubSample(wave_name, wave_path);
            ui.invalidateSampleUsageCache();
        },
        .none => {},
    }

    ui.cancelDrag();
    return true;
}

/// Draw startup screen
pub fn drawStartupScreen(r: *Renderer, ui: *EditorUI, width: i32, height: i32) types.StartupAction {
    var action = types.StartupAction.none;

    r.fillRect(0, 0, width, height, Colors.background);

    const dialog_w: i32 = 500;
    const dialog_h: i32 = 320;
    const x = @divFloor(width - dialog_w, 2);
    const y = @divFloor(height - dialog_h, 2);

    r.drawRoundedRect(x, y, dialog_w, dialog_h, Colors.panel, true);
    r.drawRect(x, y, dialog_w, dialog_h, Colors.accent);
    r.drawRect(x + 1, y + 1, dialog_w - 2, dialog_h - 2, Colors.accent);

    r.drawTextLarge("SpeedSX", x + @divFloor(dialog_w, 2) - 42, y + 20, Colors.accent);
    r.drawText("Configuration Editor", x + @divFloor(dialog_w, 2) - 95, y + 50, Colors.text_dim);

    r.drawTextSmall("Enter the path to your SPD-SX configuration folder:", x + 20, y + 90, Colors.text);
    r.drawTextSmall("(e.g., /Volumes/SPD-SX_/Roland or /media/usb/Roland)", x + 20, y + 105, Colors.text_dim);

    const input_x = x + 20;
    const input_y = y + 130;
    const input_w = dialog_w - 40;
    const input_h: i32 = 28;

    const current_path = ui.getStartupPath();
    _ = drawStartupPathInput(r, ui, input_x, input_y, input_w, input_h, current_path);

    const error_msg = ui.getStartupError();
    if (error_msg.len > 0) {
        r.drawTextSmall(error_msg, x + 20, y + 170, 0xFFE04040);
    }

    const btn_w: i32 = 140;
    const btn_h: i32 = 32;
    const btn_y = y + 200;
    const btn_gap: i32 = 20;
    const total_btn_w = btn_w * 2 + btn_gap;
    const btn_start_x = x + @divFloor(dialog_w - total_btn_w, 2);

    const open_x = btn_start_x;
    const open_hovered = ui.isHovered(open_x, btn_y, btn_w, btn_h);
    const open_color: u32 = if (open_hovered) 0xFF3A9A3A else 0xFF2A8A2A;
    r.drawRoundedRect(open_x, btn_y, btn_w, btn_h, open_color, true);
    r.drawRoundedRect(open_x, btn_y, btn_w, btn_h, Colors.border, false);
    r.drawText("Open", open_x + @divFloor(btn_w - 40, 2), btn_y + 8, Colors.text);

    if (ui.isClicked(open_x, btn_y, btn_w, btn_h)) {
        action = .open_project;
    }

    const new_x = btn_start_x + btn_w + btn_gap;
    if (drawButton(r, ui, new_x, btn_y, btn_w, btn_h, "New Project", true)) {
        action = .new_project;
    }

    r.drawTextSmall("Tip: Connect your SPD-SX via USB and it will appear as a drive.", x + 20, y + 250, Colors.text_dim);
    r.drawTextSmall("The configuration is usually in the 'Roland' folder.", x + 20, y + 265, Colors.text_dim);
    r.drawTextSmall("You can also drag and drop a folder here to set the path.", x + 20, y + 280, Colors.accent_dark);

    r.drawTextSmall("Press Enter to Open, Escape for New Project", x + 20, y + dialog_h - 20, Colors.text_dim);

    return action;
}

fn drawStartupPathInput(r: *Renderer, ui: *EditorUI, x: i32, y: i32, w: i32, h: i32, current_value: []const u8) bool {
    const field_id = TextFieldId.startup_path;
    const is_focused = ui.text_input.focused_field == field_id;
    const hovered = ui.isHovered(x, y, w, h);

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
    const max_chars: usize = @intCast(@divFloor(w - 16, 5));
    const display_len = @min(display_text.len, max_chars);

    const text_y = y + @divFloor(h - 6, 2);
    if (display_text.len > 0) {
        r.drawTextSmall(display_text[0..display_len], x + 8, text_y, Colors.text);
    } else {
        r.drawTextSmall("Enter path here...", x + 8, text_y, Colors.text_dim);
    }

    if (is_focused and ui.text_input.cursor_blink < 0.5) {
        const cursor_x = x + 8 + @as(i32, ui.text_input.cursor_pos) * 5;
        r.fillRect(cursor_x, y + 4, 1, h - 8, Colors.text);
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

/// Apply startup path input
pub fn applyStartupPathInput(ui: *EditorUI) void {
    if (ui.text_input.focused_field == .startup_path) {
        const text = ui.finishTextInput();
        ui.setStartupPath(text);
    }
}
