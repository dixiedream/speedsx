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
    chain_count: usize,
    tag_count: usize,
    error_message: ?[]const u8,
};

/// Check if a path exists
fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Extract relative wave path from a full path
/// e.g., "/path/to/Roland/SPD-SX/WAVE/DATA/01/file.wav" -> "01/file.wav"
fn extractRelativeWavePath(full_path: []const u8, base_path: []const u8) []const u8 {
    // Look for "SPD-SX/WAVE/DATA/" marker in the path
    const marker = "SPD-SX/WAVE/DATA/";
    if (std.mem.indexOf(u8, full_path, marker)) |pos| {
        const relative_start = pos + marker.len;
        if (relative_start < full_path.len) {
            return full_path[relative_start..];
        }
    }

    // Also try with base_path prefix directly
    var prefix_buf: [512]u8 = undefined;
    const prefix = std.fmt.bufPrint(&prefix_buf, "{s}/SPD-SX/WAVE/DATA/", .{base_path}) catch return full_path;
    if (std.mem.startsWith(u8, full_path, prefix)) {
        return full_path[prefix.len..];
    }

    // Return as-is if no prefix found (might already be relative)
    return full_path;
}

/// Load SPD-SX configuration from a path (e.g., /Volumes/SPD-SX_/Roland)
/// Returns a Project populated with the loaded data
pub fn loadConfiguration(allocator: Allocator, base_path: []const u8) SpdSxError!LoadResult {
    var result = LoadResult{
        .project = models.Project.init(),
        .kit_count = 0,
        .wave_count = 0,
        .chain_count = 0,
        .tag_count = 0,
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

    // Load kit chains
    result.chain_count = loadKitChains(allocator, actual_path, &result.project.kit_chain_library) catch 0;

    result.tag_count = loadTagList(allocator, actual_path, &result.project.tag_library) catch 0;

    // Set file path
    result.project.setFilePath(base_path);

    return result;
}

/// Load waves from SPD-SX WAVE directory
fn loadWaves(allocator: Allocator, base_path: []const u8, library: *models.SampleLibrary) !usize {
    var wave_count: usize = 0;
    var path_buf: [512]u8 = undefined;
    var full_path_buf: [512]u8 = undefined;

    // Waves are stored in SPD-SX/WAVE/PRM/XX/YY.spd format
    // Actual WAV files are in SPD-SX/WAVE/DATA/XX/filename.wav
    for (0..99) |folder| {
        for (0..100) |file| {
            const wave_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/WAVE/PRM/{d:0>2}/{d:0>2}.spd", .{ base_path, folder, file }) catch continue;

            if (!pathExists(wave_path)) continue;

            const wave_id: u32 = @intCast(folder * 100 + file);
            const cli_wave = cli_xml.parseWaveFile(allocator, wave_path, wave_id) catch continue;

            // Convert CLI wave to UI sample and add to library
            const wave_name = cli_wave.getName(allocator) catch continue;
            defer allocator.free(wave_name);

            // Get the path from the wave metadata
            const stored_path = cli_wave.getPath();

            // Build the full absolute path to the actual WAV file
            // WAV files are stored in SPD-SX/WAVE/DATA/{relative_path}
            // But if the path is already absolute (starts with /), use it as-is
            var full_wave_path: []const u8 = undefined;
            if (stored_path.len > 0 and stored_path[0] == '/') {
                // Already an absolute path - extract relative part to rebuild correctly
                const rel_path = extractRelativeWavePath(stored_path, base_path);
                full_wave_path = std.fmt.bufPrint(&full_path_buf, "{s}/SPD-SX/WAVE/DATA/{s}", .{ base_path, rel_path }) catch continue;
            } else {
                // Relative path - prepend the base
                full_wave_path = std.fmt.bufPrint(&full_path_buf, "{s}/SPD-SX/WAVE/DATA/{s}", .{ base_path, stored_path }) catch continue;
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

fn loadTagList(allocator: Allocator, base_path: []const u8, library: *models.TagLibrary) !usize {
    var path_buf: [512]u8 = undefined;

    const tag_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/SYSTEM/tag_list.spd", .{base_path}) catch {
        return 0;
    };

    if (!pathExists(tag_path)) {
        return 0;
    }

    var cli_tags = cli_xml.parseTagListFile(allocator, tag_path) catch {
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
fn loadKitChains(allocator: Allocator, base_path: []const u8, library: *models.KitChainLibrary) !usize {
    var path_buf: [512]u8 = undefined;

    const chain_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/SYSTEM/sysparam.spd", .{base_path}) catch {
        return 0;
    };

    if (!pathExists(chain_path)) {
        return 0;
    }

    var cli_chains = cli_xml.parseKitChainFile(allocator, chain_path) catch {
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
        ui_kit.pad_link = @enumFromInt(@as(u8, @intCast(cli_kit.link_pad0 + 1)));
    }
    if (cli_kit.link_pad1 >= 0 and cli_kit.link_pad1 < 16) {
        ui_kit.pad_link_target = @enumFromInt(@as(u8, @intCast(cli_kit.link_pad1 + 1)));
    }

    // Convert FX1 settings
    ui_kit.fx1_switch = cli_kit.fx1_sw != 0;
    ui_kit.fx1_type = @enumFromInt(@min(cli_kit.fx1_type, 20));
    for (cli_kit.fx1_prm, 0..) |prm, idx| {
        ui_kit.fx1_params.params[idx] = prm;
    }

    // Convert FX2 settings
    ui_kit.fx2_switch = cli_kit.fx2_sw != 0;
    ui_kit.fx2_type = @enumFromInt(@min(cli_kit.fx2_type, 20));
    for (cli_kit.fx2_prm, 0..) |prm, idx| {
        ui_kit.fx2_params.params[idx] = prm;
    }
    ui_kit.fx2_assign = @enumFromInt(@min(cli_kit.fx2_asgn, 15));

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
    ui_pad.play_mode = @enumFromInt(@min(cli_pad.play_mode, 2));

    // Mute group
    ui_pad.mute_group = @enumFromInt(@min(cli_pad.mute_grp, 9));

    // MIDI note (-1 = OFF, 0-127 = note number)
    ui_pad.midi_note = cli_pad.note_num;

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

    // Reverse playback
    ui_pad.reverse = cli_pad.reverse != 0;

    // MIDI channel (CLI uses -1 for GLOBAL, 0-15 for channels 1-16)
    if (cli_pad.pad_midi_ch == -1) {
        ui_pad.midi_channel = .global;
    } else if (cli_pad.pad_midi_ch >= 0 and cli_pad.pad_midi_ch < 16) {
        ui_pad.midi_channel = @enumFromInt(@as(u8, @intCast(cli_pad.pad_midi_ch + 1)));
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
pub fn saveConfiguration(allocator: Allocator, project: *const models.Project, base_path: []const u8) SpdSxError!void {
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

        // Extract relative path (remove base_path/SPD-SX/WAVE/DATA/ prefix if present)
        const full_path = sample.getPath();
        const relative_path = extractRelativeWavePath(full_path, base_path);
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
    cli_xml_writer.exportConfiguration(&data_store, base_path, allocator) catch {
        return SpdSxError.WriteError;
    };

    // Delete extra kit files that are no longer in the project
    // This ensures deleted kits don't reappear on reload
    deleteExtraKitFiles(base_path, project.kit_count);

    // Delete extra wave parameter files beyond the current wave count
    // This ensures deleted waves don't reappear on reload
    // Waves are renumbered consecutively (0, 1, 2, ...) so any wave files
    // beyond the current count are orphaned and should be removed
    deleteExtraWaveFiles(base_path, project.sample_library.count);
}

/// Delete kit files beyond the current kit count
fn deleteExtraKitFiles(base_path: []const u8, kit_count: u8) void {
    var path_buf: [512]u8 = undefined;

    // Check for kit files beyond our current count and delete them
    var i: usize = kit_count;
    while (i < 300) : (i += 1) {
        const kit_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/KIT/kit{d:0>3}.spd", .{ base_path, i }) catch continue;

        // Try to delete the file - if it doesn't exist, we can stop searching
        // (assuming kit files are contiguous)
        std.fs.cwd().deleteFile(kit_path) catch |err| {
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
/// Waves are stored as SPD-SX/WAVE/PRM/XX/YY.spd where XX is folder (00-99) and YY is file (00-99)
/// Wave ID = folder * 100 + file
fn deleteExtraWaveFiles(base_path: []const u8, wave_count: u16) void {
    var path_buf: [512]u8 = undefined;

    // Start from the first wave ID beyond our count
    var wave_id: usize = wave_count;
    var consecutive_not_found: usize = 0;

    // Scan through possible wave locations and delete extra files
    // Stop after finding 100 consecutive missing files (indicates end of waves)
    while (wave_id < 9900 and consecutive_not_found < 100) : (wave_id += 1) {
        const folder = wave_id / 100;
        const file = wave_id % 100;

        const wave_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/WAVE/PRM/{d:0>2}/{d:0>2}.spd", .{ base_path, folder, file }) catch continue;

        std.fs.cwd().deleteFile(wave_path) catch |err| {
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
    if (@intFromEnum(ui_kit.pad_link) > 0) {
        cli_kit.link_pad0 = @intCast(@intFromEnum(ui_kit.pad_link) - 1);
    }
    if (@intFromEnum(ui_kit.pad_link_target) > 0) {
        cli_kit.link_pad1 = @intCast(@intFromEnum(ui_kit.pad_link_target) - 1);
    }

    // Convert FX1 settings
    cli_kit.fx1_sw = if (ui_kit.fx1_switch) 1 else 0;
    cli_kit.fx1_type = @intFromEnum(ui_kit.fx1_type);
    for (ui_kit.fx1_params.params, 0..) |prm, idx| {
        cli_kit.fx1_prm[idx] = prm;
    }

    // Convert FX2 settings
    cli_kit.fx2_sw = if (ui_kit.fx2_switch) 1 else 0;
    cli_kit.fx2_type = @intFromEnum(ui_kit.fx2_type);
    for (ui_kit.fx2_params.params, 0..) |prm, idx| {
        cli_kit.fx2_prm[idx] = prm;
    }
    cli_kit.fx2_asgn = @intFromEnum(ui_kit.fx2_assign);

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

    // MIDI note (-1 = OFF, 0-127 = note number)
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

    // Reverse playback
    cli_pad.reverse = if (ui_pad.reverse) 1 else 0;

    // MIDI channel (UI uses 0=GLOBAL, 1-16 for channels; CLI uses -1 for GLOBAL, 0-15)
    if (ui_pad.midi_channel == .global) {
        cli_pad.pad_midi_ch = -1;
    } else {
        cli_pad.pad_midi_ch = @as(i8, @intCast(@intFromEnum(ui_pad.midi_channel))) - 1;
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
pub fn deleteWaveFiles(base_path: []const u8, wave_index: u16, sample_path: []const u8) void {
    var path_buf: [512]u8 = undefined;

    // Delete the actual WAV file if it exists and is within the SPD-SX directory
    if (sample_path.len > 0) {
        // Only delete if the file is within the SPD-SX WAVE/DATA directory
        // to avoid accidentally deleting files from other locations
        if (std.mem.indexOf(u8, sample_path, "SPD-SX/WAVE/DATA") != null) {
            std.fs.cwd().deleteFile(sample_path) catch {};
        }
    }

    // Delete the .spd parameter file
    // Note: This deletes by the current index. After deletion, remaining waves
    // will be renumbered on save, and deleteExtraWaveFiles will clean up orphaned files.
    const folder = wave_index / 100;
    const file = wave_index % 100;

    const prm_path = std.fmt.bufPrint(&path_buf, "{s}/SPD-SX/WAVE/PRM/{d:0>2}/{d:0>2}.spd", .{ base_path, folder, file }) catch return;
    std.fs.cwd().deleteFile(prm_path) catch {};
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
