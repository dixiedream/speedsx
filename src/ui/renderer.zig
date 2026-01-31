/// SDL2 Renderer wrapper with bitmap font support
const std = @import("std");
const sdl = @import("../sdl.zig");
const c = sdl.c;
const font = @import("../font.zig");
const types = @import("types.zig");
const Colors = types.Colors;

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
        Colors.setRenderColor(self.sdl_renderer, col);

        // Draw each pixel of the character
        for (0..font.CHAR_HEIGHT) |row| {
            for (0..font.CHAR_WIDTH) |column| {
                if (font.getPixel(char_index, column, row)) {
                    const px = x + @as(i32, @intCast(column)) * scale;
                    const py = y + @as(i32, @intCast(row)) * scale;
                    const rect = c.SDL_Rect{ .x = px, .y = py, .w = scale, .h = scale };
                    _ = c.SDL_RenderFillRect(self.sdl_renderer, &rect);
                }
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
            cursor_x += (font.CHAR_WIDTH + font.CHAR_SPACING) * scale;
        }
    }

    pub fn measureTextSmall(self: *Renderer, text: []const u8) i32 {
        _ = self;
        return font.textWidth(text);
    }
};
