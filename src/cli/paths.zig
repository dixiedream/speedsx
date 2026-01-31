/// SPD-SX Path Construction Utilities
/// Single source of truth for all SPD-SX folder structure and file paths
const std = @import("std");

/// SPD-SX directory structure constants
pub const SPDSX_ROOT = "SPD-SX";
pub const KIT_DIR = "KIT";
pub const WAVE_DIR = "WAVE";
pub const WAVE_PRM_DIR = "WAVE/PRM";
pub const WAVE_DATA_DIR = "WAVE/DATA";
pub const SYSTEM_DIR = "SYSTEM";

/// Maximum wave folders (00-99)
pub const MAX_WAVE_FOLDERS = 100;
/// Maximum waves per folder (00-99)
pub const MAX_WAVES_PER_FOLDER = 100;

/// Build path to SPD-SX root directory
pub fn getSpdSxRoot(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ base_path, SPDSX_ROOT }) catch null;
}

/// Build path to KIT directory
pub fn getKitDir(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}", .{ base_path, SPDSX_ROOT, KIT_DIR }) catch null;
}

/// Build path to a specific kit file
pub fn getKitFilePath(buf: []u8, base_path: []const u8, kit_index: usize) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/kit{d:0>3}.spd", .{ base_path, SPDSX_ROOT, KIT_DIR, kit_index }) catch null;
}

/// Build path to WAVE/PRM directory
pub fn getWavePrmDir(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}", .{ base_path, SPDSX_ROOT, WAVE_PRM_DIR }) catch null;
}

/// Build path to a specific WAVE/PRM folder (00-99)
pub fn getWavePrmFolderPath(buf: []u8, base_path: []const u8, folder: usize) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/{d:0>2}", .{ base_path, SPDSX_ROOT, WAVE_PRM_DIR, folder }) catch null;
}

/// Build path to a specific wave .spd parameter file
pub fn getWavePrmFilePath(buf: []u8, base_path: []const u8, wave_id: u32) ?[]const u8 {
    const folder = wave_id / MAX_WAVES_PER_FOLDER;
    const file = wave_id % MAX_WAVES_PER_FOLDER;
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/{d:0>2}/{d:0>2}.spd", .{ base_path, SPDSX_ROOT, WAVE_PRM_DIR, folder, file }) catch null;
}

/// Build path to WAVE/DATA directory
pub fn getWaveDataDir(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}", .{ base_path, SPDSX_ROOT, WAVE_DATA_DIR }) catch null;
}

/// Build path to a specific WAVE/DATA folder (00-99)
pub fn getWaveDataFolderPath(buf: []u8, base_path: []const u8, folder: usize) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/{d:0>2}", .{ base_path, SPDSX_ROOT, WAVE_DATA_DIR, folder }) catch null;
}

/// Build path to a specific wave audio file in WAVE/DATA
pub fn getWaveDataFilePath(buf: []u8, base_path: []const u8, folder: usize, filename: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/{d:0>2}/{s}", .{ base_path, SPDSX_ROOT, WAVE_DATA_DIR, folder, filename }) catch null;
}

/// Build full path from a relative wave path (e.g., "00/sample.wav")
pub fn getFullWaveDataPath(buf: []u8, base_path: []const u8, relative_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/{s}", .{ base_path, SPDSX_ROOT, WAVE_DATA_DIR, relative_path }) catch null;
}

/// Build relative wave path (folder/filename.wav)
pub fn getRelativeWavePath(buf: []u8, folder: usize, filename: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{d:0>2}/{s}", .{ folder, filename }) catch null;
}

/// Build path to SYSTEM directory
pub fn getSystemDir(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}", .{ base_path, SPDSX_ROOT, SYSTEM_DIR }) catch null;
}

/// Build path to tag_list.spd
pub fn getTagListPath(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/tag_list.spd", .{ base_path, SPDSX_ROOT, SYSTEM_DIR }) catch null;
}

/// Build path to sysparam.spd (kit chains)
pub fn getSysparamPath(buf: []u8, base_path: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}/sysparam.spd", .{ base_path, SPDSX_ROOT, SYSTEM_DIR }) catch null;
}

/// Extract relative wave path from a full path
/// e.g., "/path/to/Roland/SPD-SX/WAVE/DATA/01/file.wav" -> "01/file.wav"
pub fn extractRelativeWavePath(full_path: []const u8) []const u8 {
    // Look for "SPD-SX/WAVE/DATA/" marker in the path
    const marker = SPDSX_ROOT ++ "/" ++ WAVE_DATA_DIR ++ "/";
    if (std.mem.indexOf(u8, full_path, marker)) |pos| {
        const relative_start = pos + marker.len;
        if (relative_start < full_path.len) {
            return full_path[relative_start..];
        }
    }
    // Return as-is if no prefix found (might already be relative)
    return full_path;
}

/// Calculate wave folder from wave ID
pub fn getWaveFolder(wave_id: u32) usize {
    return wave_id / MAX_WAVES_PER_FOLDER;
}

/// Calculate wave file index from wave ID
pub fn getWaveFileIndex(wave_id: u32) usize {
    return wave_id % MAX_WAVES_PER_FOLDER;
}

/// Check if a path exists
pub fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Check if a path is a valid SPD-SX configuration root
pub fn isValidSpdSxPath(path: []const u8) bool {
    var buf: [512]u8 = undefined;

    // Check for SPD-SX/KIT directory
    if (getKitDir(&buf, path)) |kit_path| {
        if (pathExists(kit_path)) return true;
    }

    // Check with /Roland prefix
    var roland_buf: [512]u8 = undefined;
    const roland_path = std.fmt.bufPrint(&roland_buf, "{s}/Roland", .{path}) catch return false;
    if (getKitDir(&buf, roland_path)) |kit_path| {
        if (pathExists(kit_path)) return true;
    }

    return false;
}

/// Create all required SPD-SX directories
pub fn createDirectoryStructure(base_path: []const u8) void {
    var buf: [512]u8 = undefined;

    // Create main directories
    if (getSpdSxRoot(&buf, base_path)) |p| std.fs.cwd().makePath(p) catch {};
    if (getKitDir(&buf, base_path)) |p| std.fs.cwd().makePath(p) catch {};
    if (getWavePrmDir(&buf, base_path)) |p| std.fs.cwd().makePath(p) catch {};
    if (getWaveDataDir(&buf, base_path)) |p| std.fs.cwd().makePath(p) catch {};
    if (getSystemDir(&buf, base_path)) |p| std.fs.cwd().makePath(p) catch {};

    // Create wave subdirectories (00-99)
    for (0..MAX_WAVE_FOLDERS) |folder| {
        if (getWavePrmFolderPath(&buf, base_path, folder)) |p| std.fs.cwd().makePath(p) catch {};
        if (getWaveDataFolderPath(&buf, base_path, folder)) |p| std.fs.cwd().makePath(p) catch {};
    }
}

/// Ensure a specific wave folder exists (both PRM and DATA)
pub fn ensureWaveFolderExists(base_path: []const u8, folder: usize) void {
    var buf: [512]u8 = undefined;
    if (getWavePrmFolderPath(&buf, base_path, folder)) |p| std.fs.cwd().makePath(p) catch {};
    if (getWaveDataFolderPath(&buf, base_path, folder)) |p| std.fs.cwd().makePath(p) catch {};
}

/// Get filename from a path
pub fn getFilename(path: []const u8) []const u8 {
    var i = path.len;
    while (i > 0) {
        i -= 1;
        if (path[i] == '/' or path[i] == '\\') {
            return path[i + 1 ..];
        }
    }
    return path;
}

/// Get filename without extension
pub fn getFilenameWithoutExt(filename: []const u8) []const u8 {
    var i = filename.len;
    while (i > 0) {
        i -= 1;
        if (filename[i] == '.') {
            return filename[0..i];
        }
    }
    return filename;
}

// Tests
test "path construction" {
    var buf: [512]u8 = undefined;

    const kit_dir = getKitDir(&buf, "/media/usb/Roland");
    try std.testing.expect(kit_dir != null);
    try std.testing.expectEqualStrings("/media/usb/Roland/SPD-SX/KIT", kit_dir.?);
}

test "wave path construction" {
    var buf: [512]u8 = undefined;

    const wave_prm = getWavePrmFilePath(&buf, "/media/usb", 42);
    try std.testing.expect(wave_prm != null);
    try std.testing.expectEqualStrings("/media/usb/SPD-SX/WAVE/PRM/00/42.spd", wave_prm.?);

    const wave_prm2 = getWavePrmFilePath(&buf, "/media/usb", 142);
    try std.testing.expect(wave_prm2 != null);
    try std.testing.expectEqualStrings("/media/usb/SPD-SX/WAVE/PRM/01/42.spd", wave_prm2.?);
}

test "extract relative wave path" {
    const full = "/Volumes/SPD-SX_/Roland/SPD-SX/WAVE/DATA/00/kick.wav";
    const rel = extractRelativeWavePath(full);
    try std.testing.expectEqualStrings("00/kick.wav", rel);
}

test "filename extraction" {
    try std.testing.expectEqualStrings("file.wav", getFilename("/path/to/file.wav"));
    try std.testing.expectEqualStrings("file", getFilenameWithoutExt("file.wav"));
}
