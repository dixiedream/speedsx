const std = @import("std");
const models = @import("models.zig");

/// Magic number for project files
const PROJECT_MAGIC: u32 = 0x53504458; // "SPDX"
const PROJECT_VERSION: u16 = 1;

/// Magic number for kit files
const KIT_MAGIC: u32 = 0x4B495458; // "KITX"
const KIT_VERSION: u16 = 1;

/// File operation errors
pub const FileError = error{
    InvalidMagic,
    UnsupportedVersion,
    CorruptedData,
    OutOfMemory,
    AccessDenied,
    FileNotFound,
    IoError,
};

/// Project file header
const ProjectHeader = extern struct {
    magic: u32,
    version: u16,
    kit_count: u8,
    reserved: u8,
    name_len: u8,
    padding: [7]u8,
};

/// Kit file header
const KitHeader = extern struct {
    magic: u32,
    version: u16,
    name_len: u8,
    tempo_low: u8,
    tempo_high: u8,
    master_volume: u8,
    master_fx_send: u8,
    reserved: u8,
};

/// Pad data for serialization
const PadData = extern struct {
    volume: u8,
    pan: i8,
    pitch: i8,
    decay: u8,
    play_mode: u8,
    mute_group: u8,
    midi_note: u8,
    velocity_curve: u8,
    trigger_type: u8,
    enabled: u8,
    has_sample: u8,
    sample_name_len: u8,
    sample_path_len_low: u8,
    sample_path_len_high: u8,
    reserved: [2]u8,
};

/// Save a project to file
pub fn saveProject(project: *const models.Project, path: []const u8) FileError!void {
    const file = std.fs.cwd().createFile(path, .{}) catch |err| {
        return switch (err) {
            error.AccessDenied => FileError.AccessDenied,
            else => FileError.IoError,
        };
    };
    defer file.close();

    // Write header
    const header = ProjectHeader{
        .magic = PROJECT_MAGIC,
        .version = PROJECT_VERSION,
        .kit_count = project.kit_count,
        .reserved = 0,
        .name_len = project.name_len,
        .padding = [_]u8{0} ** 7,
    };

    _ = file.writeAll(std.mem.asBytes(&header)) catch return FileError.IoError;

    // Write project name
    _ = file.writeAll(project.project_name[0..project.name_len]) catch return FileError.IoError;

    // Write each kit
    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        saveKitDataToFile(file, &project.kits[i]) catch return FileError.IoError;
    }
}

/// Load a project from file
pub fn loadProject(path: []const u8) FileError!models.Project {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => FileError.FileNotFound,
            error.AccessDenied => FileError.AccessDenied,
            else => FileError.IoError,
        };
    };
    defer file.close();

    // Read header
    var header: ProjectHeader = undefined;
    _ = file.readAll(std.mem.asBytes(&header)) catch return FileError.IoError;

    if (header.magic != PROJECT_MAGIC) return FileError.InvalidMagic;
    if (header.version > PROJECT_VERSION) return FileError.UnsupportedVersion;

    var project = models.Project{};
    project.kit_count = header.kit_count;
    project.name_len = header.name_len;

    // Read project name
    _ = file.readAll(project.project_name[0..header.name_len]) catch return FileError.IoError;

    // Read each kit
    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        project.kits[i] = loadKitDataFromFile(file) catch return FileError.CorruptedData;
    }

    return project;
}

/// Save a single kit to file
pub fn saveKit(kit: *const models.Kit, path: []const u8) FileError!void {
    const file = std.fs.cwd().createFile(path, .{}) catch |err| {
        return switch (err) {
            error.AccessDenied => FileError.AccessDenied,
            else => FileError.IoError,
        };
    };
    defer file.close();

    saveKitDataToFile(file, kit) catch return FileError.IoError;
}

/// Load a single kit from file
pub fn loadKit(path: []const u8) FileError!models.Kit {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => FileError.FileNotFound,
            error.AccessDenied => FileError.AccessDenied,
            else => FileError.IoError,
        };
    };
    defer file.close();

    return loadKitDataFromFile(file) catch FileError.CorruptedData;
}

/// Internal: Save kit data to file
fn saveKitDataToFile(file: std.fs.File, kit: *const models.Kit) !void {
    // Write kit header
    const header = KitHeader{
        .magic = KIT_MAGIC,
        .version = KIT_VERSION,
        .name_len = kit.name_len,
        .tempo_low = @truncate(kit.tempo),
        .tempo_high = @truncate(kit.tempo >> 8),
        .master_volume = kit.master_volume,
        .master_fx_send = kit.master_fx_send,
        .reserved = 0,
    };

    _ = try file.writeAll(std.mem.asBytes(&header));

    // Write kit name
    _ = try file.writeAll(kit.name[0..kit.name_len]);

    // Write each pad
    for (kit.pads) |pad| {
        const pad_data = PadData{
            .volume = pad.volume,
            .pan = pad.pan,
            .pitch = pad.pitch,
            .decay = pad.decay,
            .play_mode = @intFromEnum(pad.play_mode),
            .mute_group = @intFromEnum(pad.mute_group),
            .midi_note = pad.midi_note,
            .velocity_curve = pad.velocity_curve,
            .trigger_type = @intFromEnum(pad.trigger_type),
            .enabled = if (pad.enabled) 1 else 0,
            .has_sample = if (pad.has_sample) 1 else 0,
            .sample_name_len = pad.sample.name_len,
            .sample_path_len_low = @truncate(pad.sample.path_len),
            .sample_path_len_high = @truncate(pad.sample.path_len >> 8),
            .reserved = [_]u8{0} ** 2,
        };

        _ = try file.writeAll(std.mem.asBytes(&pad_data));

        // Write sample data if present
        if (pad.has_sample) {
            _ = try file.writeAll(pad.sample.name[0..pad.sample.name_len]);
            _ = try file.writeAll(pad.sample.file_path[0..pad.sample.path_len]);
        }
    }
}

/// Internal: Load kit data from file
fn loadKitDataFromFile(file: std.fs.File) !models.Kit {
    // Read kit header
    var header: KitHeader = undefined;
    _ = try file.readAll(std.mem.asBytes(&header));

    if (header.magic != KIT_MAGIC) return error.InvalidMagic;
    if (header.version > KIT_VERSION) return error.UnsupportedVersion;

    var kit = models.Kit{};
    kit.name_len = header.name_len;
    kit.tempo = @as(u16, header.tempo_high) << 8 | header.tempo_low;
    kit.master_volume = header.master_volume;
    kit.master_fx_send = header.master_fx_send;

    // Read kit name
    _ = try file.readAll(kit.name[0..kit.name_len]);

    // Read each pad
    for (&kit.pads) |*pad| {
        var pad_data: PadData = undefined;
        _ = try file.readAll(std.mem.asBytes(&pad_data));

        pad.volume = pad_data.volume;
        pad.pan = pad_data.pan;
        pad.pitch = pad_data.pitch;
        pad.decay = pad_data.decay;
        pad.play_mode = @enumFromInt(pad_data.play_mode);
        pad.mute_group = @enumFromInt(pad_data.mute_group);
        pad.midi_note = pad_data.midi_note;
        pad.velocity_curve = pad_data.velocity_curve;
        pad.trigger_type = @enumFromInt(pad_data.trigger_type);
        pad.enabled = pad_data.enabled != 0;
        pad.has_sample = pad_data.has_sample != 0;
        pad.sample.name_len = pad_data.sample_name_len;
        pad.sample.path_len = @as(u16, pad_data.sample_path_len_high) << 8 | pad_data.sample_path_len_low;

        // Read sample data if present
        if (pad.has_sample) {
            _ = try file.readAll(pad.sample.name[0..pad.sample.name_len]);
            _ = try file.readAll(pad.sample.file_path[0..pad.sample.path_len]);
            pad.sample.loaded = true;
        }
    }

    return kit;
}

/// Get file extension from path
pub fn getExtension(path: []const u8) ?[]const u8 {
    var i = path.len;
    while (i > 0) {
        i -= 1;
        if (path[i] == '.') {
            return path[i + 1 ..];
        }
        if (path[i] == '/' or path[i] == '\\') {
            return null;
        }
    }
    return null;
}

/// Get filename from path
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

/// Check if a file is a supported audio format
pub fn isSupportedAudio(path: []const u8) bool {
    const ext = getExtension(path) orelse return false;

    const supported = [_][]const u8{
        "wav", "WAV",
        "aiff", "AIFF",
        "aif", "AIF",
    };

    for (supported) |s| {
        if (std.mem.eql(u8, ext, s)) return true;
    }

    return false;
}

/// Export kit to SPD-SX compatible format
pub fn exportToSpdSx(kit: *const models.Kit, path: []const u8) FileError!void {
    return saveKit(kit, path);
}

/// Import kit from SPD-SX format
pub fn importFromSpdSx(path: []const u8) FileError!models.Kit {
    return loadKit(path);
}
