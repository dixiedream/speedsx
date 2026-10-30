/// Bitmap font data for UI rendering
/// Simple 4x6 embedded font (ASCII 32-126)
/// Each character is stored as 3 bytes (24 bits for 4x6 grid)
pub const CHAR_WIDTH = 4;
pub const CHAR_HEIGHT = 6;
pub const CHAR_SPACING = 1;

/// Font data: 4 columns x 6 rows, packed row-major into 3 bytes per char
/// Characters 32 (space) through 126 (~)
pub const data = [95][3]u8{
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

/// Get the pixel data for a character
/// Returns whether the pixel at (px, py) within the character should be drawn
pub fn getPixel(char_index: usize, px: usize, py: usize) bool {
    if (char_index >= data.len) return false;
    if (px >= CHAR_WIDTH or py >= CHAR_HEIGHT) return false;

    const char_data = data[char_index];
    const bit_index = py * CHAR_WIDTH + px;
    const byte_index = bit_index / 8;
    const bit_offset: u3 = @intCast(7 - (bit_index % 8));

    return (char_data[byte_index] & (@as(u8, 1) << bit_offset)) != 0;
}

/// Calculate text width in pixels
pub fn textWidth(text: []const u8) i32 {
    if (text.len == 0) return 0;
    return @intCast(text.len * (CHAR_WIDTH + CHAR_SPACING) - CHAR_SPACING);
}

// Tests
const testing = @import("std").testing;

test "font data size" {
    try testing.expectEqual(@as(usize, 95), data.len);
}

test "getPixel bounds" {
    // Out of bounds should return false
    try testing.expect(!getPixel(100, 0, 0)); // Invalid char
    try testing.expect(!getPixel(0, 10, 0)); // Invalid x
    try testing.expect(!getPixel(0, 0, 10)); // Invalid y
}

test "textWidth calculation" {
    try testing.expectEqual(@as(i32, 0), textWidth(""));
    try testing.expectEqual(@as(i32, 4), textWidth("A")); // 4 pixels, no spacing
    try testing.expectEqual(@as(i32, 9), textWidth("AB")); // 4 + 1 + 4 = 9
    try testing.expectEqual(@as(i32, 14), textWidth("ABC")); // 4 + 1 + 4 + 1 + 4 = 14
}
