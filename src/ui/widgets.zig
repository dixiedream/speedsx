/// Basic UI widgets - buttons, sliders, dropdowns, toggles
const std = @import("std");
const types = @import("types.zig");
const renderer = @import("renderer.zig");
const state = @import("state.zig");

const Colors = types.Colors;
const Renderer = renderer.Renderer;
const EditorUI = state.EditorUI;

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
