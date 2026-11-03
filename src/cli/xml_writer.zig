const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const storage = @import("storage.zig");

const Kit = types.Kit;
const Pad = types.Pad;
const Wave = types.Wave;
const TagListEntry = types.TagListEntry;
const KitChain = types.KitChain;

/// Write errors
pub const WriteError = error{
    WriteError,
    CreateError,
} || Allocator.Error || std.Io.File.OpenError || std.Io.Writer.Error;

/// XML Writer helper
pub const XmlWriter = struct {
    out: *std.Io.Writer,
    indent_level: usize = 0,

    pub fn init(out: *std.Io.Writer) XmlWriter {
        return .{ .out = out };
    }

    pub fn flush(self: *XmlWriter) WriteError!void {
        try self.out.flush();
    }

    fn writeBytes(self: *XmlWriter, bytes: []const u8) !void {
        try self.out.writeAll(bytes);
    }

    fn writeIndent(self: *XmlWriter) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.writeBytes("\t");
        }
    }

    pub fn openTag(self: *XmlWriter, name: []const u8) !void {
        try self.writeIndent();
        try self.writeBytes("<");
        try self.writeBytes(name);
        try self.writeBytes(">\r\n");
        self.indent_level += 1;
    }

    pub fn closeTag(self: *XmlWriter, name: []const u8) !void {
        self.indent_level -= 1;
        try self.writeIndent();
        try self.writeBytes("</");
        try self.writeBytes(name);
        try self.writeBytes(">\r\n");
    }

    pub fn writeElement(self: *XmlWriter, name: []const u8, value: []const u8) !void {
        try self.writeIndent();
        try self.writeBytes("<");
        try self.writeBytes(name);
        try self.writeBytes(">");
        try self.writeBytes(value);
        try self.writeBytes("</");
        try self.writeBytes(name);
        try self.writeBytes(">\r\n");
    }

    pub fn writeIntElement(self: *XmlWriter, name: []const u8, value: anytype) !void {
        var buf: [32]u8 = undefined;
        const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return error.WriteError;
        try self.writeElement(name, str);
    }
};

/// Write a kit to a .spd file
pub fn writeKitFile(io: std.Io, kit: *const Kit, file_path: []const u8) !void {
    const file = try std.Io.Dir.createFileAbsolute(io, file_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(file, io, &write_buf);
    var writer = XmlWriter.init(&file_writer.interface);
    try writeKit(&writer, kit);
    try writer.flush();
}

/// Write kit data using XmlWriter
fn writeKit(writer: *XmlWriter, kit: *const Kit) !void {
    try writer.openTag("KitPrm");

    try writer.writeIntElement("Level", kit.level);
    try writer.writeIntElement("Tempo", kit.tempo);

    // Write name
    try writer.writeIntElement("Nm0", kit.nm[0]);
    try writer.writeIntElement("Nm1", kit.nm[1]);
    try writer.writeIntElement("Nm2", kit.nm[2]);
    try writer.writeIntElement("Nm3", kit.nm[3]);
    try writer.writeIntElement("Nm4", kit.nm[4]);
    try writer.writeIntElement("Nm5", kit.nm[5]);
    try writer.writeIntElement("Nm6", kit.nm[6]);
    try writer.writeIntElement("Nm7", kit.nm[7]);

    // Write sub-name
    try writer.writeIntElement("SubNm0", kit.sub_nm[0]);
    try writer.writeIntElement("SubNm1", kit.sub_nm[1]);
    try writer.writeIntElement("SubNm2", kit.sub_nm[2]);
    try writer.writeIntElement("SubNm3", kit.sub_nm[3]);
    try writer.writeIntElement("SubNm4", kit.sub_nm[4]);
    try writer.writeIntElement("SubNm5", kit.sub_nm[5]);
    try writer.writeIntElement("SubNm6", kit.sub_nm[6]);
    try writer.writeIntElement("SubNm7", kit.sub_nm[7]);
    try writer.writeIntElement("SubNm8", kit.sub_nm[8]);
    try writer.writeIntElement("SubNm9", kit.sub_nm[9]);
    try writer.writeIntElement("SubNm10", kit.sub_nm[10]);
    try writer.writeIntElement("SubNm11", kit.sub_nm[11]);
    try writer.writeIntElement("SubNm12", kit.sub_nm[12]);
    try writer.writeIntElement("SubNm13", kit.sub_nm[13]);
    try writer.writeIntElement("SubNm14", kit.sub_nm[14]);
    try writer.writeIntElement("SubNm15", kit.sub_nm[15]);

    // Write FX settings
    try writer.writeIntElement("Fx2Asgn", kit.fx2_asgn);
    try writer.writeIntElement("LinkPad0", kit.link_pad0);
    try writer.writeIntElement("LinkPad1", kit.link_pad1);
    try writer.writeIntElement("Fx1Sw", kit.fx1_sw);
    try writer.writeIntElement("Fx1Type", kit.fx1_type);

    // Write FX1 parameters
    try writer.writeIntElement("Fx1Prm0", kit.fx1_prm[0]);
    try writer.writeIntElement("Fx1Prm1", kit.fx1_prm[1]);
    try writer.writeIntElement("Fx1Prm2", kit.fx1_prm[2]);
    try writer.writeIntElement("Fx1Prm3", kit.fx1_prm[3]);
    try writer.writeIntElement("Fx1Prm4", kit.fx1_prm[4]);
    try writer.writeIntElement("Fx1Prm5", kit.fx1_prm[5]);
    try writer.writeIntElement("Fx1Prm6", kit.fx1_prm[6]);
    try writer.writeIntElement("Fx1Prm7", kit.fx1_prm[7]);
    try writer.writeIntElement("Fx1Prm8", kit.fx1_prm[8]);
    try writer.writeIntElement("Fx1Prm9", kit.fx1_prm[9]);
    try writer.writeIntElement("Fx1Prm10", kit.fx1_prm[10]);
    try writer.writeIntElement("Fx1Prm11", kit.fx1_prm[11]);
    try writer.writeIntElement("Fx1Prm12", kit.fx1_prm[12]);
    try writer.writeIntElement("Fx1Prm13", kit.fx1_prm[13]);
    try writer.writeIntElement("Fx1Prm14", kit.fx1_prm[14]);
    try writer.writeIntElement("Fx1Prm15", kit.fx1_prm[15]);
    try writer.writeIntElement("Fx1Prm16", kit.fx1_prm[16]);
    try writer.writeIntElement("Fx1Prm17", kit.fx1_prm[17]);
    try writer.writeIntElement("Fx1Prm18", kit.fx1_prm[18]);
    try writer.writeIntElement("Fx1Prm19", kit.fx1_prm[19]);

    try writer.writeIntElement("Fx2Sw", kit.fx2_sw);
    try writer.writeIntElement("Fx2Type", kit.fx2_type);

    // Write FX2 parameters
    try writer.writeIntElement("Fx2Prm0", kit.fx2_prm[0]);
    try writer.writeIntElement("Fx2Prm1", kit.fx2_prm[1]);
    try writer.writeIntElement("Fx2Prm2", kit.fx2_prm[2]);
    try writer.writeIntElement("Fx2Prm3", kit.fx2_prm[3]);
    try writer.writeIntElement("Fx2Prm4", kit.fx2_prm[4]);
    try writer.writeIntElement("Fx2Prm5", kit.fx2_prm[5]);
    try writer.writeIntElement("Fx2Prm6", kit.fx2_prm[6]);
    try writer.writeIntElement("Fx2Prm7", kit.fx2_prm[7]);
    try writer.writeIntElement("Fx2Prm8", kit.fx2_prm[8]);
    try writer.writeIntElement("Fx2Prm9", kit.fx2_prm[9]);
    try writer.writeIntElement("Fx2Prm10", kit.fx2_prm[10]);
    try writer.writeIntElement("Fx2Prm11", kit.fx2_prm[11]);
    try writer.writeIntElement("Fx2Prm12", kit.fx2_prm[12]);
    try writer.writeIntElement("Fx2Prm13", kit.fx2_prm[13]);
    try writer.writeIntElement("Fx2Prm14", kit.fx2_prm[14]);
    try writer.writeIntElement("Fx2Prm15", kit.fx2_prm[15]);
    try writer.writeIntElement("Fx2Prm16", kit.fx2_prm[16]);
    try writer.writeIntElement("Fx2Prm17", kit.fx2_prm[17]);
    try writer.writeIntElement("Fx2Prm18", kit.fx2_prm[18]);
    try writer.writeIntElement("Fx2Prm19", kit.fx2_prm[19]);

    // Write pads
    for (&kit.pads) |*pad| {
        try writePad(writer, pad);
    }

    try writer.closeTag("KitPrm");
}

/// Write pad data using XmlWriter
fn writePad(writer: *XmlWriter, pad: *const Pad) !void {
    try writer.openTag("PadPrm");

    try writer.writeIntElement("Wv", pad.wv);
    try writer.writeIntElement("WvLevel", pad.wv_level);
    try writer.writeIntElement("WvPan", pad.wv_pan);
    try writer.writeIntElement("PlayMode", pad.play_mode);
    try writer.writeIntElement("OutAsgn", pad.out_asgn);
    try writer.writeIntElement("MuteGrp", pad.mute_grp);
    try writer.writeIntElement("TempoSync", pad.tempo_sync);
    try writer.writeIntElement("PadMidiCh", pad.pad_midi_ch);
    try writer.writeIntElement("NoteNum", pad.note_num);
    try writer.writeIntElement("MidiCtrl", pad.midi_ctrl);
    try writer.writeIntElement("Loop", pad.loop);
    try writer.writeIntElement("TrigType", pad.trig_type);
    try writer.writeIntElement("GateTime", pad.gate_time);
    try writer.writeIntElement("Dynamics", pad.dynamics);
    try writer.writeIntElement("VoiceAsgn", pad.voice_asgn);
    try writer.writeIntElement("Reverse", pad.reverse);
    try writer.writeIntElement("SubWv", pad.sub_wv);
    try writer.writeIntElement("SubWvLevel", pad.sub_wv_level);
    try writer.writeIntElement("SubWvPan", pad.sub_wv_pan);

    try writer.closeTag("PadPrm");
}

/// Write a wave to a .spd file
pub fn writeWaveFile(io: std.Io, wave: *const Wave, file_path: []const u8) !void {
    const file = try std.Io.Dir.createFileAbsolute(io, file_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(file, io, &write_buf);
    var writer = XmlWriter.init(&file_writer.interface);
    try writeWave(&writer, wave);
    try writer.flush();
}

/// Write wave data using XmlWriter
fn writeWave(writer: *XmlWriter, wave: *const Wave) !void {
    try writer.openTag("WvPrm");

    // Write name
    try writer.writeIntElement("Nm0", wave.nm[0]);
    try writer.writeIntElement("Nm1", wave.nm[1]);
    try writer.writeIntElement("Nm2", wave.nm[2]);
    try writer.writeIntElement("Nm3", wave.nm[3]);
    try writer.writeIntElement("Nm4", wave.nm[4]);
    try writer.writeIntElement("Nm5", wave.nm[5]);
    try writer.writeIntElement("Nm6", wave.nm[6]);
    try writer.writeIntElement("Nm7", wave.nm[7]);
    try writer.writeIntElement("Nm8", wave.nm[8]);
    try writer.writeIntElement("Nm9", wave.nm[9]);
    try writer.writeIntElement("Nm10", wave.nm[10]);
    try writer.writeIntElement("Nm11", wave.nm[11]);

    try writer.writeElement("Path", wave.getPath());
    try writer.writeIntElement("Tag", wave.tag);
    try writer.writeIntElement("Tempo", wave.tempo);
    try writer.writeIntElement("Beat", wave.beat);
    try writer.writeIntElement("Measure", wave.measure);
    try writer.writeIntElement("Start", wave.start);
    try writer.writeIntElement("End", wave.end);

    try writer.closeTag("WvPrm");
}

/// Write tag list to tag_list.spd
pub fn writeTagListFile(io: std.Io, tags: []const TagListEntry, file_path: []const u8) !void {
    const file = try std.Io.Dir.createFileAbsolute(io, file_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(file, io, &write_buf);
    var writer = XmlWriter.init(&file_writer.interface);

    try writer.openTag("TagList");

    for (tags) |*tag| {
        try writer.openTag("TagPrm");

        try writer.writeIntElement("Nm0", tag.nm[0]);
        try writer.writeIntElement("Nm1", tag.nm[1]);
        try writer.writeIntElement("Nm2", tag.nm[2]);
        try writer.writeIntElement("Nm3", tag.nm[3]);
        try writer.writeIntElement("Nm4", tag.nm[4]);
        try writer.writeIntElement("Nm5", tag.nm[5]);
        try writer.writeIntElement("Nm6", tag.nm[6]);
        try writer.writeIntElement("Nm7", tag.nm[7]);
        try writer.writeIntElement("Nm8", tag.nm[8]);
        try writer.writeIntElement("Nm9", tag.nm[9]);
        try writer.writeIntElement("Nm10", tag.nm[10]);
        try writer.writeIntElement("Nm11", tag.nm[11]);
        try writer.writeIntElement("Order", tag.order);

        try writer.closeTag("TagPrm");
    }

    try writer.closeTag("TagList");
    try writer.flush();
}

const xml = @import("xml.zig");

const kit_chain_open = "<KitChainPrm>";
const kit_chain_close = "</KitChainPrm>";

/// Replace only the KitChainPrm section, preserving SetupPrm, MEfctPrm, etc.
pub fn replaceKitChainPrmSection(allocator: Allocator, existing: []const u8, new_section: []const u8) ![]u8 {
    const start = std.mem.indexOf(u8, existing, kit_chain_open) orelse {
        return try allocator.dupe(u8, new_section);
    };
    const tail = existing[start..];
    const close_rel = std.mem.indexOf(u8, tail, kit_chain_close) orelse {
        return try allocator.dupe(u8, new_section);
    };
    const end = start + close_rel + kit_chain_close.len;

    const merged = try std.mem.concat(allocator, u8, &.{ existing[0..start], new_section, existing[end..] });
    return merged;
}

fn writeKitChainPrm(writer: *XmlWriter, chains: []const KitChain) !void {
    try writer.openTag("KitChainPrm");

    for (chains) |*chain| {
        try writer.openTag("KitChain");

        try writer.writeIntElement("Nm0", chain.nm[0]);
        try writer.writeIntElement("Nm1", chain.nm[1]);
        try writer.writeIntElement("Nm2", chain.nm[2]);
        try writer.writeIntElement("Nm3", chain.nm[3]);
        try writer.writeIntElement("Nm4", chain.nm[4]);
        try writer.writeIntElement("Nm5", chain.nm[5]);
        try writer.writeIntElement("Nm6", chain.nm[6]);
        try writer.writeIntElement("Nm7", chain.nm[7]);
        try writer.writeIntElement("Nm8", chain.nm[8]);
        try writer.writeIntElement("Nm9", chain.nm[9]);

        try writer.writeIntElement("Stp0", chain.steps[0]);
        try writer.writeIntElement("Stp1", chain.steps[1]);
        try writer.writeIntElement("Stp2", chain.steps[2]);
        try writer.writeIntElement("Stp3", chain.steps[3]);
        try writer.writeIntElement("Stp4", chain.steps[4]);
        try writer.writeIntElement("Stp5", chain.steps[5]);
        try writer.writeIntElement("Stp6", chain.steps[6]);
        try writer.writeIntElement("Stp7", chain.steps[7]);
        try writer.writeIntElement("Stp8", chain.steps[8]);
        try writer.writeIntElement("Stp9", chain.steps[9]);
        try writer.writeIntElement("Stp10", chain.steps[10]);
        try writer.writeIntElement("Stp11", chain.steps[11]);
        try writer.writeIntElement("Stp12", chain.steps[12]);
        try writer.writeIntElement("Stp13", chain.steps[13]);
        try writer.writeIntElement("Stp14", chain.steps[14]);
        try writer.writeIntElement("Stp15", chain.steps[15]);
        try writer.writeIntElement("Stp16", chain.steps[16]);
        try writer.writeIntElement("Stp17", chain.steps[17]);
        try writer.writeIntElement("Stp18", chain.steps[18]);
        try writer.writeIntElement("Stp19", chain.steps[19]);

        try writer.closeTag("KitChain");
    }

    try writer.closeTag("KitChainPrm");
}

/// Format KitChainPrm XML into an allocated buffer.
pub fn formatKitChainPrm(allocator: Allocator, chains: []const KitChain) ![]u8 {
    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();

    var writer = XmlWriter.init(&allocating.writer);
    try writeKitChainPrm(&writer, chains);
    return allocating.toOwnedSlice();
}

fn writeFileContents(io: std.Io, file_path: []const u8, data: []const u8) !void {
    const file = try std.Io.Dir.createFileAbsolute(io, file_path, .{});
    defer file.close(io);

    var write_buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.Writer.init(file, io, &write_buf);
    try file_writer.interface.writeAll(data);
    try file_writer.interface.flush();
}

/// Write kit chains to sysparam.spd, preserving other top-level sections when present.
pub fn writeKitChainFile(allocator: Allocator, io: std.Io, chains: []const KitChain, file_path: []const u8) !void {
    const new_section = try formatKitChainPrm(allocator, chains);
    defer allocator.free(new_section);

    const merged = blk: {
        const existing = xml.readFileContents(allocator, io, file_path, 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => break :blk try allocator.dupe(u8, new_section),
            else => return err,
        };
        defer allocator.free(existing);
        break :blk try replaceKitChainPrmSection(allocator, existing, new_section);
    };
    defer allocator.free(merged);

    try writeFileContents(io, file_path, merged);
}

/// Export entire configuration to SPD-SX directory structure
pub fn exportConfiguration(io: std.Io, data_store: *const storage.DataStore, base_path: []const u8, allocator: Allocator) !void {
    // Create directory structure
    const kit_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/KIT", .{base_path});
    defer allocator.free(kit_dir);

    const system_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/SYSTEM", .{base_path});
    defer allocator.free(system_dir);

    std.Io.Dir.createDirPath(.cwd(), io, kit_dir) catch {};
    std.Io.Dir.createDirPath(.cwd(), io, system_dir) catch {};

    // Write kits
    for (data_store.kits.getAll(), 0..) |*kit, i| {
        var filename_buf: [512]u8 = undefined;
        const filename = try std.fmt.bufPrint(&filename_buf, "{s}/kit{d:0>3}.spd", .{ kit_dir, i });
        try writeKitFile(io, kit, filename);
    }

    // Write waves
    for (data_store.waves.getAll()) |*wave| {
        const wave_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/WAVE/PRM/{d:0>2}", .{ base_path, wave.wave_id / 100 });
        defer allocator.free(wave_dir);

        std.Io.Dir.createDirPath(.cwd(), io, wave_dir) catch {};

        var filename_buf: [512]u8 = undefined;
        const filename = try std.fmt.bufPrint(&filename_buf, "{s}/{d:0>2}.spd", .{ wave_dir, wave.wave_id % 100 });
        try writeWaveFile(io, wave, filename);
    }

    // Write tag list
    const tag_file = try std.fmt.allocPrint(allocator, "{s}/tag_list.spd", .{system_dir});
    defer allocator.free(tag_file);
    try writeTagListFile(io, data_store.tags.getAll(), tag_file);

    // Write kit chains
    const chain_file = try std.fmt.allocPrint(allocator, "{s}/sysparam.spd", .{system_dir});
    defer allocator.free(chain_file);
    try writeKitChainFile(allocator, io, data_store.kit_chains.getAll(), chain_file);
}

test "replaceKitChainPrmSection preserves surrounding sysparam content" {
    const allocator = std.testing.allocator;
    const existing =
        \\<SetupPrm>
        \\<StartupKit>5</StartupKit>
        \\</SetupPrm>
        \\<KitChainPrm>
        \\<KitChain><Stp0>1</Stp0></KitChain>
        \\</KitChainPrm>
        \\<MEfctPrm></MEfctPrm>
    ;
    const new_section =
        \\<KitChainPrm>
        \\<KitChain><Stp0>2</Stp0></KitChain>
        \\</KitChainPrm>
    ;

    const merged = try replaceKitChainPrmSection(allocator, existing, new_section);
    defer allocator.free(merged);

    try std.testing.expect(std.mem.startsWith(u8, merged, "<SetupPrm>"));
    try std.testing.expect(std.mem.indexOf(u8, merged, "<StartupKit>5</StartupKit>") != null);
    try std.testing.expect(std.mem.indexOf(u8, merged, "<Stp0>2</Stp0>") != null);
    try std.testing.expect(std.mem.indexOf(u8, merged, "<MEfctPrm>") != null);
    try std.testing.expect(std.mem.indexOf(u8, merged, "<Stp0>1</Stp0>") == null);
}

test "writeKitFile persists non-empty kit XML" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const base_path = try tmp_dir.dir.realPathFileAlloc(io, ".", std.testing.allocator);
    defer std.testing.allocator.free(base_path);

    const kit_file_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/kit000.spd", .{base_path});
    defer std.testing.allocator.free(kit_file_path);

    var kit = Kit.init();
    kit.level = 100;
    kit.tempo = 1200;

    try writeKitFile(io, &kit, kit_file_path);

    const parsed = try xml.parseKitFile(std.testing.allocator, io, kit_file_path);
    try std.testing.expectEqual(@as(u8, 100), parsed.level);
    try std.testing.expectEqual(@as(u16, 1200), parsed.tempo);
}
