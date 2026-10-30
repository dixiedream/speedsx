const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const storage = @import("storage.zig");

const Kit = types.Kit;
const Pad = types.Pad;
const Wave = types.Wave;
const TagListEntry = types.TagListEntry;
const KitChain = types.KitChain;
const DataStore = storage.DataStore;

/// XML parsing errors
pub const XmlError = error{
    InvalidXml,
    UnexpectedEndOfFile,
    InvalidTagName,
    MissingAttribute,
    ParseIntError,
    FileNotFound,
    ReadError,
} || Allocator.Error || std.Io.File.OpenError || std.Io.Reader.ReadAllocError;

/// Simple XML element representation
pub const XmlElement = struct {
    name: []const u8,
    content: ?[]const u8,
    children: std.ArrayListUnmanaged(XmlElement),
    allocator: Allocator,

    pub fn init(allocator: Allocator, name: []const u8) XmlElement {
        return .{
            .name = name,
            .content = null,
            .children = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *XmlElement) void {
        for (self.children.items) |*child| {
            child.deinit();
        }
        self.children.deinit(self.allocator);
    }

    /// Find first child element with given name
    pub fn findChild(self: *const XmlElement, name: []const u8) ?*const XmlElement {
        for (self.children.items) |*child| {
            if (std.mem.eql(u8, child.name, name)) {
                return child;
            }
        }
        return null;
    }

    /// Get text content
    pub fn getText(self: *const XmlElement) []const u8 {
        return self.content orelse "";
    }

    /// Get integer value from text content
    pub fn getInt(self: *const XmlElement, comptime T: type) ?T {
        const text = self.getText();
        if (text.len == 0) return null;
        return std.fmt.parseInt(T, text, 10) catch null;
    }
};

/// Simple XML parser
pub const XmlParser = struct {
    allocator: Allocator,
    data: []const u8,
    pos: usize,

    pub fn init(allocator: Allocator, data: []const u8) XmlParser {
        return .{
            .allocator = allocator,
            .data = data,
            .pos = 0,
        };
    }

    fn skipWhitespace(self: *XmlParser) void {
        while (self.pos < self.data.len and std.ascii.isWhitespace(self.data[self.pos])) {
            self.pos += 1;
        }
    }

    fn peek(self: *const XmlParser) ?u8 {
        if (self.pos < self.data.len) {
            return self.data[self.pos];
        }
        return null;
    }

    fn advance(self: *XmlParser) ?u8 {
        if (self.pos < self.data.len) {
            const c = self.data[self.pos];
            self.pos += 1;
            return c;
        }
        return null;
    }

    fn readTagName(self: *XmlParser) []const u8 {
        const start = self.pos;
        while (self.pos < self.data.len) {
            const c = self.data[self.pos];
            if (std.ascii.isWhitespace(c) or c == '>' or c == '/') break;
            self.pos += 1;
        }
        return self.data[start..self.pos];
    }

    /// Parse a single element
    pub fn parseElement(self: *XmlParser) XmlError!?XmlElement {
        self.skipWhitespace();

        if (self.peek() != '<') {
            return null;
        }
        _ = self.advance();

        if (self.peek() == '/') {
            return null;
        }

        if (self.peek() == '?') {
            while (self.pos < self.data.len) {
                if (self.data[self.pos] == '>' and self.pos > 0 and self.data[self.pos - 1] == '?') {
                    self.pos += 1;
                    return self.parseElement();
                }
                self.pos += 1;
            }
            return null;
        }

        if (self.peek() == '!') {
            while (self.pos < self.data.len and self.data[self.pos] != '>') {
                self.pos += 1;
            }
            if (self.pos < self.data.len) self.pos += 1;
            return self.parseElement();
        }

        const tag_name = self.readTagName();
        if (tag_name.len == 0) return error.InvalidTagName;

        var element = XmlElement.init(self.allocator, tag_name);
        errdefer element.deinit();

        self.skipWhitespace();
        while (self.peek() != '>' and self.peek() != '/' and self.pos < self.data.len) {
            _ = self.advance();
        }

        if (self.peek() == '/') {
            _ = self.advance();
            if (self.peek() == '>') {
                _ = self.advance();
                return element;
            }
        }

        if (self.peek() != '>') {
            return error.InvalidXml;
        }
        _ = self.advance();

        var content_start: ?usize = null;
        var content_end: usize = self.pos;

        while (self.pos < self.data.len) {
            self.skipWhitespace();

            if (self.peek() == '<') {
                if (self.pos + 1 < self.data.len and self.data[self.pos + 1] == '/') {
                    if (content_start) |start| {
                        var end = content_end;
                        while (end > start and std.ascii.isWhitespace(self.data[end - 1])) {
                            end -= 1;
                        }
                        var trimmed_start = start;
                        while (trimmed_start < end and std.ascii.isWhitespace(self.data[trimmed_start])) {
                            trimmed_start += 1;
                        }
                        element.content = self.data[trimmed_start..end];
                    }
                    self.pos += 2;
                    _ = self.readTagName();
                    if (self.peek() == '>') {
                        _ = self.advance();
                    }
                    break;
                } else {
                    if (try self.parseElement()) |child| {
                        try element.children.append(self.allocator, child);
                    }
                }
            } else {
                if (content_start == null) {
                    content_start = self.pos;
                }
                _ = self.advance();
                content_end = self.pos;
            }
        }

        return element;
    }

    pub fn parse(self: *XmlParser) XmlError!?XmlElement {
        self.skipWhitespace();
        return self.parseElement();
    }
};

/// Helper to get child value by name
fn getChildValue(element: *const XmlElement, name: []const u8, comptime T: type, default: T) T {
    if (element.findChild(name)) |e| {
        return e.getInt(T) orelse default;
    }
    return default;
}

fn readFileAlloc(allocator: Allocator, io: std.Io, file_path: []const u8, max: usize) ![]u8 {
    const file = std.Io.Dir.openFileAbsolute(io, file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return error.FileNotFound;
        return error.ReadError;
    };
    defer file.close(io);

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(io, &read_buf);
    return file_reader.interface.readAllocAll(allocator, max) catch error.ReadError;
}

/// Parse a .spd kit file
pub fn parseKitFile(allocator: Allocator, io: std.Io, file_path: []const u8) !Kit {
    const content = try readFileAlloc(allocator, io, file_path, 1024 * 1024);
    defer allocator.free(content);

    var parser = XmlParser.init(allocator, content);
    var root = try parser.parse() orelse return error.InvalidXml;
    defer root.deinit();

    return parseKitElement(&root);
}

/// Parse Kit from XML element
fn parseKitElement(element: *const XmlElement) Kit {
    var kit = Kit.init();

    kit.level = getChildValue(element, "Level", u8, 100);
    kit.tempo = getChildValue(element, "Tempo", u16, 1200);

    // Parse name - done manually to avoid comptime limits
    kit.nm[0] = getChildValue(element, "Nm0", u8, 0);
    kit.nm[1] = getChildValue(element, "Nm1", u8, 0);
    kit.nm[2] = getChildValue(element, "Nm2", u8, 0);
    kit.nm[3] = getChildValue(element, "Nm3", u8, 0);
    kit.nm[4] = getChildValue(element, "Nm4", u8, 0);
    kit.nm[5] = getChildValue(element, "Nm5", u8, 0);
    kit.nm[6] = getChildValue(element, "Nm6", u8, 0);
    kit.nm[7] = getChildValue(element, "Nm7", u8, 0);

    // Parse sub-name
    kit.sub_nm[0] = getChildValue(element, "SubNm0", u8, 0);
    kit.sub_nm[1] = getChildValue(element, "SubNm1", u8, 0);
    kit.sub_nm[2] = getChildValue(element, "SubNm2", u8, 0);
    kit.sub_nm[3] = getChildValue(element, "SubNm3", u8, 0);
    kit.sub_nm[4] = getChildValue(element, "SubNm4", u8, 0);
    kit.sub_nm[5] = getChildValue(element, "SubNm5", u8, 0);
    kit.sub_nm[6] = getChildValue(element, "SubNm6", u8, 0);
    kit.sub_nm[7] = getChildValue(element, "SubNm7", u8, 0);
    kit.sub_nm[8] = getChildValue(element, "SubNm8", u8, 0);
    kit.sub_nm[9] = getChildValue(element, "SubNm9", u8, 0);
    kit.sub_nm[10] = getChildValue(element, "SubNm10", u8, 0);
    kit.sub_nm[11] = getChildValue(element, "SubNm11", u8, 0);
    kit.sub_nm[12] = getChildValue(element, "SubNm12", u8, 0);
    kit.sub_nm[13] = getChildValue(element, "SubNm13", u8, 0);
    kit.sub_nm[14] = getChildValue(element, "SubNm14", u8, 0);
    kit.sub_nm[15] = getChildValue(element, "SubNm15", u8, 0);

    // Parse FX settings
    kit.fx2_asgn = getChildValue(element, "Fx2Asgn", u8, 0);
    kit.link_pad0 = getChildValue(element, "LinkPad0", i8, -1);
    kit.link_pad1 = getChildValue(element, "LinkPad1", i8, -1);
    kit.fx1_sw = getChildValue(element, "Fx1Sw", u8, 1);
    kit.fx1_type = getChildValue(element, "Fx1Type", u8, 0);
    kit.fx2_sw = getChildValue(element, "Fx2Sw", u8, 1);
    kit.fx2_type = getChildValue(element, "Fx2Type", u8, 0);

    // Parse FX1 parameters
    kit.fx1_prm[0] = getChildValue(element, "Fx1Prm0", u8, 0);
    kit.fx1_prm[1] = getChildValue(element, "Fx1Prm1", u8, 0);
    kit.fx1_prm[2] = getChildValue(element, "Fx1Prm2", u8, 0);
    kit.fx1_prm[3] = getChildValue(element, "Fx1Prm3", u8, 0);
    kit.fx1_prm[4] = getChildValue(element, "Fx1Prm4", u8, 0);
    kit.fx1_prm[5] = getChildValue(element, "Fx1Prm5", u8, 0);
    kit.fx1_prm[6] = getChildValue(element, "Fx1Prm6", u8, 0);
    kit.fx1_prm[7] = getChildValue(element, "Fx1Prm7", u8, 0);
    kit.fx1_prm[8] = getChildValue(element, "Fx1Prm8", u8, 0);
    kit.fx1_prm[9] = getChildValue(element, "Fx1Prm9", u8, 0);
    kit.fx1_prm[10] = getChildValue(element, "Fx1Prm10", u8, 0);
    kit.fx1_prm[11] = getChildValue(element, "Fx1Prm11", u8, 0);
    kit.fx1_prm[12] = getChildValue(element, "Fx1Prm12", u8, 0);
    kit.fx1_prm[13] = getChildValue(element, "Fx1Prm13", u8, 0);
    kit.fx1_prm[14] = getChildValue(element, "Fx1Prm14", u8, 0);
    kit.fx1_prm[15] = getChildValue(element, "Fx1Prm15", u8, 0);
    kit.fx1_prm[16] = getChildValue(element, "Fx1Prm16", u8, 0);
    kit.fx1_prm[17] = getChildValue(element, "Fx1Prm17", u8, 0);
    kit.fx1_prm[18] = getChildValue(element, "Fx1Prm18", u8, 0);
    kit.fx1_prm[19] = getChildValue(element, "Fx1Prm19", u8, 0);

    // Parse FX2 parameters
    kit.fx2_prm[0] = getChildValue(element, "Fx2Prm0", u8, 0);
    kit.fx2_prm[1] = getChildValue(element, "Fx2Prm1", u8, 0);
    kit.fx2_prm[2] = getChildValue(element, "Fx2Prm2", u8, 0);
    kit.fx2_prm[3] = getChildValue(element, "Fx2Prm3", u8, 0);
    kit.fx2_prm[4] = getChildValue(element, "Fx2Prm4", u8, 0);
    kit.fx2_prm[5] = getChildValue(element, "Fx2Prm5", u8, 0);
    kit.fx2_prm[6] = getChildValue(element, "Fx2Prm6", u8, 0);
    kit.fx2_prm[7] = getChildValue(element, "Fx2Prm7", u8, 0);
    kit.fx2_prm[8] = getChildValue(element, "Fx2Prm8", u8, 0);
    kit.fx2_prm[9] = getChildValue(element, "Fx2Prm9", u8, 0);
    kit.fx2_prm[10] = getChildValue(element, "Fx2Prm10", u8, 0);
    kit.fx2_prm[11] = getChildValue(element, "Fx2Prm11", u8, 0);
    kit.fx2_prm[12] = getChildValue(element, "Fx2Prm12", u8, 0);
    kit.fx2_prm[13] = getChildValue(element, "Fx2Prm13", u8, 0);
    kit.fx2_prm[14] = getChildValue(element, "Fx2Prm14", u8, 0);
    kit.fx2_prm[15] = getChildValue(element, "Fx2Prm15", u8, 0);
    kit.fx2_prm[16] = getChildValue(element, "Fx2Prm16", u8, 0);
    kit.fx2_prm[17] = getChildValue(element, "Fx2Prm17", u8, 0);
    kit.fx2_prm[18] = getChildValue(element, "Fx2Prm18", u8, 0);
    kit.fx2_prm[19] = getChildValue(element, "Fx2Prm19", u8, 0);

    // Parse pads
    var pad_idx: usize = 0;
    for (element.children.items) |*child| {
        if (std.mem.eql(u8, child.name, "PadPrm") and pad_idx < types.MAX_PADS) {
            kit.pads[pad_idx] = parsePadElement(child);
            pad_idx += 1;
        }
    }

    return kit;
}

/// Parse Pad from XML element
fn parsePadElement(element: *const XmlElement) Pad {
    var pad = Pad.init();

    pad.wv = getChildValue(element, "Wv", i32, -1);
    pad.wv_level = getChildValue(element, "WvLevel", u8, 100);
    pad.wv_pan = getChildValue(element, "WvPan", u8, 15);
    pad.play_mode = getChildValue(element, "PlayMode", u8, 0);
    pad.out_asgn = getChildValue(element, "OutAsgn", u8, 0);
    pad.mute_grp = getChildValue(element, "MuteGrp", u8, 0);
    pad.tempo_sync = getChildValue(element, "TempoSync", u8, 0);
    pad.pad_midi_ch = getChildValue(element, "PadMidiCh", i8, -1);
    pad.note_num = getChildValue(element, "NoteNum", i16, -1);
    pad.midi_ctrl = getChildValue(element, "MidiCtrl", u8, 0);
    pad.loop = getChildValue(element, "Loop", u8, 0);
    pad.trig_type = getChildValue(element, "TrigType", u8, 0);
    pad.gate_time = getChildValue(element, "GateTime", i8, -1);
    pad.dynamics = getChildValue(element, "Dynamics", u8, 1);
    pad.voice_asgn = getChildValue(element, "VoiceAsgn", u8, 1);
    pad.reverse = getChildValue(element, "Reverse", u8, 0);
    pad.sub_wv = getChildValue(element, "SubWv", i32, -1);
    pad.sub_wv_level = getChildValue(element, "SubWvLevel", u8, 100);
    pad.sub_wv_pan = getChildValue(element, "SubWvPan", u8, 15);

    return pad;
}

/// Parse a .spd wave file
pub fn parseWaveFile(allocator: Allocator, io: std.Io, file_path: []const u8, wave_id: u32) !Wave {
    const content = try readFileAlloc(allocator, io, file_path, 1024 * 1024);
    defer allocator.free(content);

    var parser = XmlParser.init(allocator, content);
    var root = try parser.parse() orelse return error.InvalidXml;
    defer root.deinit();

    return parseWaveElement(&root, wave_id);
}

/// Parse Wave from XML element
fn parseWaveElement(element: *const XmlElement, wave_id: u32) Wave {
    var wave = Wave.init();
    wave.wave_id = wave_id;

    // Parse name
    wave.nm[0] = getChildValue(element, "Nm0", u8, 0);
    wave.nm[1] = getChildValue(element, "Nm1", u8, 0);
    wave.nm[2] = getChildValue(element, "Nm2", u8, 0);
    wave.nm[3] = getChildValue(element, "Nm3", u8, 0);
    wave.nm[4] = getChildValue(element, "Nm4", u8, 0);
    wave.nm[5] = getChildValue(element, "Nm5", u8, 0);
    wave.nm[6] = getChildValue(element, "Nm6", u8, 0);
    wave.nm[7] = getChildValue(element, "Nm7", u8, 0);
    wave.nm[8] = getChildValue(element, "Nm8", u8, 0);
    wave.nm[9] = getChildValue(element, "Nm9", u8, 0);
    wave.nm[10] = getChildValue(element, "Nm10", u8, 0);
    wave.nm[11] = getChildValue(element, "Nm11", u8, 0);

    if (element.findChild("Path")) |e| {
        const path_text = e.getText();
        wave.setPath(path_text);
    }
    wave.tag = getChildValue(element, "Tag", u8, 1);
    wave.tempo = getChildValue(element, "Tempo", u16, 0);
    wave.beat = getChildValue(element, "Beat", u8, 0);
    wave.measure = getChildValue(element, "Measure", u8, 0);
    wave.start = getChildValue(element, "Start", u32, 0);
    wave.end = getChildValue(element, "End", u32, 0);

    return wave;
}

/// Parse tag_list.spd file
pub fn parseTagListFile(allocator: Allocator, io: std.Io, file_path: []const u8) !std.ArrayListUnmanaged(TagListEntry) {
    const content = try readFileAlloc(allocator, io, file_path, 1024 * 1024);
    defer allocator.free(content);

    var parser = XmlParser.init(allocator, content);
    var root = try parser.parse() orelse return error.InvalidXml;
    defer root.deinit();

    var tags: std.ArrayListUnmanaged(TagListEntry) = .empty;
    errdefer tags.deinit(allocator);

    for (root.children.items) |*child| {
        if (std.mem.eql(u8, child.name, "TagPrm")) {
            var tag = TagListEntry.init();

            tag.nm[0] = getChildValue(child, "Nm0", u8, 0);
            tag.nm[1] = getChildValue(child, "Nm1", u8, 0);
            tag.nm[2] = getChildValue(child, "Nm2", u8, 0);
            tag.nm[3] = getChildValue(child, "Nm3", u8, 0);
            tag.nm[4] = getChildValue(child, "Nm4", u8, 0);
            tag.nm[5] = getChildValue(child, "Nm5", u8, 0);
            tag.nm[6] = getChildValue(child, "Nm6", u8, 0);
            tag.nm[7] = getChildValue(child, "Nm7", u8, 0);
            tag.nm[8] = getChildValue(child, "Nm8", u8, 0);
            tag.nm[9] = getChildValue(child, "Nm9", u8, 0);
            tag.nm[10] = getChildValue(child, "Nm10", u8, 0);
            tag.nm[11] = getChildValue(child, "Nm11", u8, 0);
            tag.order = getChildValue(child, "Order", u8, 0);

            try tags.append(allocator, tag);
        }
    }

    return tags;
}

/// Parse kit chain from sysparam.spd
pub fn parseKitChainFile(allocator: Allocator, io: std.Io, file_path: []const u8) !std.ArrayListUnmanaged(KitChain) {
    const content = try readFileAlloc(allocator, io, file_path, 1024 * 1024);
    defer allocator.free(content);

    // Wrap content in <sys> tags if not already present
    const wrapped: []const u8 = if (!std.mem.startsWith(u8, content, "<sys>"))
        try std.fmt.allocPrint(allocator, "<sys>\n{s}\n</sys>", .{content})
    else
        content;
    defer if (wrapped.ptr != content.ptr) allocator.free(@constCast(wrapped));

    var parser = XmlParser.init(allocator, wrapped);
    var root = try parser.parse() orelse return error.InvalidXml;
    defer root.deinit();

    var chains: std.ArrayListUnmanaged(KitChain) = .empty;
    errdefer chains.deinit(allocator);

    // Look for KitChainPrm > KitChain elements
    for (root.children.items) |*child| {
        if (std.mem.eql(u8, child.name, "KitChainPrm")) {
            for (child.children.items) |*chain_elem| {
                if (std.mem.eql(u8, chain_elem.name, "KitChain")) {
                    var chain = KitChain.init();

                    chain.nm[0] = getChildValue(chain_elem, "Nm0", u8, 0);
                    chain.nm[1] = getChildValue(chain_elem, "Nm1", u8, 0);
                    chain.nm[2] = getChildValue(chain_elem, "Nm2", u8, 0);
                    chain.nm[3] = getChildValue(chain_elem, "Nm3", u8, 0);
                    chain.nm[4] = getChildValue(chain_elem, "Nm4", u8, 0);
                    chain.nm[5] = getChildValue(chain_elem, "Nm5", u8, 0);
                    chain.nm[6] = getChildValue(chain_elem, "Nm6", u8, 0);
                    chain.nm[7] = getChildValue(chain_elem, "Nm7", u8, 0);
                    chain.nm[8] = getChildValue(chain_elem, "Nm8", u8, 0);
                    chain.nm[9] = getChildValue(chain_elem, "Nm9", u8, 0);

                    chain.steps[0] = getChildValue(chain_elem, "Stp0", i32, -1);
                    chain.steps[1] = getChildValue(chain_elem, "Stp1", i32, -1);
                    chain.steps[2] = getChildValue(chain_elem, "Stp2", i32, -1);
                    chain.steps[3] = getChildValue(chain_elem, "Stp3", i32, -1);
                    chain.steps[4] = getChildValue(chain_elem, "Stp4", i32, -1);
                    chain.steps[5] = getChildValue(chain_elem, "Stp5", i32, -1);
                    chain.steps[6] = getChildValue(chain_elem, "Stp6", i32, -1);
                    chain.steps[7] = getChildValue(chain_elem, "Stp7", i32, -1);
                    chain.steps[8] = getChildValue(chain_elem, "Stp8", i32, -1);
                    chain.steps[9] = getChildValue(chain_elem, "Stp9", i32, -1);
                    chain.steps[10] = getChildValue(chain_elem, "Stp10", i32, -1);
                    chain.steps[11] = getChildValue(chain_elem, "Stp11", i32, -1);
                    chain.steps[12] = getChildValue(chain_elem, "Stp12", i32, -1);
                    chain.steps[13] = getChildValue(chain_elem, "Stp13", i32, -1);
                    chain.steps[14] = getChildValue(chain_elem, "Stp14", i32, -1);
                    chain.steps[15] = getChildValue(chain_elem, "Stp15", i32, -1);
                    chain.steps[16] = getChildValue(chain_elem, "Stp16", i32, -1);
                    chain.steps[17] = getChildValue(chain_elem, "Stp17", i32, -1);
                    chain.steps[18] = getChildValue(chain_elem, "Stp18", i32, -1);
                    chain.steps[19] = getChildValue(chain_elem, "Stp19", i32, -1);

                    try chains.append(allocator, chain);
                }
            }
        }
    }

    return chains;
}

// Tests
test "XmlParser basic parsing" {
    const allocator = std.testing.allocator;
    const xml_data = "<root><child>value</child></root>";

    var parser = XmlParser.init(allocator, xml_data);
    var root = try parser.parse();
    defer if (root) |*r| r.deinit();

    try std.testing.expect(root != null);
    try std.testing.expectEqualStrings("root", root.?.name);
    try std.testing.expectEqual(@as(usize, 1), root.?.children.items.len);

    const child = root.?.findChild("child");
    try std.testing.expect(child != null);
    try std.testing.expectEqualStrings("value", child.?.getText());
}

test "Parse kit element" {
    const allocator = std.testing.allocator;
    const xml_data =
        \\<KitPrm>
        \\<Level>80</Level>
        \\<Tempo>1400</Tempo>
        \\<Nm0>84</Nm0>
        \\<Nm1>101</Nm1>
        \\<Nm2>115</Nm2>
        \\<Nm3>116</Nm3>
        \\</KitPrm>
    ;

    var parser = XmlParser.init(allocator, xml_data);
    var root = try parser.parse();
    defer if (root) |*r| r.deinit();

    try std.testing.expect(root != null);

    const kit = parseKitElement(&root.?);
    try std.testing.expectEqual(@as(u8, 80), kit.level);
    try std.testing.expectEqual(@as(u16, 1400), kit.tempo);
    try std.testing.expectEqual(@as(u8, 84), kit.nm[0]); // 'T'
}
