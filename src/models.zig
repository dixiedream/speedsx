const std = @import("std");

/// Play mode for a pad sample
pub const PlayMode = enum(u8) {
    single = 0, // Play once
    phrase = 1, // Loop continuously
    loop = 2, // Loop continuously

    pub fn toString(self: PlayMode) []const u8 {
        return switch (self) {
            .single => "Single",
            .phrase => "Phrase",
            .loop => "Loop",
        };
    }
};

/// Mute group assignment
pub const MuteGroup = enum(u8) {
    off = 0,
    group1 = 1,
    group2 = 2,
    group3 = 3,
    group4 = 4,
    group5 = 5,
    group6 = 6,
    group7 = 7,
    group8 = 8,
    group9 = 9,

    pub fn toString(self: MuteGroup) []const u8 {
        return switch (self) {
            .off => "Off",
            .group1 => "1",
            .group2 => "2",
            .group3 => "3",
            .group4 => "4",
            .group5 => "5",
            .group6 => "6",
            .group7 => "7",
            .group8 => "8",
            .group9 => "9",
        };
    }
};

/// Loop mode for a pad sample
pub const LoopMode = enum(u8) {
    off = 0,
    on = 1,
    x2 = 2,
    x4 = 3,
    x8 = 4,

    pub fn toString(self: LoopMode) []const u8 {
        return switch (self) {
            .off => "OFF",
            .on => "ON",
            .x2 => "X2",
            .x4 => "X4",
            .x8 => "X8",
        };
    }
};


/// Tempo sync mode
pub const TempoSync = enum(u8) {
    off = 0,
    on = 1,

    pub fn toString(self: TempoSync) []const u8 {
        return switch (self) {
            .off => "OFF",
            .on => "ON",
        };
    }
};

/// Trigger type (ALT mode for alternating samples)
pub const TriggerMode = enum(u8) {
    shot = 0,
    alt = 1,

    pub fn toString(self: TriggerMode) []const u8 {
        return switch (self) {
            .shot => "NORMAL",
            .alt => "ALT"
        };
    }
};

/// Dynamics mode
pub const Dynamics = enum(u8) {
    off = 0,
    on = 1,

    pub fn toString(self: Dynamics) []const u8 {
        return switch (self) {
            .off => "OFF",
            .on => "ON",
        };
    }
};

/// Poly/Mono mode
pub const PolyMono = enum(u8) {
    mono = 0,
    poly = 1,

    pub fn toString(self: PolyMono) []const u8 {
        return switch (self) {
            .mono => "MONO",
            .poly => "POLY",
        };
    }
};

/// Output assignment
pub const OutputAssign = enum(u8) {
    master_out = 0,
    sub_out = 1,
    phones = 2,
    individual_1 = 3,
    individual_2 = 4,

    pub fn toString(self: OutputAssign) []const u8 {
        return switch (self) {
            .master_out => "MASTER OUT",
            .sub_out => "SUB OUT",
            .phones => "PHONES",
            .individual_1 => "INDIV 1",
            .individual_2 => "INDIV 2",
        };
    }
};

/// Pad link mode
pub const PadLink = enum(u8) {
    off = 0,
    pad1 = 1,
    pad2 = 2,
    pad3 = 3,
    pad4 = 4,
    pad5 = 5,
    pad6 = 6,
    pad7 = 7,
    pad8 = 8,
    pad9 = 9,
    trig1 = 10,
    trig2 = 11,
    trig3 = 12,
    trig4 = 13,
    fs1 = 14,
    fs2 = 15,

    pub fn toString(self: PadLink) []const u8 {
        return switch (self) {
            .off => "OFF",
            .pad1 => "PAD1",
            .pad2 => "PAD2",
            .pad3 => "PAD3",
            .pad4 => "PAD4",
            .pad5 => "PAD5",
            .pad6 => "PAD6",
            .pad7 => "PAD7",
            .pad8 => "PAD8",
            .pad9 => "PAD9",
            .trig1 => "TRIG1",
            .trig2 => "TRIG2",
            .trig3 => "TRIG3",
            .trig4 => "TRIG4",
            .fs1 => "FS1",
            .fs2 => "FS2"
        };
    }
};

/// Represents a sample that can be loaded onto a pad
pub const Sample = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: u8 = 0,
    file_path: [256]u8 = [_]u8{0} ** 256,
    path_len: u16 = 0,
    duration_ms: u32 = 0,
    sample_rate: u32 = 44100,
    channels: u8 = 2,
    loaded: bool = false,

    pub fn init() Sample {
        return Sample{};
    }

    pub fn setName(self: *Sample, name: []const u8) void {
        const len = @min(name.len, 64);
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const Sample) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setPath(self: *Sample, path: []const u8) void {
        const len = @min(path.len, 256);
        @memcpy(self.file_path[0..len], path[0..len]);
        self.path_len = @intCast(len);
    }

    pub fn getPath(self: *const Sample) []const u8 {
        return self.file_path[0..self.path_len];
    }
};

/// Represents a single pad on the SPD-SX
pub const Pad = struct {
    // Main wave/sample
    sample: Sample = Sample.init(),
    volume: u8 = 100, // 0-127
    pan: i8 = 0, // -64 to +63 (center = 0)
    pitch: i8 = 0, // -24 to +24 semitones
    decay: u8 = 100, // 0-100%
    play_mode: PlayMode = .single,
    mute_group: MuteGroup = .off,
    midi_note: u8 = 36, // Default to C2
    velocity_curve: u8 = 0, // 0 = linear, 1-4 = various curves
    trigger_type: TriggerType = .head,
    enabled: bool = true,
    has_sample: bool = false,

    // Mode settings
    // loop: bool = false,
    loop_mode: LoopMode = .off,
    trigger_mode: TriggerMode = .shot,
    dynamics: Dynamics = .off,
    poly_mono: PolyMono = .mono,
    output_assign: OutputAssign = .master_out,
    tempo_sync: TempoSync = .off,

    // Sub wave/sample
    sub_sample: Sample = Sample.init(),
    sub_volume: u8 = 100, // 0-127
    sub_pan: i8 = 0, // -64 to +63
    has_sub_sample: bool = false,

    pub const TriggerType = enum(u8) {
        head = 0,
        rim = 1,
        both = 2,

        pub fn toString(self: TriggerType) []const u8 {
            return switch (self) {
                .head => "Head",
                .rim => "Rim",
                .both => "Both",
            };
        }
    };

    pub fn init() Pad {
        return Pad{};
    }

    pub fn reset(self: *Pad) void {
        self.* = Pad.init();
    }

    pub fn loadSample(self: *Pad, name: []const u8, path: []const u8) void {
        self.sample.setName(name);
        self.sample.setPath(path);
        self.sample.loaded = true;
        self.has_sample = true;
    }

    pub fn clearSample(self: *Pad) void {
        self.sample = Sample.init();
        self.has_sample = false;
    }

    pub fn loadSubSample(self: *Pad, name: []const u8, path: []const u8) void {
        self.sub_sample.setName(name);
        self.sub_sample.setPath(path);
        self.sub_sample.loaded = true;
        self.has_sub_sample = true;
    }

    pub fn clearSubSample(self: *Pad) void {
        self.sub_sample = Sample.init();
        self.has_sub_sample = false;
    }
};

/// A kit is a collection of pad configurations
pub const Kit = struct {
    name: [32]u8 = [_]u8{0} ** 32,
    name_len: u8 = 0,
    sub_name: [32]u8 = [_]u8{0} ** 32,
    sub_name_len: u8 = 0,
    pads: [NUM_PADS]Pad = undefined,
    tempo: u16 = 120, // BPM (stored as integer, but displayed as float)
    tempo_decimal: u8 = 0, // Decimal part of tempo (0-9)
    master_volume: u8 = 100,
    master_fx_send: u8 = 50,
    pad_link: PadLink = .off,
    pad_link_target: PadLink = .off,
    modified: bool = false,

    pub const NUM_PADS = 9; // SPD-SX has 9 pads

    pub fn init() Kit {
        var kit = Kit{};
        for (&kit.pads, 0..) |*pad, i| {
            pad.* = Pad.init();
            pad.midi_note = @intCast(36 + i); // C2, C#2, D2, etc.
        }
        kit.setName("New Kit");
        return kit;
    }

    pub fn setName(self: *Kit, name: []const u8) void {
        const len = @min(name.len, 32);
        @memcpy(self.name[0..len], name[0..len]);
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const Kit) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn setSubName(self: *Kit, name: []const u8) void {
        const len = @min(name.len, 32);
        @memcpy(self.sub_name[0..len], name[0..len]);
        self.sub_name_len = @intCast(len);
    }

    pub fn getSubName(self: *const Kit) []const u8 {
        return self.sub_name[0..self.sub_name_len];
    }

    pub fn getPad(self: *Kit, index: usize) *Pad {
        return &self.pads[index];
    }

    pub fn getTempoFloat(self: *const Kit) f32 {
        return @as(f32, @floatFromInt(self.tempo)) + @as(f32, @floatFromInt(self.tempo_decimal)) / 10.0;
    }

    pub fn setTempoFloat(self: *Kit, tempo: f32) void {
        self.tempo = @intFromFloat(tempo);
        self.tempo_decimal = @intFromFloat((tempo - @as(f32, @floatFromInt(self.tempo))) * 10.0);
    }

    pub fn copyFrom(self: *Kit, other: *const Kit) void {
        self.* = other.*;
        self.modified = false;
    }

    pub fn duplicate(self: *const Kit) Kit {
        var new_kit = self.*;
        new_kit.modified = false;
        return new_kit;
    }
};

/// Represents the entire project state
pub const Project = struct {
    kits: [MAX_KITS]Kit = undefined,
    kit_count: u8 = 0,
    current_kit_index: u8 = 0,
    project_name: [64]u8 = [_]u8{0} ** 64,
    name_len: u8 = 0,
    sample_library: SampleLibrary = SampleLibrary.init(),
    file_path: [256]u8 = [_]u8{0} ** 256,
    file_path_len: u16 = 0,

    pub const MAX_KITS = 100;

    pub fn init() Project {
        var project = Project{};
        _ = project.addKit(); // Start with one kit
        project.setName("Untitled Project");
        return project;
    }

    pub fn setName(self: *Project, name: []const u8) void {
        const len = @min(name.len, 64);
        @memcpy(self.project_name[0..len], name[0..len]);
        self.name_len = @intCast(len);
    }

    pub fn getName(self: *const Project) []const u8 {
        return self.project_name[0..self.name_len];
    }

    pub fn setFilePath(self: *Project, path: []const u8) void {
        const len = @min(path.len, 256);
        @memcpy(self.file_path[0..len], path[0..len]);
        self.file_path_len = @intCast(len);
    }

    pub fn getFilePath(self: *const Project) []const u8 {
        return self.file_path[0..self.file_path_len];
    }

    pub fn addKit(self: *Project) bool {
        if (self.kit_count >= MAX_KITS) return false;
        self.kits[self.kit_count] = Kit.init();
        self.kit_count += 1;
        return true;
    }

    pub fn deleteKit(self: *Project, index: u8) bool {
        if (index >= self.kit_count or self.kit_count <= 1) return false;

        // Shift kits down
        var i: u8 = index;
        while (i < self.kit_count - 1) : (i += 1) {
            self.kits[i] = self.kits[i + 1];
        }
        self.kit_count -= 1;

        if (self.current_kit_index >= self.kit_count) {
            self.current_kit_index = self.kit_count - 1;
        }
        return true;
    }

    pub fn duplicateKit(self: *Project, index: u8) bool {
        if (self.kit_count >= MAX_KITS or index >= self.kit_count) return false;
        const new_kit = self.kits[index].duplicate();
        self.kits[self.kit_count] = new_kit;
        self.kit_count += 1;
        return true;
    }

    pub fn initKit(self: *Project, index: u8) void {
        if (index < self.kit_count) {
            self.kits[index] = Kit.init();
        }
    }

    pub fn moveKitUp(self: *Project, index: u8) bool {
        if (index == 0 or index >= self.kit_count) return false;
        const temp = self.kits[index];
        self.kits[index] = self.kits[index - 1];
        self.kits[index - 1] = temp;
        self.current_kit_index = index - 1;
        return true;
    }

    pub fn moveKitDown(self: *Project, index: u8) bool {
        if (index >= self.kit_count - 1) return false;
        const temp = self.kits[index];
        self.kits[index] = self.kits[index + 1];
        self.kits[index + 1] = temp;
        self.current_kit_index = index + 1;
        return true;
    }

    pub fn currentKit(self: *Project) *Kit {
        return &self.kits[self.current_kit_index];
    }

    pub fn selectKit(self: *Project, index: u8) void {
        if (index < self.kit_count) {
            self.current_kit_index = index;
        }
    }
};

/// Library of available samples
pub const SampleLibrary = struct {
    samples: [MAX_SAMPLES]Sample = undefined,
    count: u16 = 0,
    categories: [16][32]u8 = undefined,
    category_count: u8 = 0,

    pub const MAX_SAMPLES = 1000;

    pub fn init() SampleLibrary {
        return SampleLibrary{};
    }

    pub fn addSample(self: *SampleLibrary, name: []const u8, path: []const u8) bool {
        if (self.count >= MAX_SAMPLES) return false;
        self.samples[self.count] = Sample.init();
        self.samples[self.count].setName(name);
        self.samples[self.count].setPath(path);
        self.count += 1;
        return true;
    }

    pub fn getSample(self: *SampleLibrary, index: u16) ?*Sample {
        if (index >= self.count) return null;
        return &self.samples[index];
    }

    /// Find a sample by path, returns index or null if not found
    pub fn findByPath(self: *const SampleLibrary, path: []const u8) ?u16 {
        var i: u16 = 0;
        while (i < self.count) : (i += 1) {
            if (std.mem.eql(u8, self.samples[i].getPath(), path)) {
                return i;
            }
        }
        return null;
    }

    /// Add sample if not already present, returns the index
    pub fn addOrFind(self: *SampleLibrary, name: []const u8, path: []const u8) ?u16 {
        // Check if already exists
        if (self.findByPath(path)) |existing| {
            return existing;
        }
        // Add new
        if (self.count >= MAX_SAMPLES) return null;
        const index = self.count;
        self.samples[index] = Sample.init();
        self.samples[index].setName(name);
        self.samples[index].setPath(path);
        self.count += 1;
        return index;
    }

    /// Remove a sample by index
    pub fn removeSample(self: *SampleLibrary, index: u16) bool {
        if (index >= self.count) return false;
        // Shift samples down
        var i: u16 = index;
        while (i < self.count - 1) : (i += 1) {
            self.samples[i] = self.samples[i + 1];
        }
        self.count -= 1;
        return true;
    }
};

/// Effect types available
pub const EffectType = enum(u8) {
    none = 0,
    reverb = 1,
    delay = 2,
    chorus = 3,
    flanger = 4,
    distortion = 5,
    compressor = 6,
    eq = 7,
    filter = 8,

    pub fn toString(self: EffectType) []const u8 {
        return switch (self) {
            .none => "None",
            .reverb => "Reverb",
            .delay => "Delay",
            .chorus => "Chorus",
            .flanger => "Flanger",
            .distortion => "Distortion",
            .compressor => "Compressor",
            .eq => "EQ",
            .filter => "Filter",
        };
    }
};

/// MIDI configuration
pub const MidiConfig = struct {
    input_channel: u8 = 0, // 0-15 (0 = omni)
    output_channel: u8 = 9, // 0-15 (9 = GM drums)
    local_control: bool = true,
    send_program_change: bool = true,
    receive_program_change: bool = true,
    clock_source: ClockSource = .internal,

    pub const ClockSource = enum(u8) {
        internal = 0,
        midi = 1,
        usb = 2,

        pub fn toString(self: ClockSource) []const u8 {
            return switch (self) {
                .internal => "Internal",
                .midi => "MIDI",
                .usb => "USB",
            };
        }
    };
};
