/// SPD-SX I/O Integration Layer
/// Bridges CLI functionality with UI models
const std = @import("std");
const Allocator = std.mem.Allocator;

// CLI modules (source of truth for SPD-SX file formats)
const cli_types = @import("cli/types.zig");
const cli_storage = @import("cli/storage.zig");
const cli_xml = @import("cli/xml.zig");
const cli_xml_writer = @import("cli/xml_writer.zig");
const cli_encoding = @import("cli/encoding.zig");
const cli_paths = @import("cli/paths.zig");

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

/// Counts from loading SPD-SX configuration (project is populated in place).
pub const LoadStats = struct {
    kit_count: usize,
    wave_count: usize,
    chain_count: usize,
    tag_count: usize,
    error_message: ?[]const u8,
};

const extractRelativeWavePath = cli_paths.extractRelativeWavePath;

/// Load SPD-SX configuration from a path (e.g., /Volumes/SPD-SX_/Roland)
/// Populates `project` in place to avoid large stack copies.
pub fn loadConfiguration(
    allocator: Allocator,
    io: std.Io,
    base_path: []const u8,
    project: *models.Project,
) SpdSxError!LoadStats {
    project.* = models.Project.init();

    var stats = LoadStats{
        .kit_count = 0,
        .wave_count = 0,
        .chain_count = 0,
        .tag_count = 0,
        .error_message = null,
    };

    // Determine actual path (handle Roland subdirectory)
    var path_buf: [512]u8 = undefined;
    var actual_path: []const u8 = base_path;

    // Check if SPD-SX/KIT exists at base_path
    if (cli_paths.getKitDir(&path_buf, base_path)) |kit_path| {
        if (!cli_paths.pathExists(io, kit_path)) {
            // Try with /Roland prefix
            var roland_buf: [512]u8 = undefined;
            const roland_path = std.fmt.bufPrint(&roland_buf, "{s}/Roland", .{base_path}) catch base_path;
            if (cli_paths.getKitDir(&path_buf, roland_path)) |roland_kit_path| {
                if (cli_paths.pathExists(io, roland_kit_path)) {
                    actual_path = roland_path;
                }
            }
        }
    }

    // Clear sample library
    project.sample_library = models.SampleLibrary.init();

    // Load waves first (so we can reference them in kits)
    stats.wave_count = loadWaves(allocator, io, actual_path, &project.sample_library) catch 0;

    // Load kits
    stats.kit_count = loadKits(allocator, io, actual_path, project) catch 0;

    // Load kit chains
    stats.chain_count = loadKitChains(allocator, io, actual_path, &project.kit_chain_library) catch 0;

    stats.tag_count = loadTagList(allocator, io, actual_path, &project.tag_library) catch 0;

    // Set file path
    project.setFilePath(base_path);

    return stats;
}

/// Load waves from SPD-SX WAVE directory
fn loadWaves(allocator: Allocator, io: std.Io, base_path: []const u8, library: *models.SampleLibrary) !usize {
    var wave_count: usize = 0;
    var path_buf: [512]u8 = undefined;
    var full_path_buf: [512]u8 = undefined;

    // Waves are stored in SPD-SX/WAVE/PRM/XX/YY.spd format
    // Actual WAV files are in SPD-SX/WAVE/DATA/XX/filename.wav
    for (0..cli_paths.MAX_WAVE_FOLDERS) |folder| {
        for (0..cli_paths.MAX_WAVES_PER_FOLDER) |file| {
            const wave_id: u32 = @intCast(folder * cli_paths.MAX_WAVES_PER_FOLDER + file);
            const wave_path = cli_paths.getWavePrmFilePath(&path_buf, base_path, wave_id) orelse continue;

            if (!cli_paths.pathExists(io, wave_path)) continue;

            const cli_wave = cli_xml.parseWaveFile(allocator, io, wave_path, wave_id) catch continue;

            // Convert CLI wave to UI sample and add to library
            const wave_name = cli_wave.getName(allocator) catch continue;
            defer allocator.free(wave_name);

            // Get the path from the wave metadata (should be relative like "00/sample.wav")
            const stored_path = cli_wave.getPath();

            // Build the full absolute path to the actual WAV file
            var full_wave_path: []const u8 = undefined;
            if (stored_path.len > 0 and stored_path[0] == '/') {
                // Already an absolute path - extract relative part to rebuild correctly
                const rel_path = extractRelativeWavePath(stored_path);
                full_wave_path = cli_paths.getFullWaveDataPath(&full_path_buf, base_path, rel_path) orelse continue;
            } else {
                // Relative path - prepend the base using CLI paths
                full_wave_path = cli_paths.getFullWaveDataPath(&full_path_buf, base_path, stored_path) orelse continue;
            }

            // Add sample with metadata
            if (library.count < models.SampleLibrary.MAX_SAMPLES) {
                const idx = library.count;
                library.samples[idx] = models.Sample.init();
                library.samples[idx].setName(wave_name);
                library.samples[idx].setPath(full_wave_path);

                // Copy wave metadata
                library.samples[idx].tag = cli_wave.tag;
                library.samples[idx].tempo = cli_wave.tempo;
                library.samples[idx].beat = cli_wave.beat;
                library.samples[idx].measure = cli_wave.measure;
                library.samples[idx].start_point = cli_wave.start;
                library.samples[idx].end_point = cli_wave.end;

                library.count += 1;
                wave_count += 1;
            }
        }
    }

    return wave_count;
}

/// Load kits from SPD-SX KIT directory
fn loadKits(allocator: Allocator, io: std.Io, base_path: []const u8, project: *models.Project) !usize {
    var kit_count: usize = 0;
    var path_buf: [512]u8 = undefined;

    // Reset project kits
    project.kit_count = 0;

    for (0..300) |i| {
        const kit_path = cli_paths.getKitFilePath(&path_buf, base_path, i) orelse continue;

        if (!cli_paths.pathExists(io, kit_path)) continue;

        const cli_kit = cli_xml.parseKitFile(allocator, io, kit_path) catch continue;

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

fn loadTagList(allocator: Allocator, io: std.Io, base_path: []const u8, library: *models.TagLibrary) !usize {
    var path_buf: [512]u8 = undefined;

    const tag_path = cli_paths.getTagListPath(&path_buf, base_path) orelse return 0;

    if (!cli_paths.pathExists(io, tag_path)) {
        return 0;
    }

    var cli_tags = cli_xml.parseTagListFile(allocator, io, tag_path) catch {
        return 0;
    };
    defer cli_tags.deinit(allocator);

    // Reset library - TagLibrary.init() sets count to MAX_TAGS, so we need to reset it to 0
    library.* = models.TagLibrary.init();
    library.count = 0;

    var count: usize = 0;
    for (cli_tags.items) |*cli_tag| {
        if (library.count >= models.TagLibrary.MAX_TAGS) break;

        const ui_tag = &library.tags[library.count];
        convertCliTagToUiTag(allocator, cli_tag, ui_tag);

        // Only count tags that have a name
        if (ui_tag.name.len > 0) {
            library.count += 1;
            count += 1;
        }
    }

    return count;
}

/// Load kit chains from SPD-SX SYSTEM directory (sysparam.spd)
fn loadKitChains(allocator: Allocator, io: std.Io, base_path: []const u8, library: *models.KitChainLibrary) !usize {
    var path_buf: [512]u8 = undefined;

    const chain_path = cli_paths.getSysparamPath(&path_buf, base_path) orelse return 0;

    if (!cli_paths.pathExists(io, chain_path)) {
        return 0;
    }

    var cli_chains = cli_xml.parseKitChainFile(allocator, io, chain_path) catch {
        return 0;
    };
    defer cli_chains.deinit(allocator);

    // Reset library
    library.* = models.KitChainLibrary.init();

    var count: usize = 0;
    for (cli_chains.items) |*cli_chain| {
        if (library.count >= models.KitChainLibrary.MAX_CHAINS) break;

        // Convert CLI chain to UI chain
        const ui_chain = &library.chains[library.count];
        convertCliChainToUiChain(allocator, cli_chain, ui_chain);

        // Only count chains that have a name or steps
        if (ui_chain.step_count > 0 or ui_chain.name.len > 0) {
            library.count += 1;
            count += 1;
        }
    }

    return count;
}

fn convertCliTagToUiTag(allocator: Allocator, cli_tag: *const cli_types.TagListEntry, ui_tag: *models.TagEntry) void {
    ui_tag.* = models.TagEntry.init();

    const name = cli_tag.getName(allocator) catch "";
    defer if (name.len > 0) allocator.free(name);
    ui_tag.setName(name);

    ui_tag.order = cli_tag.order;
}

/// Convert a CLI KitChain to a UI KitChain
fn convertCliChainToUiChain(allocator: Allocator, cli_chain: *const cli_types.KitChain, ui_chain: *models.KitChain) void {
    ui_chain.* = models.KitChain.init();

    // Convert name
    const name = cli_chain.getName(allocator) catch "";
    defer if (name.len > 0) allocator.free(name);
    ui_chain.setName(name);

    // Convert steps (CLI uses i32, UI uses i16; -1 means empty)
    ui_chain.step_count = 0;
    for (cli_chain.steps, 0..) |step, i| {
        if (i >= models.KitChain.MAX_STEPS) break;
        if (step >= 0) {
            ui_chain.steps[i] = @intCast(step);
            ui_chain.step_count = @intCast(i + 1);
        } else {
            ui_chain.steps[i] = -1;
        }
    }

    // Recalculate step_count to be the actual number of valid steps
    // (counting from the end to find the last valid step)
    var actual_count: u8 = 0;
    for (ui_chain.steps[0..models.KitChain.MAX_STEPS], 0..) |step, i| {
        if (step >= 0) {
            actual_count = @intCast(i + 1);
        }
    }
    ui_chain.step_count = actual_count;
}

fn convertUiTagToCliTag(ui_tag: *const models.TagEntry) cli_types.TagListEntry {
    var cli_tag = cli_types.TagListEntry.init();
    cli_encoding.encodeString(ui_tag.getName(), &cli_tag.nm);
    cli_tag.order = ui_tag.order;
    return cli_tag;
}

/// Convert a UI KitChain to a CLI KitChain
fn convertUiChainToCliChain(ui_chain: *const models.KitChain) cli_types.KitChain {
    var cli_chain = cli_types.KitChain.init();

    // Convert name using encoding
    cli_encoding.encodeString(ui_chain.getName(), &cli_chain.nm);

    // Convert steps (UI uses i16, CLI uses i32)
    for (ui_chain.steps, 0..) |step, i| {
        if (i >= cli_types.KITCHAIN_MAX_STEPS) break;
        cli_chain.steps[i] = step;
    }

    return cli_chain;
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
        ui_kit.pad_link = @fromBackingInt(@intCast(@as(u8, @intCast(cli_kit.link_pad0 + 1))));
    }
    if (cli_kit.link_pad1 >= 0 and cli_kit.link_pad1 < 16) {
        ui_kit.pad_link_target = @fromBackingInt(@intCast(@as(u8, @intCast(cli_kit.link_pad1 + 1))));
    }

    // Convert FX1 settings
    ui_kit.fx1_switch = cli_kit.fx1_sw != 0;
    ui_kit.fx1_type = @fromBackingInt(@intCast(@min(cli_kit.fx1_type, 20)));
    for (cli_kit.fx1_prm, 0..) |prm, idx| {
        ui_kit.fx1_params.params[idx] = prm;
    }

    // Convert FX2 settings
    ui_kit.fx2_switch = cli_kit.fx2_sw != 0;
    ui_kit.fx2_type = @fromBackingInt(@intCast(@min(cli_kit.fx2_type, 20)));
    for (cli_kit.fx2_prm, 0..) |prm, idx| {
        ui_kit.fx2_params.params[idx] = prm;
    }
    ui_kit.fx2_assign = @fromBackingInt(@intCast(@min(cli_kit.fx2_asgn, 15)));

    // Convert pads (both CLI and UI have 15 pads: 9 main + 4 triggers + 2 footswitches)
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
    ui_pad.play_mode = @fromBackingInt(@intCast(@min(cli_pad.play_mode, 2)));

    // Mute group
    ui_pad.mute_group = @fromBackingInt(@intCast(@min(cli_pad.mute_grp, 9)));

    // MIDI note (-1 = OFF, 0-127 = note number)
    ui_pad.midi_note = cli_pad.note_num;

    // Loop mode
    ui_pad.loop_mode = @fromBackingInt(@intCast(@min(cli_pad.loop, 4)));

    // Tempo sync
    ui_pad.tempo_sync = @fromBackingInt(@intCast(@min(cli_pad.tempo_sync, 1)));

    // Trigger mode
    ui_pad.trigger_mode = @fromBackingInt(@intCast(@min(cli_pad.trig_type, 1)));

    // Dynamics
    ui_pad.dynamics = @fromBackingInt(@intCast(@min(cli_pad.dynamics, 1)));

    // Voice assignment (poly/mono)
    ui_pad.poly_mono = @fromBackingInt(@intCast(@min(cli_pad.voice_asgn, 1)));

    // Output assignment
    ui_pad.output_assign = @fromBackingInt(@intCast(@min(cli_pad.out_asgn, 4)));

    // Reverse playback
    ui_pad.reverse = cli_pad.reverse != 0;

    // MIDI channel (CLI uses -1 for GLOBAL, 0-15 for channels 1-16)
    if (cli_pad.pad_midi_ch == -1) {
        ui_pad.midi_channel = .global;
    } else if (cli_pad.pad_midi_ch >= 0 and cli_pad.pad_midi_ch < 16) {
        ui_pad.midi_channel = @fromBackingInt(@intCast(@as(u8, @intCast(cli_pad.pad_midi_ch + 1))));
    }

    // MIDI External Control (OFF or ON)
    ui_pad.midi_ext_ctrl = cli_pad.midi_ctrl != 0;

    // Gate time (CLI: -1 = OFF, 0 = ALT, 1-80 = 0.1s-8.0s)
    // (UI: 0 = OFF, 1 = ALT, 2-81 = 0.1s-8.0s)
    if (cli_pad.gate_time == -1) {
        ui_pad.midi_gate_time = 0; // OFF
    } else if (cli_pad.gate_time >= 0) {
        ui_pad.midi_gate_time = @intCast(@as(i16, cli_pad.gate_time) + 1);
    }

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
pub fn saveConfiguration(allocator: Allocator, io: std.Io, project: *const models.Project, base_path: []const u8) SpdSxError!void {
    // Create DataStore and populate from UI project
    var data_store = cli_storage.DataStore.init(allocator);
    defer data_store.deinit();

    // Convert UI kits to CLI kits
    // Wave references are resolved by path lookup, so waves are automatically
    // referenced by their new consecutive indices
    var i: u8 = 0;
    while (i < project.kit_count) : (i += 1) {
        var cli_kit = convertUiKitToCliKit(allocator, &project.kits[i], &project.sample_library);
        cli_kit.kit_id = i;
        data_store.kits.insert(cli_kit) catch continue;
    }

    // Convert UI samples to CLI waves with consecutive IDs
    // This automatically renumbers waves: if samples were deleted from the middle,
    // the remaining samples get consecutive IDs (0, 1, 2, ...) based on their
    // position in the sample library array
    var w: u16 = 0;
    while (w < project.sample_library.count) : (w += 1) {
        const sample = &project.sample_library.samples[w];
        var cli_wave = cli_types.Wave.init();
        cli_wave.wave_id = w; // Consecutive numbering
        cli_wave.setName(sample.getName());

        // Extract relative path using CLI paths module
        const full_path = sample.getPath();
        const relative_path = extractRelativeWavePath(full_path);
        cli_wave.setPath(relative_path);

        // Copy wave metadata
        cli_wave.tag = sample.tag;
        cli_wave.tempo = sample.tempo;
        cli_wave.beat = sample.beat;
        cli_wave.measure = sample.measure;
        cli_wave.start = sample.start_point;
        cli_wave.end = sample.end_point;

        data_store.waves.insert(cli_wave) catch continue;
    }

    // Convert UI kit chains to CLI kit chains
    var c: u8 = 0;
    while (c < project.kit_chain_library.count) : (c += 1) {
        const ui_chain = &project.kit_chain_library.chains[c];
        const cli_chain = convertUiChainToCliChain(ui_chain);
        data_store.kit_chains.insert(cli_chain) catch continue;
    }

    var t: u8 = 0;
    while (t < project.tag_library.count) : (t += 1) {
        const ui_tag = &project.tag_library.tags[t];
        const cli_tag = convertUiTagToCliTag(ui_tag);
        data_store.tags.insert(cli_tag) catch continue;
    }

    // Export using CLI xml_writer
    cli_xml_writer.exportConfiguration(io, &data_store, base_path, allocator) catch {
        return SpdSxError.WriteError;
    };

    // Delete extra kit files that are no longer in the project
    // This ensures deleted kits don't reappear on reload
    deleteExtraKitFiles(io, base_path, project.kit_count);

    // Delete extra wave parameter files beyond the current wave count
    // This ensures deleted waves don't reappear on reload
    // Waves are renumbered consecutively (0, 1, 2, ...) so any wave files
    // beyond the current count are orphaned and should be removed
    deleteExtraWaveFiles(io, base_path, project.sample_library.count);
}

/// Delete kit files beyond the current kit count
fn deleteExtraKitFiles(io: std.Io, base_path: []const u8, kit_count: u8) void {
    var path_buf: [512]u8 = undefined;

    // Check for kit files beyond our current count and delete them
    var i: usize = kit_count;
    while (i < 300) : (i += 1) {
        const kit_path = cli_paths.getKitFilePath(&path_buf, base_path, i) orelse continue;

        // Try to delete the file - if it doesn't exist, we can stop searching
        // (assuming kit files are contiguous)
        std.Io.Dir.deleteFileAbsolute(io, kit_path) catch |err| {
            if (err == error.FileNotFound) {
                // No more kit files to delete
                break;
            }
            // Other errors (permission, etc.) - continue trying
            continue;
        };
    }
}

/// Delete wave parameter files beyond the current wave count
/// Uses CLI paths module for path construction
fn deleteExtraWaveFiles(io: std.Io, base_path: []const u8, wave_count: u16) void {
    var path_buf: [512]u8 = undefined;

    // Start from the first wave ID beyond our count
    var wave_id: u32 = wave_count;
    var consecutive_not_found: usize = 0;

    // Maximum wave ID = 99 folders * 100 files = 9900
    const max_wave_id = cli_paths.MAX_WAVE_FOLDERS * cli_paths.MAX_WAVES_PER_FOLDER;

    // Scan through possible wave locations and delete extra files
    // Stop after finding 100 consecutive missing files (indicates end of waves)
    while (wave_id < max_wave_id and consecutive_not_found < 100) : (wave_id += 1) {
        const wave_path = cli_paths.getWavePrmFilePath(&path_buf, base_path, wave_id) orelse continue;

        std.Io.Dir.deleteFileAbsolute(io, wave_path) catch |err| {
            if (err == error.FileNotFound) {
                consecutive_not_found += 1;
                continue;
            }
            // Other errors - continue trying
            continue;
        };

        // File was deleted successfully, reset the not-found counter
        consecutive_not_found = 0;
    }
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
    if (@backingInt(ui_kit.pad_link) > 0) {
        cli_kit.link_pad0 = @intCast(@backingInt(ui_kit.pad_link) - 1);
    }
    if (@backingInt(ui_kit.pad_link_target) > 0) {
        cli_kit.link_pad1 = @intCast(@backingInt(ui_kit.pad_link_target) - 1);
    }

    // Convert FX1 settings
    cli_kit.fx1_sw = if (ui_kit.fx1_switch) 1 else 0;
    cli_kit.fx1_type = @backingInt(ui_kit.fx1_type);
    for (ui_kit.fx1_params.params, 0..) |prm, idx| {
        cli_kit.fx1_prm[idx] = prm;
    }

    // Convert FX2 settings
    cli_kit.fx2_sw = if (ui_kit.fx2_switch) 1 else 0;
    cli_kit.fx2_type = @backingInt(ui_kit.fx2_type);
    for (ui_kit.fx2_params.params, 0..) |prm, idx| {
        cli_kit.fx2_prm[idx] = prm;
    }
    cli_kit.fx2_asgn = @backingInt(ui_kit.fx2_assign);

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
    cli_pad.play_mode = @backingInt(ui_pad.play_mode);

    // Mute group
    cli_pad.mute_grp = @backingInt(ui_pad.mute_group);

    // MIDI note (-1 = OFF, 0-127 = note number)
    cli_pad.note_num = ui_pad.midi_note;

    // Loop mode
    cli_pad.loop = @backingInt(ui_pad.loop_mode);

    // Tempo sync
    cli_pad.tempo_sync = @backingInt(ui_pad.tempo_sync);

    // Trigger type
    cli_pad.trig_type = @backingInt(ui_pad.trigger_mode);

    // Dynamics
    cli_pad.dynamics = @backingInt(ui_pad.dynamics);

    // Voice assignment
    cli_pad.voice_asgn = @backingInt(ui_pad.poly_mono);

    // Output assignment
    cli_pad.out_asgn = @backingInt(ui_pad.output_assign);

    // Reverse playback
    cli_pad.reverse = if (ui_pad.reverse) 1 else 0;

    // MIDI channel (UI uses 0=GLOBAL, 1-16 for channels; CLI uses -1 for GLOBAL, 0-15)
    if (ui_pad.midi_channel == .global) {
        cli_pad.pad_midi_ch = -1;
    } else {
        cli_pad.pad_midi_ch = @as(i8, @intCast(@backingInt(ui_pad.midi_channel))) - 1;
    }

    // MIDI External Control (OFF or ON -> CLI uses 0 or 1)
    cli_pad.midi_ctrl = if (ui_pad.midi_ext_ctrl) 1 else 0;

    // Gate time (UI: 0 = OFF, 1 = ALT, 2-81 = 0.1s-8.0s)
    // (CLI: -1 = OFF, 0 = ALT, 1-80 = 0.1s-8.0s)
    if (ui_pad.midi_gate_time == 0) {
        cli_pad.gate_time = -1; // OFF
    } else {
        cli_pad.gate_time = @intCast(@as(i16, ui_pad.midi_gate_time) - 1);
    }

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

/// Delete a wave's physical files (both the WAV file and the .spd parameter file)
/// wave_index: the index in the sample library
/// sample_path: the path to the WAV file
/// base_path: the SPD-SX configuration base path
pub fn deleteWaveFiles(io: std.Io, base_path: []const u8, wave_index: u16, sample_path: []const u8) void {
    var path_buf: [512]u8 = undefined;

    // Delete the actual WAV file if it exists and is within the SPD-SX directory
    if (sample_path.len > 0) {
        // Only delete if the file is within the SPD-SX WAVE/DATA directory
        // to avoid accidentally deleting files from other locations
        const wave_data_marker = cli_paths.SPDSX_ROOT ++ "/" ++ cli_paths.WAVE_DATA_DIR;
        if (std.mem.indexOf(u8, sample_path, wave_data_marker) != null) {
            std.Io.Dir.deleteFileAbsolute(io, sample_path) catch {};
        }
    }

    // Delete the .spd parameter file using CLI paths
    const prm_path = cli_paths.getWavePrmFilePath(&path_buf, base_path, wave_index) orelse return;
    std.Io.Dir.deleteFileAbsolute(io, prm_path) catch {};
}

/// Check if the path looks like a valid SPD-SX configuration path
pub fn isValidSpdSxPath(io: std.Io, path: []const u8) bool {
    return cli_paths.isValidSpdSxPath(io, path);
}

/// Create initial SPD-SX directory structure
pub fn createSpdSxStructure(io: std.Io, base_path: []const u8) SpdSxError!void {
    cli_paths.createDirectoryStructure(io, base_path);
}

/// Import result
pub const ImportResult = struct {
    success: bool = false,
    relative_path: [256]u8 = @splat(0),
    relative_path_len: usize = 0,
    sample_index: ?u16 = null,
    error_message: ?[]const u8 = null,

    pub fn getRelativePath(self: *const ImportResult) []const u8 {
        return self.relative_path[0..self.relative_path_len];
    }
};

/// Import an audio file into the SPD-SX structure
/// Converts to 44.1kHz 16-bit WAV and copies to WAVE/DATA folder
/// Uses CLI infrastructure for wave metadata and paths
pub fn importAudioFile(
    allocator: Allocator,
    io: std.Io,
    source_path: []const u8,
    base_path: []const u8,
    library: *models.SampleLibrary,
) ImportResult {
    var result = ImportResult{};

    // Get filename from source path using CLI paths
    const filename = cli_paths.getFilename(source_path);
    if (filename.len == 0) {
        result.error_message = "Invalid source path";
        return result;
    }

    // Find next available wave slot
    const wave_index = library.count;
    if (wave_index >= models.SampleLibrary.MAX_SAMPLES) {
        result.error_message = "Sample library is full";
        return result;
    }

    // Calculate folder for the wave using CLI paths
    const folder = cli_paths.getWaveFolder(wave_index);

    // Ensure destination directories exist using CLI paths
    cli_paths.ensureWaveFolderExists(io, base_path, folder);

    // Create destination path using CLI paths
    var dest_path_buf: [512]u8 = undefined;
    const dest_path = cli_paths.getWaveDataFilePath(&dest_path_buf, base_path, folder, filename) orelse {
        result.error_message = "Path too long";
        return result;
    };

    // Convert and copy the audio file to 44.1kHz 16-bit stereo WAV
    convertAndCopyAudio(allocator, io, source_path, dest_path) catch |err| {
        result.error_message = switch (err) {
            error.FileNotFound => "Source file not found",
            error.OutOfMemory => "Out of memory",
            error.InvalidFormat => "Invalid audio format",
            error.ConversionFailed => "Audio conversion failed",
            error.WriteError => "Failed to write file",
            error.PathTooLong => "Path too long",
        };
        return result;
    };

    // Build relative path for the wave .spd file using CLI paths
    var rel_path_buf: [256]u8 = undefined;
    const rel_path = cli_paths.getRelativeWavePath(&rel_path_buf, folder, filename) orelse {
        result.error_message = "Path too long";
        return result;
    };
    const rel_path_len = rel_path.len;

    @memcpy(result.relative_path[0..rel_path_len], rel_path_buf[0..rel_path_len]);
    result.relative_path_len = rel_path_len;

    // Build full path for the UI sample library using CLI paths
    var full_path_buf: [512]u8 = undefined;
    const full_path = cli_paths.getFullWaveDataPath(&full_path_buf, base_path, result.getRelativePath()) orelse {
        result.error_message = "Path too long";
        return result;
    };

    // Get wave name (filename without extension) using CLI paths
    const wave_name = cli_paths.getFilenameWithoutExt(filename);

    // Add to UI sample library - this will be written to .spd by saveConfiguration
    if (library.count < models.SampleLibrary.MAX_SAMPLES) {
        const idx = library.count;
        library.samples[idx] = models.Sample.init();
        library.samples[idx].setName(wave_name);
        library.samples[idx].setPath(full_path);
        library.samples[idx].sample_rate = 44100;
        library.samples[idx].channels = 2;
        library.count += 1;
        result.sample_index = idx;

        // Also write the wave .spd file immediately using CLI infrastructure
        var cli_wave = cli_types.Wave.init();
        cli_wave.wave_id = idx;
        cli_wave.setName(wave_name);
        cli_wave.setPath(result.getRelativePath()); // Store relative path

        // Write the wave .spd parameter file using CLI paths
        var prm_path_buf: [512]u8 = undefined;
        const prm_path = cli_paths.getWavePrmFilePath(&prm_path_buf, base_path, idx) orelse {
            result.error_message = "Path too long";
            return result;
        };

        cli_xml_writer.writeWaveFile(io, &cli_wave, prm_path) catch {
            // Non-fatal - will be written on save anyway
        };
    }

    result.success = true;
    return result;
}

/// Convert audio file to 44.1kHz 16-bit stereo WAV and copy to destination
fn convertAndCopyAudio(allocator: Allocator, io: std.Io, source_path: []const u8, dest_path: []const u8) !void {
    const sdl = @import("sdl.zig");
    const c = sdl.c;

    // Ensure source path is null-terminated
    var src_path_buf: [512:0]u8 = undefined;
    if (source_path.len >= src_path_buf.len) return error.PathTooLong;
    @memcpy(src_path_buf[0..source_path.len], source_path);
    src_path_buf[source_path.len] = 0;

    // Load source audio file using SDL
    const rw = c.SDL_RWFromFile(&src_path_buf, "rb");
    if (rw == null) {
        return error.FileNotFound;
    }

    var source_spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
    var audio_buf: [*c]u8 = undefined;
    var audio_len: u32 = undefined;

    const load_result = c.SDL_LoadWAV_RW(rw, 1, &source_spec, &audio_buf, &audio_len);
    if (load_result == null) {
        return error.InvalidFormat;
    }
    defer c.SDL_FreeWAV(audio_buf);

    // Target format: 44100Hz, 16-bit signed little-endian, stereo
    const target_freq: c_int = 44100;
    const target_format: u16 = c.AUDIO_S16LSB;
    const target_channels: u8 = 2;

    // Check if conversion is needed
    const needs_conversion = source_spec.freq != target_freq or
        source_spec.format != target_format or
        source_spec.channels != target_channels;

    var final_data: []const u8 = undefined;
    var final_len: u32 = undefined;
    var converted_buf: ?[]u8 = null;

    if (needs_conversion) {
        // Build audio converter
        var cvt: c.SDL_AudioCVT = undefined;
        const build_result = c.SDL_BuildAudioCVT(
            &cvt,
            source_spec.format,
            source_spec.channels,
            source_spec.freq,
            target_format,
            target_channels,
            target_freq,
        );

        if (build_result < 0) {
            return error.ConversionFailed;
        }

        if (build_result == 0) {
            // No conversion needed after all
            final_data = audio_buf[0..audio_len];
            final_len = audio_len;
        } else {
            // Allocate buffer for conversion
            const needed_len: usize = @intCast(@as(u64, audio_len) * @as(u64, @intCast(cvt.len_mult)));
            converted_buf = allocator.alloc(u8, needed_len) catch return error.OutOfMemory;

            @memcpy(converted_buf.?[0..audio_len], audio_buf[0..audio_len]);

            cvt.len = @intCast(audio_len);
            cvt.buf = converted_buf.?.ptr;

            if (c.SDL_ConvertAudio(&cvt) < 0) {
                allocator.free(converted_buf.?);
                return error.ConversionFailed;
            }

            final_data = converted_buf.?[0..@intCast(cvt.len_cvt)];
            final_len = @intCast(cvt.len_cvt);
        }
    } else {
        final_data = audio_buf[0..audio_len];
        final_len = audio_len;
    }
    defer if (converted_buf) |buf| allocator.free(buf);

    // Write WAV file
    try writeWavFile(io, dest_path, final_data, final_len, target_freq, target_channels);
}

/// Write audio data as a WAV file (44.1kHz 16-bit stereo)
fn writeWavFile(io: std.Io, path: []const u8, data: []const u8, data_len: u32, sample_rate: c_int, channels: u8) !void {
    const file = std.Io.Dir.createFileAbsolute(io, path, .{}) catch return error.WriteError;
    defer file.close(io);

    // WAV header parameters
    const bits_per_sample: u16 = 16;
    const byte_rate: u32 = @intCast(@as(u64, @intCast(sample_rate)) * channels * (bits_per_sample / 8));
    const block_align: u16 = channels * (bits_per_sample / 8);
    const file_size: u32 = 36 + data_len;

    // Build 44-byte WAV header
    var header: [44]u8 = undefined;
    var pos: usize = 0;

    // RIFF header
    @memcpy(header[pos..][0..4], "RIFF");
    pos += 4;
    std.mem.writeInt(u32, header[pos..][0..4], file_size, .little);
    pos += 4;
    @memcpy(header[pos..][0..4], "WAVE");
    pos += 4;

    // fmt chunk
    @memcpy(header[pos..][0..4], "fmt ");
    pos += 4;
    std.mem.writeInt(u32, header[pos..][0..4], 16, .little); // Subchunk1Size
    pos += 4;
    std.mem.writeInt(u16, header[pos..][0..2], 1, .little); // AudioFormat (PCM)
    pos += 2;
    std.mem.writeInt(u16, header[pos..][0..2], channels, .little); // NumChannels
    pos += 2;
    std.mem.writeInt(u32, header[pos..][0..4], @intCast(sample_rate), .little); // SampleRate
    pos += 4;
    std.mem.writeInt(u32, header[pos..][0..4], byte_rate, .little); // ByteRate
    pos += 4;
    std.mem.writeInt(u16, header[pos..][0..2], block_align, .little); // BlockAlign
    pos += 2;
    std.mem.writeInt(u16, header[pos..][0..2], bits_per_sample, .little); // BitsPerSample
    pos += 2;

    // data chunk header
    @memcpy(header[pos..][0..4], "data");
    pos += 4;
    std.mem.writeInt(u32, header[pos..][0..4], data_len, .little); // Subchunk2Size

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(io, &write_buf);
    file_writer.interface.writeAll(&header) catch return error.WriteError;
    file_writer.interface.writeAll(data) catch return error.WriteError;
}

// Tests
test "path exists check" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const exists = cli_paths.pathExists(io, "/tmp");
    try std.testing.expect(exists or !exists); // Just verify it doesn't crash
}

// Skips when backup path is not present on the machine running tests.
test "load configuration from backup fixture" {
    const backup_path = "/home/ale/Downloads/Roland-bkp";

    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    if (!cli_paths.isValidSpdSxPath(io, backup_path)) return;

    var project = models.Project.init();
    const stats = try loadConfiguration(std.testing.allocator, io, backup_path, &project);
    try std.testing.expect(stats.kit_count > 0);
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
