//! SPD-SX Editor - Zig Port
//!
//! A command-line editor for Roland SPD-SX drum pad configuration files.
//! Ported from the Java version.
//!
//! Features:
//! - Load and save SPD-SX configuration from SD card
//! - List, view, and edit kits
//! - List, view, and edit waves
//! - Manage tags and kit chains
//! - Export configurations

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const types = @import("types.zig");
pub const encoding = @import("encoding.zig");
pub const storage = @import("storage.zig");
pub const xml = @import("xml.zig");
pub const xml_writer = @import("xml_writer.zig");

const DataStore = storage.DataStore;
const Kit = types.Kit;
const Wave = types.Wave;
const TagListEntry = types.TagListEntry;
const KitChain = types.KitChain;

/// Application state
const App = struct {
    data_store: DataStore,
    allocator: Allocator,
    loaded_path: ?[]u8 = null,

    pub fn init(allocator: Allocator) App {
        return .{
            .data_store = DataStore.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *App) void {
        if (self.loaded_path) |path| {
            self.allocator.free(path);
        }
        self.data_store.deinit();
    }
};

/// Print usage information
fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\SPD-SX Editor - Roland SPD-SX Configuration Tool
        \\
        \\Usage: spd-sx-editor <command> [options]
        \\
        \\Commands:
        \\  load <path>           Load configuration from SPD-SX SD card path
        \\  save <path>           Save configuration to path
        \\  list-kits             List all loaded kits
        \\  list-waves            List all loaded waves
        \\  list-tags             List all tags
        \\  list-chains           List all kit chains
        \\  show-kit <index>      Show details of a specific kit
        \\  show-wave <index>     Show details of a specific wave
        \\  rename-kit <idx> <name>  Rename a kit
        \\  rename-wave <idx> <name> Rename a wave
        \\  create-kit            Create a new empty kit
        \\  delete-kit <index>    Delete a kit
        \\  swap-kits <a> <b>     Swap two kits
        \\  export <path>         Export configuration to new location
        \\  help                  Show this help message
        \\  version               Show version information
        \\
        \\Examples:
        \\  spd-sx-editor load /media/SD_CARD
        \\  spd-sx-editor list-kits
        \\  spd-sx-editor show-kit 0
        \\  spd-sx-editor rename-kit 0 "My Kit"
        \\  spd-sx-editor save /media/SD_CARD
        \\
    );
}

/// Print version information
fn printVersion(writer: anytype) !void {
    try writer.writeAll(
        \\SPD-SX Editor v1.0.0
        \\Zig port of the Java SPD-SX Editor
        \\
        \\For Roland SPD-SX Sampling Pad
        \\
    );
}

/// Load configuration from SPD-SX path
fn loadConfiguration(app: *App, path: []const u8) !void {
    const stdout = getStdOutWriter();

    try stdout.print("Loading configuration from: {s}\n", .{path});

    // Clear existing data
    app.data_store.clear();

    // Determine actual path (handle Roland subdirectory)
    var actual_path_buf: [512]u8 = undefined;
    var actual_path: []const u8 = path;

    const roland_path = std.fmt.bufPrint(&actual_path_buf, "{s}/Roland/SPD-SX/KIT", .{path}) catch path;
    if (pathExists(roland_path)) {
        actual_path = std.fmt.bufPrint(&actual_path_buf, "{s}/Roland", .{path}) catch path;
    }

    // Load kits
    var kit_count: usize = 0;
    for (0..300) |i| {
        var kit_path_buf: [512]u8 = undefined;
        const kit_path = std.fmt.bufPrint(&kit_path_buf, "{s}/SPD-SX/KIT/kit{d:0>3}.spd", .{ actual_path, i }) catch continue;

        if (pathExists(kit_path)) {
            const kit = xml.parseKitFile(app.allocator, kit_path) catch {
                // Create empty kit for missing slots
                var empty_kit = Kit.init();
                empty_kit.kit_id = @intCast(i);
                try app.data_store.kits.insert(empty_kit);
                continue;
            };
            var mutable_kit = kit;
            mutable_kit.kit_id = @intCast(i);
            try app.data_store.kits.insert(mutable_kit);
            kit_count += 1;
        }
    }

    // Load waves
    var wave_count: usize = 0;
    for (0..99) |folder| {
        for (0..100) |file| {
            var wave_path_buf: [512]u8 = undefined;
            const wave_path = std.fmt.bufPrint(&wave_path_buf, "{s}/SPD-SX/WAVE/PRM/{d:0>2}/{d:0>2}.spd", .{ actual_path, folder, file }) catch continue;

            if (pathExists(wave_path)) {
                const wave_id: u32 = @intCast(folder * 100 + file);
                const wave = xml.parseWaveFile(app.allocator, wave_path, wave_id) catch continue;
                try app.data_store.waves.insert(wave);
                wave_count += 1;
            }
        }
    }

    // Load tag list
    var tag_path_buf: [512]u8 = undefined;
    const tag_path = std.fmt.bufPrint(&tag_path_buf, "{s}/SPD-SX/SYSTEM/tag_list.spd", .{actual_path}) catch "";
    if (pathExists(tag_path)) {
        var tags = xml.parseTagListFile(app.allocator, tag_path) catch std.ArrayListUnmanaged(TagListEntry){};
        defer tags.deinit(app.allocator);
        for (tags.items) |tag| {
            try app.data_store.tags.insert(tag);
        }
    }

    // Load kit chains
    var chain_path_buf: [512]u8 = undefined;
    const chain_path = std.fmt.bufPrint(&chain_path_buf, "{s}/SPD-SX/SYSTEM/sysparam.spd", .{actual_path}) catch "";
    if (pathExists(chain_path)) {
        var chains = xml.parseKitChainFile(app.allocator, chain_path) catch std.ArrayListUnmanaged(KitChain){};
        defer chains.deinit(app.allocator);
        for (chains.items) |chain| {
            try app.data_store.kit_chains.insert(chain);
        }
    }

    // Store loaded path
    if (app.loaded_path) |old_path| {
        app.allocator.free(old_path);
    }
    app.loaded_path = try app.allocator.dupe(u8, path);

    try stdout.print("Loaded {d} kits, {d} waves, {d} tags, {d} kit chains\n", .{
        kit_count,
        wave_count,
        app.data_store.tags.size(),
        app.data_store.kit_chains.size(),
    });
}

/// Check if path exists
fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// List all kits
fn listKits(app: *App) !void {
    const stdout = getStdOutWriter();
    const kits = app.data_store.kits.getAll();

    if (kits.len == 0) {
        try stdout.writeAll("No kits loaded. Use 'load <path>' to load configuration.\n");
        return;
    }

    try stdout.print("Kits ({d} total):\n", .{kits.len});
    try stdout.writeAll("─────────────────────────────────────────\n");
    try stdout.writeAll(" #   Name             Level  Tempo\n");
    try stdout.writeAll("─────────────────────────────────────────\n");

    for (kits, 0..) |*kit, i| {
        const name = kit.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        // Pad name to 16 characters
        var name_buf: [16]u8 = [_]u8{' '} ** 16;
        const copy_len = @min(name.len, 16);
        @memcpy(name_buf[0..copy_len], name[0..copy_len]);

        const tempo_f: f64 = @as(f64, @floatFromInt(kit.tempo)) / 10.0;

        try stdout.print("{d:>3}  {s}  {d:>5}  {d:>6.1}\n", .{
            i,
            &name_buf,
            kit.level,
            tempo_f,
        });
    }
}

/// List all waves
fn listWaves(app: *App) !void {
    const stdout = getStdOutWriter();
    const waves = app.data_store.waves.getAll();

    if (waves.len == 0) {
        try stdout.writeAll("No waves loaded. Use 'load <path>' to load configuration.\n");
        return;
    }

    try stdout.print("Waves ({d} total):\n", .{waves.len});
    try stdout.writeAll("───────────────────────────────────────────────\n");
    try stdout.writeAll("  ID   Name              Tag  Path\n");
    try stdout.writeAll("───────────────────────────────────────────────\n");

    for (waves) |*wave| {
        const name = wave.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        var name_buf: [16]u8 = [_]u8{' '} ** 16;
        const copy_len = @min(name.len, 16);
        @memcpy(name_buf[0..copy_len], name[0..copy_len]);

        const path = wave.getPath();
        const display_path = if (path.len > 20) path[path.len - 20 ..] else path;

        try stdout.print("{d:>4}  {s}  {d:>3}  {s}\n", .{
            wave.wave_id,
            &name_buf,
            wave.tag,
            display_path,
        });
    }
}

/// List all tags
fn listTags(app: *App) !void {
    const stdout = getStdOutWriter();
    const tags = app.data_store.tags.getAll();

    if (tags.len == 0) {
        try stdout.writeAll("No tags loaded.\n");
        return;
    }

    try stdout.print("Tags ({d} total):\n", .{tags.len});
    try stdout.writeAll("───────────────────────────\n");
    try stdout.writeAll("  #   Name          Order\n");
    try stdout.writeAll("───────────────────────────\n");

    for (tags, 0..) |*tag, i| {
        const name = tag.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        try stdout.print("{d:>3}  {s:<12}  {d:>3}\n", .{
            i,
            name,
            tag.order,
        });
    }
}

/// List all kit chains
fn listChains(app: *App) !void {
    const stdout = getStdOutWriter();
    const chains = app.data_store.kit_chains.getAll();

    if (chains.len == 0) {
        try stdout.writeAll("No kit chains loaded.\n");
        return;
    }

    try stdout.print("Kit Chains ({d} total):\n", .{chains.len});
    try stdout.writeAll("─────────────────────────────────────────────────\n");

    for (chains, 0..) |*chain, i| {
        const name = chain.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        try stdout.print("{d:>3}  {s}: ", .{ i, name });

        // Print steps
        for (chain.steps) |step| {
            if (step == -1) break;
            try stdout.print("{d} ", .{step});
        }
        try stdout.writeAll("\n");
    }
}

/// Show kit details
fn showKit(app: *App, index: usize) !void {
    const stdout = getStdOutWriter();

    if (app.data_store.kits.get(index)) |kit| {
        const name = kit.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        const sub_name = kit.getSubName(app.allocator) catch "";
        defer if (sub_name.len > 0) app.allocator.free(sub_name);

        const tempo_f: f64 = @as(f64, @floatFromInt(kit.tempo)) / 10.0;

        try stdout.print(
            \\Kit {d}: {s}
            \\════════════════════════════════════════════════
            \\  Sub-name:    {s}
            \\  Level:       {d}
            \\  Tempo:       {d:.1} BPM
            \\  FX1:         {s} (Type: {d})
            \\  FX2:         {s} (Type: {d})
            \\  FX2 Assign:  {d}
            \\  Link Pads:   {d}, {d}
            \\
            \\Pads:
            \\────────────────────────────────────────────────
            \\  #   Wave     Level  Pan      MIDI Ch  Note
            \\────────────────────────────────────────────────
            \\
        , .{
            index,
            name,
            sub_name,
            kit.level,
            tempo_f,
            if (kit.fx1_sw == 1) "ON" else "OFF",
            kit.fx1_type,
            if (kit.fx2_sw == 1) "ON" else "OFF",
            kit.fx2_type,
            kit.fx2_asgn,
            kit.link_pad0,
            kit.link_pad1,
        });

        for (kit.pads, 0..) |pad, i| {
            const pan_text = encoding.getPanText(pad.wv_pan);
            const midi_ch_text = types.Pad.getMidiChText(pad.pad_midi_ch);

            try stdout.print("{d:>3}  {d:>6}  {d:>5}  {s:<7}  {s:<7}  {d}\n", .{
                i + 1,
                pad.wv,
                pad.wv_level,
                pan_text,
                midi_ch_text,
                pad.note_num,
            });
        }
    } else {
        try stdout.print("Kit {d} not found.\n", .{index});
    }
}

/// Show wave details
fn showWave(app: *App, index: usize) !void {
    const stdout = getStdOutWriter();

    if (app.data_store.waves.get(index)) |wave| {
        const name = wave.getName(app.allocator) catch "[error]";
        defer if (!std.mem.eql(u8, name, "[error]")) app.allocator.free(name);

        try stdout.print(
            \\Wave {d}: {s}
            \\════════════════════════════════════════════════
            \\  Wave ID:    {d}
            \\  Path:       {s}
            \\  Tag:        {d}
            \\  Tempo:      {d}
            \\  Beat:       {d}
            \\  Measure:    {d}
            \\  Start:      {d}
            \\  End:        {d}
            \\
        , .{
            index,
            name,
            wave.wave_id,
            wave.getPath(),
            wave.tag,
            wave.tempo,
            wave.beat,
            wave.measure,
            wave.start,
            wave.end,
        });
    } else {
        try stdout.print("Wave {d} not found.\n", .{index});
    }
}

/// Rename a kit
fn renameKit(app: *App, index: usize, new_name: []const u8) !void {
    const stdout = getStdOutWriter();

    if (app.data_store.kits.getMut(index)) |kit| {
        kit.setName(new_name);
        try stdout.print("Kit {d} renamed to: {s}\n", .{ index, new_name });
    } else {
        try stdout.print("Kit {d} not found.\n", .{index});
    }
}

/// Rename a wave
fn renameWave(app: *App, index: usize, new_name: []const u8) !void {
    const stdout = getStdOutWriter();

    if (app.data_store.waves.getMut(index)) |wave| {
        wave.setName(new_name);
        wave.modified = true;
        try stdout.print("Wave {d} renamed to: {s}\n", .{ index, new_name });
    } else {
        try stdout.print("Wave {d} not found.\n", .{index});
    }
}

/// Create a new kit
fn createKit(app: *App) !void {
    const stdout = getStdOutWriter();

    var kit = Kit.init();
    kit.kit_id = @intCast(app.data_store.kits.size());
    try app.data_store.kits.insert(kit);

    try stdout.print("Created new kit at index {d}\n", .{kit.kit_id});
}

/// Delete a kit
fn deleteKit(app: *App, index: usize) !void {
    const stdout = getStdOutWriter();

    if (index < app.data_store.kits.size()) {
        app.data_store.kits.delete(index);
        app.data_store.kit_chains.updateKitReferences(&app.data_store.kits);
        try stdout.print("Deleted kit {d}\n", .{index});
    } else {
        try stdout.print("Kit {d} not found.\n", .{index});
    }
}

/// Swap two kits
fn swapKits(app: *App, idx_a: usize, idx_b: usize) !void {
    const stdout = getStdOutWriter();

    if (idx_a < app.data_store.kits.size() and idx_b < app.data_store.kits.size()) {
        app.data_store.kits.swap(idx_a, idx_b);
        app.data_store.kit_chains.updateKitReferences(&app.data_store.kits);
        try stdout.print("Swapped kits {d} and {d}\n", .{ idx_a, idx_b });
    } else {
        try stdout.writeAll("Invalid kit indices.\n");
    }
}

/// Save configuration
fn saveConfiguration(app: *App, path: []const u8) !void {
    const stdout = getStdOutWriter();

    try stdout.print("Saving configuration to: {s}\n", .{path});
    try xml_writer.exportConfiguration(&app.data_store, path, app.allocator);
    try stdout.writeAll("Configuration saved successfully.\n");
}

/// Buffered writer for stdout
const StdOutWriter = std.io.GenericWriter(*OutputContext, anyerror, writeToStdout);
const StdErrWriter = std.io.GenericWriter(*OutputContext, anyerror, writeToStderr);

const OutputContext = struct {
    dummy: u8 = 0,
};

fn writeToStdout(_: *OutputContext, bytes: []const u8) anyerror!usize {
    const stdout_handle: std.posix.fd_t = std.posix.STDOUT_FILENO;
    return std.posix.write(stdout_handle, bytes);
}

fn writeToStderr(_: *OutputContext, bytes: []const u8) anyerror!usize {
    const stderr_handle: std.posix.fd_t = std.posix.STDERR_FILENO;
    return std.posix.write(stderr_handle, bytes);
}

var stdout_context = OutputContext{};
var stderr_context = OutputContext{};

fn getStdOutWriter() StdOutWriter {
    return .{ .context = &stdout_context };
}

fn getStdErrWriter() StdErrWriter {
    return .{ .context = &stderr_context };
}

/// Main entry point
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = getStdOutWriter();
    const stderr = getStdErrWriter();

    var app = App.init(allocator);
    defer app.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage(stdout);
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        try printUsage(stdout);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "-v") or std.mem.eql(u8, command, "--version")) {
        try printVersion(stdout);
    } else if (std.mem.eql(u8, command, "load")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'load' requires a path argument.\n");
            return;
        }
        loadConfiguration(&app, args[2]) catch |err| {
            try stderr.print("Error loading configuration: {}\n", .{err});
        };
    } else if (std.mem.eql(u8, command, "save")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'save' requires a path argument.\n");
            return;
        }
        saveConfiguration(&app, args[2]) catch |err| {
            try stderr.print("Error saving configuration: {}\n", .{err});
        };
    } else if (std.mem.eql(u8, command, "list-kits")) {
        try listKits(&app);
    } else if (std.mem.eql(u8, command, "list-waves")) {
        try listWaves(&app);
    } else if (std.mem.eql(u8, command, "list-tags")) {
        try listTags(&app);
    } else if (std.mem.eql(u8, command, "list-chains")) {
        try listChains(&app);
    } else if (std.mem.eql(u8, command, "show-kit")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'show-kit' requires an index argument.\n");
            return;
        }
        const index = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid kit index.\n");
            return;
        };
        try showKit(&app, index);
    } else if (std.mem.eql(u8, command, "show-wave")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'show-wave' requires an index argument.\n");
            return;
        }
        const index = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid wave index.\n");
            return;
        };
        try showWave(&app, index);
    } else if (std.mem.eql(u8, command, "rename-kit")) {
        if (args.len < 4) {
            try stderr.writeAll("Error: 'rename-kit' requires index and name arguments.\n");
            return;
        }
        const index = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid kit index.\n");
            return;
        };
        try renameKit(&app, index, args[3]);
    } else if (std.mem.eql(u8, command, "rename-wave")) {
        if (args.len < 4) {
            try stderr.writeAll("Error: 'rename-wave' requires index and name arguments.\n");
            return;
        }
        const index = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid wave index.\n");
            return;
        };
        try renameWave(&app, index, args[3]);
    } else if (std.mem.eql(u8, command, "create-kit")) {
        try createKit(&app);
    } else if (std.mem.eql(u8, command, "delete-kit")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'delete-kit' requires an index argument.\n");
            return;
        }
        const index = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid kit index.\n");
            return;
        };
        try deleteKit(&app, index);
    } else if (std.mem.eql(u8, command, "swap-kits")) {
        if (args.len < 4) {
            try stderr.writeAll("Error: 'swap-kits' requires two index arguments.\n");
            return;
        }
        const idx_a = std.fmt.parseInt(usize, args[2], 10) catch {
            try stderr.writeAll("Error: Invalid first kit index.\n");
            return;
        };
        const idx_b = std.fmt.parseInt(usize, args[3], 10) catch {
            try stderr.writeAll("Error: Invalid second kit index.\n");
            return;
        };
        try swapKits(&app, idx_a, idx_b);
    } else if (std.mem.eql(u8, command, "export")) {
        if (args.len < 3) {
            try stderr.writeAll("Error: 'export' requires a path argument.\n");
            return;
        }
        saveConfiguration(&app, args[2]) catch |err| {
            try stderr.print("Error exporting configuration: {}\n", .{err});
        };
    } else {
        try stderr.print("Unknown command: {s}\n", .{command});
        try stderr.writeAll("Use 'spd-sx-editor help' for usage information.\n");
    }
}

// Unit tests
test "types module" {
    _ = types;
}

test "encoding module" {
    _ = encoding;
}

test "storage module" {
    _ = storage;
}

test "xml module" {
    _ = xml;
}
