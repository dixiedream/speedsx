/// Basic UI widgets - buttons, sliders, dropdowns, toggles
const std = @import("std");
const models = @import("../models.zig");
const types = @import("types.zig");
const renderer = @import("renderer.zig");
const state = @import("state.zig");

const Colors = types.Colors;
const DropdownFieldId = types.DropdownFieldId;
const Renderer = renderer.Renderer;
const EditorUI = state.EditorUI;

const item_h: i32 = 20;
const max_visible_items: i32 = 8;

fn drawDropdownTrigger(
    r: *Renderer,
    ui: *const EditorUI,
    field_id: DropdownFieldId,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    current_text: []const u8,
    label: []const u8,
) void {
    if (label.len > 0) {
        r.drawTextSmall(label, x, y - 10, Colors.text_dim);
    }

    const is_open = ui.dropdown_popup.open and ui.dropdown_popup.field_id == field_id;
    const hovered = ui.isHovered(x, y, w, h);
    const bg_color = if (is_open or hovered) Colors.panel_light else Colors.panel;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, if (is_open) Colors.accent else Colors.border, false);
    r.drawTextSmall(current_text, x + 6, y + @divFloor(h - 6, 2), Colors.text);
    r.drawTextSmall("v", x + w - 10, y + @divFloor(h - 6, 2), Colors.text_dim);
}

/// Enum field: click opens a scrollable list of all options
pub fn drawEnumDropdown(
    comptime Enum: type,
    r: *Renderer,
    ui: *EditorUI,
    field_id: DropdownFieldId,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    value: *Enum,
    label: []const u8,
    comptime labelFn: fn (Enum) []const u8,
) void {
    drawDropdownTrigger(r, ui, field_id, x, y, w, h, labelFn(value.*), label);

    if (ui.isClicked(x, y, w, h)) {
        const values = std.enums.values(Enum);
        if (ui.dropdown_popup.open and ui.dropdown_popup.field_id == field_id) {
            ui.closeDropdown();
        } else {
            ui.openDropdown(field_id, x, y, w, h, values.len);
        }
    }
}

/// ON/OFF (or two-option) dropdown
pub fn drawBoolDropdown(
    r: *Renderer,
    ui: *EditorUI,
    field_id: DropdownFieldId,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    value: *bool,
    label: []const u8,
) void {
    const current_text = if (value.*) "ON" else "OFF";
    drawDropdownTrigger(r, ui, field_id, x, y, w, h, current_text, label);

    if (ui.isClicked(x, y, w, h)) {
        if (ui.dropdown_popup.open and ui.dropdown_popup.field_id == field_id) {
            ui.closeDropdown();
        } else {
            ui.openDropdown(field_id, x, y, w, h, 2);
        }
    }
}

fn drawEnumPopupForField(
    comptime Enum: type,
    r: *Renderer,
    ui: *EditorUI,
    pop: *types.DropdownPopupState,
    value: *Enum,
    comptime labelFn: fn (Enum) []const u8,
) void {
    const values = std.enums.values(Enum);
    const visible: i32 = @min(max_visible_items, @as(i32, @intCast(values.len)));
    const popup_h = visible * item_h + 2;

    r.fillRect(pop.x + 2, pop.y + 2, pop.w, popup_h, 0x80000000);
    r.fillRect(pop.x, pop.y, pop.w, popup_h, Colors.panel);
    r.drawRect(pop.x, pop.y, pop.w, popup_h, Colors.accent);

    var i: usize = 0;
    while (i < values.len) : (i += 1) {
        const item_y = pop.y + 1 + @as(i32, @intCast(i)) * item_h - pop.scroll;
        if (item_y + item_h < pop.y or item_y > pop.y + popup_h) continue;

        const opt = values[i];
        const hovered = ui.isHovered(pop.x, item_y, pop.w, item_h);
        if (hovered) {
            r.fillRect(pop.x + 1, item_y, pop.w - 2, item_h, Colors.accent_dark);
        }
        const text_color = if (opt == value.*) Colors.accent else Colors.text;
        r.drawTextSmall(labelFn(opt), pop.x + 8, item_y + 5, text_color);

        if (hovered and ui.input.mouse_clicked) {
            value.* = opt;
            ui.closeDropdown();
            return;
        }
    }

    if (ui.input.mouse_clicked) {
        const over_popup = ui.isHovered(pop.x, pop.y, pop.w, popup_h);
        const over_anchor = ui.isHovered(pop.anchor_x, pop.anchor_y, pop.anchor_w, pop.anchor_h);
        if (!over_popup and !over_anchor) {
            ui.closeDropdown();
        }
    }
}

fn drawBoolPopup(r: *Renderer, ui: *EditorUI, pop: *types.DropdownPopupState, value: *bool) void {
    const popup_h = 2 * item_h + 2;
    r.fillRect(pop.x + 2, pop.y + 2, pop.w, popup_h, 0x80000000);
    r.fillRect(pop.x, pop.y, pop.w, popup_h, Colors.panel);
    r.drawRect(pop.x, pop.y, pop.w, popup_h, Colors.accent);

    const options = [_][]const u8{ "OFF", "ON" };
    for (options, 0..) |text, idx| {
        const item_y = pop.y + 1 + @as(i32, @intCast(idx)) * item_h;
        const hovered = ui.isHovered(pop.x, item_y, pop.w, item_h);
        if (hovered) {
            r.fillRect(pop.x + 1, item_y, pop.w - 2, item_h, Colors.accent_dark);
        }
        const selected = (idx == 1) == value.*;
        const text_color = if (selected) Colors.accent else Colors.text;
        r.drawTextSmall(text, pop.x + 8, item_y + 5, text_color);
        if (hovered and ui.input.mouse_clicked) {
            value.* = idx == 1;
            ui.closeDropdown();
            return;
        }
    }

    if (ui.input.mouse_clicked) {
        const over_popup = ui.isHovered(pop.x, pop.y, pop.w, popup_h);
        const over_anchor = ui.isHovered(pop.anchor_x, pop.anchor_y, pop.anchor_w, pop.anchor_h);
        if (!over_popup and !over_anchor) {
            ui.closeDropdown();
        }
    }
}

/// Draw the active option list on top of the UI; call once per frame after panels
pub fn drawDropdownPopup(r: *Renderer, ui: *EditorUI, kit: *models.Kit, pad: *models.Pad) void {
    if (!ui.dropdown_popup.open) return;
    const pop = &ui.dropdown_popup;

    switch (pop.field_id) {
        .pad_link => drawEnumPopupForField(models.PadLink, r, ui, pop, &kit.pad_link, models.PadLink.toString),
        .pad_link_target => drawEnumPopupForField(models.PadLink, r, ui, pop, &kit.pad_link_target, models.PadLink.toString),
        .mute_group => drawEnumPopupForField(models.MuteGroup, r, ui, pop, &pad.mute_group, models.MuteGroup.toString),
        .tempo_sync => drawEnumPopupForField(models.TempoSync, r, ui, pop, &pad.tempo_sync, models.TempoSync.toString),
        .loop_mode => drawEnumPopupForField(models.LoopMode, r, ui, pop, &pad.loop_mode, models.LoopMode.toString),
        .trigger_mode => drawEnumPopupForField(models.TriggerMode, r, ui, pop, &pad.trigger_mode, models.TriggerMode.toString),
        .dynamics => drawEnumPopupForField(models.Dynamics, r, ui, pop, &pad.dynamics, models.Dynamics.toString),
        .poly_mono => drawEnumPopupForField(models.PolyMono, r, ui, pop, &pad.poly_mono, models.PolyMono.toString),
        .output_assign => drawEnumPopupForField(models.OutputAssign, r, ui, pop, &pad.output_assign, models.OutputAssign.toString),
        .reverse => drawBoolPopup(r, ui, pop, &pad.reverse),
        .midi_channel => drawEnumPopupForField(models.Pad.MidiChannel, r, ui, pop, &pad.midi_channel, models.Pad.MidiChannel.toString),
        .midi_ext_ctrl => drawBoolPopup(r, ui, pop, &pad.midi_ext_ctrl),
        .fx1_switch => drawBoolPopup(r, ui, pop, &kit.fx1_switch),
        .fx1_type => drawEnumPopupForField(models.FxType, r, ui, pop, &kit.fx1_type, models.FxType.toString),
        .fx2_switch => drawBoolPopup(r, ui, pop, &kit.fx2_switch),
        .fx2_type => drawEnumPopupForField(models.FxType, r, ui, pop, &kit.fx2_type, models.FxType.toString),
        .none => ui.closeDropdown(),
    }
}

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

/// Draw a green-styled button
pub fn drawGreenButton(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, text: []const u8, enabled: bool) bool {
    const hovered = ui.isHovered(x, y, w, h);
    const clicked = enabled and ui.isClicked(x, y, w, h);

    var bg_color = if (enabled) Colors.button_green else Colors.panel;
    if (hovered and enabled) bg_color = 0xFF3AAA3A;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);

    const text_color = if (enabled) Colors.text else Colors.text_dim;
    const text_width = r.measureTextSmall(text);
    r.drawTextSmall(text, x + @divFloor(w - text_width, 2), y + @divFloor(h - 6, 2), text_color);

    return clicked;
}

/// Draw a slider (internal implementation)
fn drawSliderInternal(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, value: *u8, min_val: u8, max_val: u8, label: []const u8, show_value: bool) void {
    r.drawTextSmall(label, x, y - 10, Colors.text_dim);
    r.drawRoundedRect(x, y, w, h, Colors.slider_bg, true);

    const range: f32 = @floatFromInt(max_val - min_val);
    const normalized = @as(f32, @floatFromInt(value.* - min_val)) / range;
    const fill_width: i32 = @intFromFloat(normalized * @as(f32, @floatFromInt(w)));

    if (fill_width > 0) {
        r.fillRect(x, y, fill_width, h, Colors.slider_fill);
    }

    if (ui.isHovered(x, y, w, h) and ui.input.mouse_down) {
        const relative_x: f32 = @floatFromInt(ui.input.mouse_x - x);
        const new_normalized = std.math.clamp(relative_x / @as(f32, @floatFromInt(w)), 0, 1);
        value.* = @intFromFloat(new_normalized * range + @as(f32, @floatFromInt(min_val)));
    }

    if (show_value) {
        var buf: [8]u8 = undefined;
        const val_str = std.fmt.bufPrint(&buf, "{d}", .{value.*}) catch "?";
        r.drawTextSmall(val_str, x + w + 8, y + 2, Colors.text);
    }
}

/// Draw a slider with value display
pub fn drawSlider(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, value: *u8, min_val: u8, max_val: u8, label: []const u8) void {
    drawSliderInternal(r, ui, x, y, w, h, value, min_val, max_val, label, true);
}

/// Draw a slider without value display (value shown separately as custom label)
pub fn drawSliderNoValue(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, value: *u8, min_val: u8, max_val: u8, label: []const u8) void {
    drawSliderInternal(r, ui, x, y, w, h, value, min_val, max_val, label, false);
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

    if (ui.isHovered(x, y, w, h) and ui.input.mouse_down) {
        const relative_x: f32 = @floatFromInt(ui.input.mouse_x - x);
        const new_normalized = std.math.clamp(relative_x / @as(f32, @floatFromInt(w)), 0, 1);
        value.* = @intFromFloat(new_normalized * range + @as(f32, @floatFromInt(min_val)));
    }

    var buf: [8]u8 = undefined;
    const val_str = std.fmt.bufPrint(&buf, "{d}", .{value.*}) catch "?";
    r.drawTextSmall(val_str, x + w + 8, y + 2, Colors.text);
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

/// Draw text box (read-only display)
pub fn drawTextBox(r: *Renderer, ui: *const EditorUI, x: i32, y: i32, w: i32, h: i32, text: []const u8) void {
    const hovered = ui.isHovered(x, y, w, h);
    const bg_color = if (hovered) Colors.panel_light else Colors.slider_bg;

    r.drawRoundedRect(x, y, w, h, bg_color, true);
    r.drawRoundedRect(x, y, w, h, Colors.border, false);

    const display_len = @min(text.len, 20);
    const display_text = if (text.len > 0) text[0..display_len] else "-";
    r.drawTextSmall(display_text, x + 4, y + @divFloor(h - 6, 2), Colors.text);
}

/// Draw scrollbar
pub fn drawScrollbar(r: *Renderer, x: i32, y: i32, w: i32, h: i32, scroll_pos: i32, max_scroll: i32) void {
    if (max_scroll <= 0) return;

    const track_h = h - 4;
    const thumb_h = @max(20, @divFloor(track_h * track_h, track_h + max_scroll));
    const available_h = track_h - thumb_h;
    const thumb_pos: i32 = if (max_scroll > 0)
        @divFloor(scroll_pos * available_h, max_scroll)
    else
        0;

    r.fillRect(x, y + 2, w, track_h, Colors.slider_bg);
    r.fillRect(x, y + 2 + thumb_pos, w, thumb_h, Colors.border);
}

/// Utility: Lerp between two colors
pub fn lerpColor(a: u32, b: u32, t: f32) u32 {
    const t_clamped = std.math.clamp(t, 0.0, 1.0);
    const inv_t = 1.0 - t_clamped;

    const ar: f32 = @floatFromInt((a >> 16) & 0xFF);
    const ag: f32 = @floatFromInt((a >> 8) & 0xFF);
    const ab: f32 = @floatFromInt(a & 0xFF);
    const aa: f32 = @floatFromInt((a >> 24) & 0xFF);

    const br: f32 = @floatFromInt((b >> 16) & 0xFF);
    const bg: f32 = @floatFromInt((b >> 8) & 0xFF);
    const bb: f32 = @floatFromInt(b & 0xFF);
    const ba: f32 = @floatFromInt((b >> 24) & 0xFF);

    const rr: u32 = @intFromFloat(ar * inv_t + br * t_clamped);
    const rg: u32 = @intFromFloat(ag * inv_t + bg * t_clamped);
    const rb: u32 = @intFromFloat(ab * inv_t + bb * t_clamped);
    const ra: u32 = @intFromFloat(aa * inv_t + ba * t_clamped);

    return (ra << 24) | (rr << 16) | (rg << 8) | rb;
}

/// Utility: Lighten a color
pub fn lightenColor(col: u32, amount: f32) u32 {
    const white: u32 = 0xFFFFFFFF;
    return lerpColor(col, white, amount);
}
