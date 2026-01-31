/// User configuration persistence
/// Stores settings like last project path between sessions
const std = @import("std");
const models = @import("models.zig");

/// Config file name
const CONFIG_FILENAME = "speedsx.conf";

/// User configuration
pub const UserConfig = struct {
    last_project_path: models.BoundedString(512) = .{},

    pub fn getLastPath(self: *const UserConfig) []const u8 {
        return self.last_project_path.get();
    }

    pub fn setLastPath(self: *UserConfig, path: []const u8) void {
        self.last_project_path.set(path);
    }
};

/// Get the config file path
fn getConfigPath(buf: []u8) ?[]const u8 {
    // Try XDG_CONFIG_HOME first, then HOME/.config
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        return std.fmt.bufPrint(buf, "{s}/speedsx/{s}", .{ xdg, CONFIG_FILENAME }) catch null;
    }

    if (std.posix.getenv("HOME")) |home| {
        return std.fmt.bufPrint(buf, "{s}/.config/speedsx/{s}", .{ home, CONFIG_FILENAME }) catch null;
    }

    // Fallback: current directory
    return std.fmt.bufPrint(buf, "./{s}", .{CONFIG_FILENAME}) catch null;
}

/// Ensure config directory exists
fn ensureConfigDir() void {
    var buf: [512]u8 = undefined;

    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        const dir_path = std.fmt.bufPrint(&buf, "{s}/speedsx", .{xdg}) catch return;
        std.fs.cwd().makePath(dir_path) catch {};
        return;
    }

    if (std.posix.getenv("HOME")) |home| {
        const dir_path = std.fmt.bufPrint(&buf, "{s}/.config/speedsx", .{home}) catch return;
        std.fs.cwd().makePath(dir_path) catch {};
    }
}

/// Load user configuration from disk
pub fn load() UserConfig {
    var user_cfg = UserConfig{};
    var path_buf: [512]u8 = undefined;

    const config_path = getConfigPath(&path_buf) orelse return user_cfg;

    const file = std.fs.cwd().openFile(config_path, .{}) catch return user_cfg;
    defer file.close();

    // Read file contents
    var content_buf: [1024]u8 = undefined;
    const bytes_read = file.readAll(&content_buf) catch return user_cfg;
    const content = content_buf[0..bytes_read];

    // Parse line by line
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        // Parse key=value format
        if (std.mem.indexOf(u8, line, "=")) |eq_pos| {
            const key = line[0..eq_pos];
            const value = line[eq_pos + 1 ..];

            if (std.mem.eql(u8, key, "last_project_path")) {
                user_cfg.last_project_path.set(value);
            }
        }
    }

    return user_cfg;
}

/// Save user configuration to disk
pub fn save(user_cfg: *const UserConfig) void {
    ensureConfigDir();

    var path_buf: [512]u8 = undefined;
    const config_path = getConfigPath(&path_buf) orelse return;

    const file = std.fs.cwd().createFile(config_path, .{}) catch return;
    defer file.close();

    const last_path = user_cfg.getLastPath();
    if (last_path.len > 0) {
        var write_buf: [600]u8 = undefined;
        const line = std.fmt.bufPrint(&write_buf, "last_project_path={s}\n", .{last_path}) catch return;
        _ = file.writeAll(line) catch {};
    }
}

/// Save just the last project path (convenience function)
pub fn saveLastPath(path: []const u8) void {
    var config = UserConfig{};
    config.setLastPath(path);
    save(&config);
}

// Tests
const testing = std.testing;

test "UserConfig basic operations" {
    var config = UserConfig{};
    try testing.expectEqualStrings("", config.getLastPath());

    config.setLastPath("/path/to/project");
    try testing.expectEqualStrings("/path/to/project", config.getLastPath());
}
