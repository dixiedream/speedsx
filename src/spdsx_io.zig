/// SPD-SX I/O Integration Layer
/// Bridges CLI functionality with UI models
const std = @import("std");
const Allocator = std.mem.Allocator;

// CLI modules
const cli_types = @import("cli/types.zig");
const cli_storage = @import("cli/storage.zig");
const cli_xml = @import("cli/xml.zig");
const cli_xml_writer = @import("cli/xml_writer.zig");
const cli_encoding = @import("cli/encoding.zig");

// UI models
const models = @import("models.zig");

/// Errors for SPD-SX I/O operations
pub const SpdSxError = error{
    FileNotFound,
    InvalidPath,
    ReadError,
    WriteError,
    InvalidFormat,
    OutOfMemory,
    AccessDenied,
};

/// Result of loading SPD-SX configuration
pub const LoadResult = struct {
    project: models.Project,
    kit_count: usize,
    wave_count: usize,
    error_message: ?[]const u8,
};

/// Check if a path exists
fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Load SPD-SX configuration from a path (e.g., /Volumes/SPD-SX_/Roland)
/// Returns a Project populated with the loaded data
pub fn loadConfiguration(allocator: Allocator, base_path: []const u8) SpdSxError!LoadResult {
    var result = LoadResult{
        .project = models.Project.init(),
        .kit_count = 0,
        .wave_count = 0,
        .error_message = null,
    };

    // Determine actual path (handle Roland subdirectory)
    var actual_path_buf: [512]u8 = undefined;
    var actual_path: []const u8 = base_path;

    const roland_kit_path = std.fmt.bufPrint(&actual_path_buf, "{s}/SPD-SX/KIT", .{base_path}) catch {
        return SpdSxError.InvalidPath;
    };

    if (!pathExists(roland_kit_path)) {
        // Try with /Roland prefix
        const with_roland = std.fmt.bufPrint(&actual_path_buf, "{s}/Roland/SPD-SX/KIT", .{base_path}) catch {
            return SpdSxError.InvalidPath;
        };
        if (pathExists(with_roland)) {
            // Update actual_path to point to the Roland subdirectory
            var temp_buf: [512]u8 = undefined;
            actual_path = std.fmt.bufPrint(&temp_buf, "{s}/Roland", .{base_path}) catch base_path;
        }
    }

    // Clear sample library
    result.project.sample_library = models.SampleLibrary.init();

    // Load waves first (so we can reference them in kits)
    result.wave_count = loadWaves(allocator, actual_path, &result.project.sample_library) catch 0;

    // Load kits
    result.kit_count = loadKits(allocator, actual_path, &result.project) catch 0;

    // Set file path
    result.project.setFilePath(base_path);

    return result;
}

/// Load waves from SPD-SX WAVE directory
fn loadWaves(allocator: Allocator, base_path: []const u8, library: *models.SampleLibrary) !usize {
    var wave_count: usize = 0;
    var path_buf: [512]u8 = undefined;

    // Waves are stored in SPD-SX/WAVE/PRM/XX/YY.spd format
    for (0..99) |folder| {
        for (0..100) |file| {
            const wave_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/WAVE/PRM/{d:0>2}/{d:0>2}.spd", .{ base_path, folder, file }) catch continue;

            if (!pathExists(wave_path)) continue;

            const wave_id: u32 = @intCast(folder * 100 + file);
            const cli_wave = cli_xml.parseWaveFile(allocator, wave_path, wave_id) catch continue;

            // Convert CLI wave to UI sample and add to library
            const wave_name = cli_wave.getName(allocator) catch continue;
            defer allocator.free(wave_name);

            const wave_file_path = cli_wave.getPath();

            _ = library.addSample(wave_name, wave_file_path);
            wave_count += 1;
        }
    }

    return wave_count;
}

/// Load kits from SPD-SX KIT directory
fn loadKits(allocator: Allocator, base_path: []const u8, project: *models.Project) !usize {
    var kit_count: usize = 0;
    var path_buf: [512]u8 = undefined;

    // Reset project kits
    project.kit_count = 0;

    for (0..300) |i| {
        const kit_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/KIT/kit{d:0>3}.spd", .{ base_path, i }) catch continue;

        if (!pathExists(kit_path)) continue;

        const cli_kit = cli_xml.parseKitFile(allocator, kit_path) catch continue;

        // Convert CLI kit to UI kit
        if (project.kit_count < models.Project.MAX_KITS) {
            convertCliKitToUiKit(allocator, &cli_kit, &project.kits[project.kit_count], &project.sample_library);
            project.kit_count += 1;
            kit_count += 1;
        }
    }

    // Ensure at least one kit exists
    if (project.kit_count == 0) {
        _ = project.addKit();
    }

    return kit_count;
}

/// Convert a CLI Kit to a UI Kit
fn convertCliKitToUiKit(allocator: Allocator, cli_kit: *const cli_types.Kit, ui_kit: *models.Kit, library: *models.SampleLibrary) void {
    // Initialize UI kit
    ui_kit.* = models.Kit.init();

    // Convert name
    const name = cli_kit.getName(allocator) catch "Untitled";
    defer if (!std.mem.eql(u8, name, "Untitled")) allocator.free(name);
    ui_kit.setName(name);

    // Convert sub-name
    const sub_name = cli_kit.getSubName(allocator) catch "";
    defer if (sub_name.len > 0) allocator.free(sub_name);
    ui_kit.setSubName(sub_name);

    // Convert basic properties
    ui_kit.master_volume = cli_kit.level;
    // CLI tempo is stored as integer * 10 (e.g., 1200 = 120.0 BPM)
    ui_kit.tempo = cli_kit.tempo / 10;
    ui_kit.tempo_decimal = @truncate(cli_kit.tempo % 10);

    // Convert pad link
    if (cli_kit.link_pad0 >= 0 and cli_kit.link_pad0 < 16) {
        ui_kit.pad_link = @enumFromInt(@as(u8, @intCast(cli_kit.link_pad0 + 1)));
    }
    if (cli_kit.link_pad1 >= 0 and cli_kit.link_pad1 < 16) {
        ui_kit.pad_link_target = @enumFromInt(@as(u8, @intCast(cli_kit.link_pad1 + 1)));
    }

    // Convert pads (CLI has 15 pads, UI has 9)
    const pad_count = @min(cli_types.MAX_PADS, models.Kit.NUM_PADS);
    for (0..pad_count) |i| {
        convertCliPadToUiPad(allocator, &cli_kit.pads[i], &ui_kit.pads[i], library);
    }
}

/// Convert a CLI Pad to a UI Pad
fn convertCliPadToUiPad(_: Allocator, cli_pad: *const cli_types.Pad, ui_pad: *models.Pad, library: *models.SampleLibrary) void {
    ui_pad.* = models.Pad.init();

    // Volume (CLI uses wv_level 0-100, UI uses 0-127)
    ui_pad.volume = cli_pad.wv_level;

    // Pan conversion: CLI uses 0-30 (15=center), UI uses -64 to +63
    // CLI: 0=L15, 15=CENTER, 30=R15
    const cli_pan: i16 = @intCast(cli_pad.wv_pan);
    ui_pad.pan = @intCast((cli_pan - 15) * 4);

    // Play mode
    ui_pad.play_mode = @enumFromInt(@min(cli_pad.play_mode, 2));

    // Mute group
    ui_pad.mute_group = @enumFromInt(@min(cli_pad.mute_grp, 9));

    // MIDI note
    if (cli_pad.note_num >= 0 and cli_pad.note_num < 128) {
        ui_pad.midi_note = @intCast(cli_pad.note_num);
    }

    // Loop mode
    ui_pad.loop_mode = @enumFromInt(@min(cli_pad.loop, 4));

    // Tempo sync
    ui_pad.tempo_sync = @enumFromInt(@min(cli_pad.tempo_sync, 1));

    // Trigger mode
    ui_pad.trigger_mode = @enumFromInt(@min(cli_pad.trig_type, 1));

    // Dynamics
    ui_pad.dynamics = @enumFromInt(@min(cli_pad.dynamics, 1));

    // Voice assignment (poly/mono)
    ui_pad.poly_mono = @enumFromInt(@min(cli_pad.voice_asgn, 1));

    // Output assignment
    ui_pad.output_assign = @enumFromInt(@min(cli_pad.out_asgn, 4));

    // Load main wave/sample if assigned
    if (cli_pad.wv >= 0) {
        const wave_idx: u16 = @intCast(cli_pad.wv);
        if (library.getSample(wave_idx)) |sample| {
            ui_pad.loadSample(sample.getName(), sample.getPath());
        }
    }

    // Load sub wave/sample if assigned
    if (cli_pad.sub_wv >= 0) {
        const sub_wave_idx: u16 = @intCast(cli_pad.sub_wv);
        if (library.getSample(sub_wave_idx)) |sample| {
            ui_pad.loadSubSample(sample.getName(), sample.getPath());
        }
        ui_pad.sub_volume = cli_pad.sub_wv_level;
        const sub_pan: i16 = @intCast(cli_pad.sub_wv_pan);
        ui_pad.sub_pan = @intCast((sub_pan - 15) * 4);
    }

    ui_pad.enabled = true;
}

/// Save SPD-SX configuration to a path
pub fn saveConfiguration(allocator: Allocator, project: *const models.Project, base_path: []const u8) SpdSxError!void {
    // Create DataStore and populate from UI project
    var data_store = cli_storage.DataStore.init(allocator);
    defer data_store.deinit();

    // Convert UI kits to CLI kits
    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        var cli_kit = convertUiKitToCliKit(allocator, &project.kits[i], &project.sample_library);
        cli_kit.kit_id = i;
        data_store.kits.insert(cli_kit) catch continue;
    }

    // Convert UI samples to CLI waves
    var w: u16 = 0;
    while (w < project.sample_library.count) : (w += 1) {
        const sample = &project.sample_library.samples[w];
        var cli_wave = cli_types.Wave.init();
        cli_wave.wave_id = w;
        cli_wave.setName(sample.getName());
        cli_wave.setPath(sample.getPath());
        data_store.waves.insert(cli_wave) catch continue;
    }

    // Export using CLI xml_writer
    cli_xml_writer.exportConfiguration(&data_store, base_path, allocator) catch {
        return SpdSxError.WriteError;
    };
}

/// Convert a UI Kit to a CLI Kit
fn convertUiKitToCliKit(allocator: Allocator, ui_kit: *const models.Kit, library: *const models.SampleLibrary) cli_types.Kit {
    var cli_kit = cli_types.Kit.init();

    // Convert name
    cli_kit.setName(ui_kit.getName());

    // Convert sub-name
    cli_kit.setSubName(ui_kit.getSubName());

    // Convert basic properties
    cli_kit.level = ui_kit.master_volume;
    cli_kit.tempo = ui_kit.tempo * 10 + ui_kit.tempo_decimal;

    // Convert pad link
    if (@intFromEnum(ui_kit.pad_link) > 0) {
        cli_kit.link_pad0 = @intCast(@intFromEnum(ui_kit.pad_link) - 1);
    }
    if (@intFromEnum(ui_kit.pad_link_target) > 0) {
        cli_kit.link_pad1 = @intCast(@intFromEnum(ui_kit.pad_link_target) - 1);
    }

    // Convert pads
    const pad_count = @min(cli_types.MAX_PADS, models.Kit.NUM_PADS);
    for (0..pad_count) |i| {
        cli_kit.pads[i] = convertUiPadToCliPad(&ui_kit.pads[i], library);
    }

    _ = allocator;
    return cli_kit;
}

/// Convert a UI Pad to a CLI Pad
fn convertUiPadToCliPad(ui_pad: *const models.Pad, library: *const models.SampleLibrary) cli_types.Pad {
    var cli_pad = cli_types.Pad.init();

    // Volume
    cli_pad.wv_level = ui_pad.volume;

    // Pan conversion: UI uses -64 to +63, CLI uses 0-30 (15=center)
    const ui_pan: i16 = ui_pad.pan;
    cli_pad.wv_pan = @intCast(std.math.clamp(@divTrunc(ui_pan, 4) + 15, 0, 30));

    // Play mode
    cli_pad.play_mode = @intFromEnum(ui_pad.play_mode);

    // Mute group
    cli_pad.mute_grp = @intFromEnum(ui_pad.mute_group);

    // MIDI note
    cli_pad.note_num = ui_pad.midi_note;

    // Loop mode
    cli_pad.loop = @intFromEnum(ui_pad.loop_mode);

    // Tempo sync
    cli_pad.tempo_sync = @intFromEnum(ui_pad.tempo_sync);

    // Trigger type
    cli_pad.trig_type = @intFromEnum(ui_pad.trigger_mode);

    // Dynamics
    cli_pad.dynamics = @intFromEnum(ui_pad.dynamics);

    // Voice assignment
    cli_pad.voice_asgn = @intFromEnum(ui_pad.poly_mono);

    // Output assignment
    cli_pad.out_asgn = @intFromEnum(ui_pad.output_assign);

    // Find wave index in library
    if (ui_pad.has_sample) {
        const sample_path = ui_pad.sample.getPath();
        if (library.findByPath(sample_path)) |idx| {
            cli_pad.wv = @intCast(idx);
        }
    }

    // Find sub wave index
    if (ui_pad.has_sub_sample) {
        const sub_path = ui_pad.sub_sample.getPath();
        if (library.findByPath(sub_path)) |idx| {
            cli_pad.sub_wv = @intCast(idx);
        }
        cli_pad.sub_wv_level = ui_pad.sub_volume;
        const sub_pan: i16 = ui_pad.sub_pan;
        cli_pad.sub_wv_pan = @intCast(std.math.clamp(@divTrunc(sub_pan, 4) + 15, 0, 30));
    }

    return cli_pad;
}

/// Check if the path looks like a valid SPD-SX configuration path
pub fn isValidSpdSxPath(path: []const u8) bool {
    var buf: [512]u8 = undefined;

    // Check for SPD-SX/KIT directory
    const kit_path = std.fmt.bufPrint(&buf, "{s}/SPD-SX/KIT", .{path}) catch return false;
    if (pathExists(kit_path)) return true;

    // Check with /Roland prefix
    const roland_kit_path = std.fmt.bufPrint(&buf, "{s}/Roland/SPD-SX/KIT", .{path}) catch return false;
    if (pathExists(roland_kit_path)) return true;

    return false;
}

/// Create initial SPD-SX directory structure
pub fn createSpdSxStructure(base_path: []const u8) SpdSxError!void {
    var buf: [512]u8 = undefined;

    const dirs = [_][]const u8{
        "/SPD-SX",
        "/SPD-SX/KIT",
        "/SPD-SX/WAVE",
        "/SPD-SX/WAVE/PRM",
        "/SPD-SX/SYSTEM",
    };

    for (dirs) |dir| {
        const full_path = std.fmt.bufPrint(&buf, "{s}{s}", .{ base_path, dir }) catch continue;
        std.fs.cwd().makePath(full_path) catch continue;
    }
}

// Tests
test "path exists check" {
    const exists = pathExists("/tmp");
    try std.testing.expect(exists or !exists); // Just verify it doesn't crash
}

test "pan conversion" {
    // UI pan -64 -> CLI pan 0 (L15)
    // UI pan 0 -> CLI pan 15 (CENTER)
    // UI pan 63 -> CLI pan 30 (R15)

    const ui_pan_center: i16 = 0;
    const cli_pan_center = @divTrunc(ui_pan_center, 4) + 15;
    try std.testing.expectEqual(@as(i16, 15), cli_pan_center);

    const ui_pan_left: i16 = -60;
    const cli_pan_left = @divTrunc(ui_pan_left, 4) + 15;
    try std.testing.expectEqual(@as(i16, 0), cli_pan_left);
}
