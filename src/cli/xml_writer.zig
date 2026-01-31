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
} || Allocator.Error || std.fs.File.OpenError || std.posix.WriteError;

/// XML Writer helper
pub const XmlWriter = struct {
    file: std.fs.File,
    indent_level: usize = 0,

    pub fn init(file: std.fs.File) XmlWriter {
        return .{ .file = file };
    }

    fn writeBytes(self: *XmlWriter, bytes: []const u8) !void {
        _ = try std.posix.write(self.file.handle, bytes);
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
pub fn writeKitFile(kit: *const Kit, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var writer = XmlWriter.init(file);
    try writeKit(&writer, kit);
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
pub fn writeWaveFile(wave: *const Wave, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var writer = XmlWriter.init(file);
    try writeWave(&writer, wave);
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
pub fn writeTagListFile(tags: []const TagListEntry, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var writer = XmlWriter.init(file);

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
}

/// Write kit chains to sysparam.spd
pub fn writeKitChainFile(chains: []const KitChain, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var writer = XmlWriter.init(file);

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

/// Export entire configuration to SPD-SX directory structure
pub fn exportConfiguration(data_store: *const storage.DataStore, base_path: []const u8, allocator: Allocator) !void {
    // Create directory structure
    const kit_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/KIT", .{base_path});
    defer allocator.free(kit_dir);

    const system_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/SYSTEM", .{base_path});
    defer allocator.free(system_dir);

    std.fs.cwd().makePath(kit_dir) catch {};
    std.fs.cwd().makePath(system_dir) catch {};

    // Write kits
    for (data_store.kits.getAll(), 0..) |*kit, i| {
        var filename_buf: [512]u8 = undefined;
        const filename = std.fmt.bufPrint(&filename_buf, "{s}/kit{d:0>3}.spd", .{ kit_dir, i }) catch continue;
        writeKitFile(kit, filename) catch |err| {
            std.debug.print("Error writing kit {d}: {}\n", .{ i, err });
        };
    }

    // Write waves
    for (data_store.waves.getAll()) |*wave| {
        const wave_dir = try std.fmt.allocPrint(allocator, "{s}/SPD-SX/WAVE/PRM/{d:0>2}", .{ base_path, wave.wave_id / 100 });
        defer allocator.free(wave_dir);

        std.fs.cwd().makePath(wave_dir) catch {};

        var filename_buf: [512]u8 = undefined;
        const filename = std.fmt.bufPrint(&filename_buf, "{s}/{d:0>2}.spd", .{ wave_dir, wave.wave_id % 100 }) catch continue;
        writeWaveFile(wave, filename) catch |err| {
            std.debug.print("Error writing wave {d}: {}\n", .{ wave.wave_id, err });
        };
    }

    // Write tag list
    const tag_file = try std.fmt.allocPrint(allocator, "{s}/tag_list.spd", .{system_dir});
    defer allocator.free(tag_file);
    writeTagListFile(data_store.tags.getAll(), tag_file) catch |err| {
        std.debug.print("Error writing tag list: {}\n", .{err});
    };

    // Write kit chains
    const chain_file = try std.fmt.allocPrint(allocator, "{s}/sysparam.spd", .{system_dir});
    defer allocator.free(chain_file);
    writeKitChainFile(data_store.kit_chains.getAll(), chain_file) catch |err| {
        std.debug.print("Error writing kit chains: {}\n", .{err});
    };
}

// Tests
test "XmlWriter basic usage" {
    // Cannot easily test file-based writer without temp files
    // Integration tests should cover this functionality
}
