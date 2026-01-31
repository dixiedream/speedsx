const std = @import("std");

/// Check if a file is a supported audio format
pub fn isSupportedAudio(path: []const u8) bool {
    // Check by extension suffix (case-insensitive)
    const lower_extensions = [_][]const u8{ ".wav", ".aiff", ".aif" };
    const upper_extensions = [_][]const u8{ ".WAV", ".AIFF", ".AIF" };

    for (lower_extensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }

    for (upper_extensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }

    return false;
}

// Tests
const testing = std.testing;

test "isSupportedAudio" {
    try testing.expect(isSupportedAudio("test.wav"));
    try testing.expect(isSupportedAudio("test.WAV"));
    try testing.expect(isSupportedAudio("test.aiff"));
    try testing.expect(isSupportedAudio("test.AIFF"));
    try testing.expect(isSupportedAudio("test.aif"));
    try testing.expect(isSupportedAudio("test.AIF"));
    try testing.expect(!isSupportedAudio("test.mp3"));
    try testing.expect(!isSupportedAudio("test.txt"));
    try testing.expect(!isSupportedAudio("test"));
}
