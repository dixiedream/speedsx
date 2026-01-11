//! Character encoding utilities for SPD-SX
//! Handles conversion between ASCII codes and characters used in kit/wave names

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Allowed symbols for names (based on Java Symbols array)
pub const allowed_symbols = " '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_=@!#$%&()+,-.[]^`{}~";

/// Check if a character is allowed in names
pub fn isAllowedChar(c: u8) bool {
    for (allowed_symbols) |s| {
        if (c == s) return true;
    }
    return false;
}

/// Get ASCII code for a character (returns code as string value)
pub fn getCode(c: u8) u8 {
    return switch (c) {
        ' ' => 32,
        '\'' => 39,
        '0'...'9' => c, // 48-57
        'A'...'Z' => c, // 65-90
        'a'...'z' => c, // 97-122
        '_' => 95,
        '=' => 61,
        '@' => 64,
        '!' => 33,
        '#' => 35,
        '$' => 36,
        '%' => 37,
        '&' => 38,
        '(' => 40,
        ')' => 41,
        '+' => 43,
        ',' => 44,
        '-' => 45,
        '.' => 46,
        '[' => 91,
        ']' => 93,
        '^' => 94,
        '`' => 96,
        '{' => 123,
        '}' => 125,
        '~' => 126,
        else => 32, // Default to space
    };
}

/// Get character from ASCII code
pub fn getCharFromCode(code: u8) u8 {
    return switch (code) {
        0 => 0, // Null/empty
        32 => ' ',
        39 => '\'',
        48...57 => code, // 0-9
        65...90 => code, // A-Z
        97...122 => code, // a-z
        95 => '_',
        61 => '=',
        64 => '@',
        33 => '!',
        35 => '#',
        36 => '$',
        37 => '%',
        38 => '&',
        40 => '(',
        41 => ')',
        43 => '+',
        44 => ',',
        45 => '-',
        46 => '.',
        91 => '[',
        93 => ']',
        94 => '^',
        96 => '`',
        123 => '{',
        125 => '}',
        126 => '~',
        else => '?', // Unknown
    };
}

/// Decode an array of ASCII codes to a string
pub fn decodeString(codes: []const u8, allocator: Allocator) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    for (codes) |code| {
        if (code == 0) break; // Stop at null
        const c = getCharFromCode(code);
        if (c != 0) {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Encode a string to an array of ASCII codes
pub fn encodeString(str: []const u8, dest: []u8) void {
    var i: usize = 0;
    for (str) |c| {
        if (i >= dest.len) break;
        dest[i] = getCode(c);
        i += 1;
    }
    // Fill rest with zeros
    while (i < dest.len) : (i += 1) {
        dest[i] = 0;
    }
}

/// Get pan text representation (L15 to R15, CENTER)
pub fn getPanText(pan_value: u8) []const u8 {
    const pan_texts = [_][]const u8{
        "L15", "L14", "L13", "L12", "L11", "L10", "L9", "L8",
        "L7",  "L6",  "L5",  "L4",  "L3",  "L2",  "L1", "CENTER",
        "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7", "R8",
        "R9",  "R10", "R11", "R12", "R13", "R14", "R15",
    };
    if (pan_value <= 30) {
        return pan_texts[pan_value];
    }
    return "?";
}

/// Get pan value from text
pub fn getPanValue(text: []const u8) ?u8 {
    const pan_texts = [_][]const u8{
        "L15", "L14", "L13", "L12", "L11", "L10", "L9", "L8",
        "L7",  "L6",  "L5",  "L4",  "L3",  "L2",  "L1", "CENTER",
        "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7", "R8",
        "R9",  "R10", "R11", "R12", "R13", "R14", "R15",
    };
    for (pan_texts, 0..) |t, i| {
        if (std.mem.eql(u8, text, t)) {
            return @intCast(i);
        }
    }
    return null;
}

/// Format file size to human readable format
pub fn formatFileSize(size: u64, buf: []u8) []const u8 {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    const dividers = [_]u64{ 1, 1000, 1000000, 1000000000, 1000000000000 };

    var unit_idx: usize = 0;
    for (dividers, 0..) |div, i| {
        if (size >= div) {
            unit_idx = i;
        }
    }

    if (unit_idx == 0) {
        return std.fmt.bufPrint(buf, "{d} B", .{size}) catch "?";
    }

    const value = @as(f64, @floatFromInt(size)) / @as(f64, @floatFromInt(dividers[unit_idx]));
    return std.fmt.bufPrint(buf, "{d:.1} {s}", .{ value, units[unit_idx] }) catch "?";
}

/// Format time in seconds to human readable format
pub fn formatTime(seconds: f64, buf: []u8) []const u8 {
    if (seconds >= 60.0) {
        const mins = @as(u32, @intFromFloat(seconds / 60.0));
        const secs = seconds - @as(f64, @floatFromInt(mins)) * 60.0;
        return std.fmt.bufPrint(buf, "{d:0>2}min {d:0>5.2}s", .{ mins, secs }) catch "?";
    }
    return std.fmt.bufPrint(buf, "{d:.2}s", .{seconds}) catch "?";
}

/// Remove whitespace from string
pub fn removeWhitespace(str: []const u8, allocator: Allocator) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    for (str) |c| {
        if (!std.ascii.isWhitespace(c)) {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Check if string is a valid email format
pub fn isEmail(email: []const u8) bool {
    var at_count: usize = 0;
    var at_pos: usize = 0;
    var dot_after_at = false;

    for (email, 0..) |c, i| {
        if (c == '@') {
            at_count += 1;
            at_pos = i;
        } else if (c == '.' and at_count == 1 and i > at_pos) {
            dot_after_at = true;
        }
    }

    return at_count == 1 and at_pos > 0 and at_pos < email.len - 1 and dot_after_at;
}

/// Compare version strings (e.g., "1.2.3" vs "1.2.4")
pub fn versionCompare(v1: []const u8, v2: []const u8) i32 {
    var it1 = std.mem.splitSequence(u8, v1, ".");
    var it2 = std.mem.splitSequence(u8, v2, ".");

    while (true) {
        const part1 = it1.next();
        const part2 = it2.next();

        if (part1 == null and part2 == null) return 0;
        if (part1 == null) return -1;
        if (part2 == null) return 1;

        const n1 = std.fmt.parseInt(u32, part1.?, 10) catch 0;
        const n2 = std.fmt.parseInt(u32, part2.?, 10) catch 0;

        if (n1 < n2) return -1;
        if (n1 > n2) return 1;
    }
}

// Tests
test "getCode and getCharFromCode roundtrip" {
    const chars = "ABCabc123 _";
    for (chars) |c| {
        const code = getCode(c);
        const back = getCharFromCode(code);
        try std.testing.expectEqual(c, back);
    }
}

test "encodeString and decodeString" {
    var allocator = std.testing.allocator;
    var buf: [8]u8 = undefined;
    encodeString("Test", &buf);
    const decoded = try decodeString(&buf, allocator);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test", decoded);
}

test "getPanText" {
    try std.testing.expectEqualStrings("L15", getPanText(0));
    try std.testing.expectEqualStrings("CENTER", getPanText(15));
    try std.testing.expectEqualStrings("R15", getPanText(30));
}

test "versionCompare" {
    try std.testing.expectEqual(@as(i32, 0), versionCompare("1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i32, -1), versionCompare("1.0.0", "1.0.1"));
    try std.testing.expectEqual(@as(i32, 1), versionCompare("1.1.0", "1.0.9"));
}
