const std = @import("std");

/// A fixed-capacity string type that avoids repetitive array+length patterns
pub fn BoundedString(comptime capacity: usize) type {
    const LenType = if (capacity <= 255) u8 else u16;

    return struct {
        const Self = @This();

        data: [capacity]u8 = [_]u8{0} ** capacity,
        len: LenType = 0,

        /// Set the string content, truncating if too long
        pub fn set(self: *Self, str: []const u8) void {
            const copy_len = @min(str.len, capacity);
            @memcpy(self.data[0..copy_len], str[0..copy_len]);
            // Zero out remaining bytes
            if (copy_len < capacity) {
                @memset(self.data[copy_len..], 0);
            }
            self.len = @intCast(copy_len);
        }

        /// Get the string as a slice
        pub fn get(self: *const Self) []const u8 {
            return self.data[0..self.len];
        }

        /// Clear the string
        pub fn clear(self: *Self) void {
            @memset(&self.data, 0);
            self.len = 0;
        }

        /// Check if empty
        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        /// Get the capacity
        pub fn getCapacity() usize {
            return capacity;
        }
    };
}

/// Play mode for a pad sample
pub const TemplateMode = enum(u8) {
    single = 0, // Play once
    phrase = 1, // Loop continuously
    loop = 2, // Loop continuously

    pub fn toString(self: TemplateMode) []const u8 {
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
            .shot => "SHOT",
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
    name: BoundedString(64) = .{},
    file_path: BoundedString(256) = .{},
    duration_ms: u32 = 0,
    sample_rate: u32 = 44100,
    channels: u8 = 2,
    loaded: bool = false,

    // Wave metadata from SPD-SX
    tag: u8 = 1, // Tag category (1-12)
    tempo: u16 = 0, // Sample tempo for sync (0 = not set)
    beat: u8 = 0, // Beat value
    measure: u8 = 0, // Measure value
    start_point: u32 = 0, // Sample start point (in samples)
    end_point: u32 = 0, // Sample end point (in samples)

    pub fn init() Sample {
        return Sample{};
    }

    pub fn setName(self: *Sample, new_name: []const u8) void {
        self.name.set(new_name);
    }

    pub fn getName(self: *const Sample) []const u8 {
        return self.name.get();
    }

    pub fn setPath(self: *Sample, path: []const u8) void {
        self.file_path.set(path);
    }

    pub fn getPath(self: *const Sample) []const u8 {
        return self.file_path.get();
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
    play_mode: TemplateMode = .single,
    mute_group: MuteGroup = .off,
    midi_note: i16 = -1, // -1 = OFF, 0-127 = note number
    velocity_curve: u8 = 0, // 0 = linear, 1-4 = various curves
    trigger_type: TriggerType = .head,
    enabled: bool = true,
    has_sample: bool = false,

    // Mode settings
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

    // MIDI settings
    midi_channel: MidiChannel = .global, // GLOBAL or 1-16
    midi_ext_ctrl: bool = false, // OFF or ON
    midi_gate_time: u8 = 0, // 0 = OFF, 1 = ALT, 2-81 = 0.1s-8.0s

    // Playback settings
    reverse: bool = false, // Reverse playback

    pub const MidiChannel = enum(u8) {
        global = 0,
        ch1 = 1,
        ch2 = 2,
        ch3 = 3,
        ch4 = 4,
        ch5 = 5,
        ch6 = 6,
        ch7 = 7,
        ch8 = 8,
        ch9 = 9,
        ch10 = 10,
        ch11 = 11,
        ch12 = 12,
        ch13 = 13,
        ch14 = 14,
        ch15 = 15,
        ch16 = 16,

        pub fn toString(self: MidiChannel) []const u8 {
            return switch (self) {
                .global => "GLOBAL",
                .ch1 => "1",
                .ch2 => "2",
                .ch3 => "3",
                .ch4 => "4",
                .ch5 => "5",
                .ch6 => "6",
                .ch7 => "7",
                .ch8 => "8",
                .ch9 => "9",
                .ch10 => "10",
                .ch11 => "11",
                .ch12 => "12",
                .ch13 => "13",
                .ch14 => "14",
                .ch15 => "15",
                .ch16 => "16",
            };
        }
    };

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
    name: BoundedString(32) = .{},
    sub_name: BoundedString(32) = .{},
    pads: [NUM_PADS]Pad = undefined,
    tempo: u16 = 120, // BPM (stored as integer, but displayed as float)
    tempo_decimal: u8 = 0, // Decimal part of tempo (0-9)
    master_volume: u8 = 100,
    master_fx_send: u8 = 50,
    pad_link: PadLink = .off,
    pad_link_target: PadLink = .off,
    modified: bool = false,

    // FX1 settings
    fx1_switch: bool = true,
    fx1_type: FxType = .thru,
    fx1_params: FxParams = FxParams.init(),

    // FX2 settings
    fx2_switch: bool = true,
    fx2_type: FxType = .thru,
    fx2_params: FxParams = FxParams.init(),
    fx2_assign: Fx2Assign = .all,

    // SPD-SX has 15 configurable pads:
    // 0-8: Main pads (physical pads on the unit)
    // 9-12: External triggers (TRIG1-4)
    // 13-14: Foot switches (FS1-2)
    pub const NUM_PADS = 15;
    pub const NUM_MAIN_PADS = 9;
    pub const NUM_TRIGGERS = 4;
    pub const NUM_FOOTSWITCHES = 2;

    pub fn init() Kit {
        var kit = Kit{};
        for (&kit.pads) |*pad| {
            pad.* = Pad.init();
        }
        kit.setName("New Kit");
        return kit;
    }

    /// Get a main pad (0-8)
    pub fn getMainPad(self: *Kit, index: usize) *Pad {
        return &self.pads[index];
    }

    /// Get a trigger pad (0-3 -> pads 9-12)
    pub fn getTriggerPad(self: *Kit, index: usize) *Pad {
        return &self.pads[NUM_MAIN_PADS + index];
    }

    /// Get a footswitch pad (0-1 -> pads 13-14)
    pub fn getFootswitchPad(self: *Kit, index: usize) *Pad {
        return &self.pads[NUM_MAIN_PADS + NUM_TRIGGERS + index];
    }

    /// Check if pad index is a main pad
    pub fn isMainPad(index: u8) bool {
        return index < NUM_MAIN_PADS;
    }

    /// Check if pad index is a trigger
    pub fn isTriggerPad(index: u8) bool {
        return index >= NUM_MAIN_PADS and index < NUM_MAIN_PADS + NUM_TRIGGERS;
    }

    /// Check if pad index is a footswitch
    pub fn isFootswitchPad(index: u8) bool {
        return index >= NUM_MAIN_PADS + NUM_TRIGGERS and index < NUM_PADS;
    }

    /// Get display name for a pad index
    pub fn getPadDisplayName(index: u8) []const u8 {
        if (index < NUM_MAIN_PADS) {
            const names = [_][]const u8{ "PAD 1", "PAD 2", "PAD 3", "PAD 4", "PAD 5", "PAD 6", "PAD 7", "PAD 8", "PAD 9" };
            return names[index];
        } else if (index < NUM_MAIN_PADS + NUM_TRIGGERS) {
            const names = [_][]const u8{ "TRIG 1", "TRIG 2", "TRIG 3", "TRIG 4" };
            return names[index - NUM_MAIN_PADS];
        } else if (index < NUM_PADS) {
            const names = [_][]const u8{ "FS 1", "FS 2" };
            return names[index - NUM_MAIN_PADS - NUM_TRIGGERS];
        }
        return "?";
    }

    pub fn setName(self: *Kit, new_name: []const u8) void {
        self.name.set(new_name);
    }

    pub fn getName(self: *const Kit) []const u8 {
        return self.name.get();
    }

    pub fn setSubName(self: *Kit, new_name: []const u8) void {
        self.sub_name.set(new_name);
    }

    pub fn getSubName(self: *const Kit) []const u8 {
        return self.sub_name.get();
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
    project_name: BoundedString(64) = .{},
    sample_library: SampleLibrary = SampleLibrary.init(),
    kit_chain_library: KitChainLibrary = KitChainLibrary.init(),
    tag_library: TagLibrary = TagLibrary.init(),
    file_path: BoundedString(256) = .{},

    pub const MAX_KITS = 100;

    pub fn init() Project {
        var project = Project{};
        _ = project.addKit(); // Start with one kit
        project.setName("Untitled Project");
        return project;
    }

    pub fn setName(self: *Project, new_name: []const u8) void {
        self.project_name.set(new_name);
    }

    pub fn getName(self: *const Project) []const u8 {
        return self.project_name.get();
    }

    pub fn setFilePath(self: *Project, path: []const u8) void {
        self.file_path.set(path);
    }

    pub fn getFilePath(self: *const Project) []const u8 {
        return self.file_path.get();
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

/// Tag entry for categorizing samples
pub const TagEntry = struct {
    name: BoundedString(16) = .{},
    order: u8 = 0,

    pub fn init() TagEntry {
        return TagEntry{};
    }

    pub fn setName(self: *TagEntry, new_name: []const u8) void {
        self.name.set(new_name);
    }

    pub fn getName(self: *const TagEntry) []const u8 {
        return self.name.get();
    }
};

/// Tag library - collection of sample categories
pub const TagLibrary = struct {
    tags: [MAX_TAGS]TagEntry = undefined,
    count: u8 = 0,

    pub const MAX_TAGS = 12;

    // Default SPD-SX tags
    const DEFAULT_TAGS = [_][]const u8{
        "KICK",
        "SNARE",
        "HI-HAT",
        "CYMBAL",
        "TOM",
        "PERCUSSION",
        "PHRASE",
        "FX",
        "LOOP",
        "OTHERS",
        "USER1",
        "USER2",
    };

    pub fn init() TagLibrary {
        var lib = TagLibrary{};
        // Initialize with default tags
        for (DEFAULT_TAGS, 0..) |tag_name, i| {
            lib.tags[i] = TagEntry.init();
            lib.tags[i].setName(tag_name);
            lib.tags[i].order = @intCast(i);
        }
        lib.count = MAX_TAGS;
        return lib;
    }

    pub fn getTag(self: *TagLibrary, index: u8) ?*TagEntry {
        if (index >= self.count) return null;
        return &self.tags[index];
    }

    pub fn setTagName(self: *TagLibrary, index: u8, name: []const u8) void {
        if (index < self.count) {
            self.tags[index].setName(name);
        }
    }

    pub fn getTagName(self: *const TagLibrary, index: u8) []const u8 {
        if (index < self.count) {
            return self.tags[index].getName();
        }
        return "Unknown";
    }
};

/// FX effect types (matches SPD-SX FX types)
pub const FxType = enum(u8) {
    thru = 0,
    stereo_delay = 1,
    sync_delay = 2,
    tape_echo = 3,
    chorus = 4,
    flanger = 5,
    step_flanger = 6,
    phaser = 7,
    step_phaser = 8,
    equalizer = 9,
    compressor = 10,
    filter = 11,
    filt_drive = 12,
    isolator = 13,
    touch_wah = 14,
    distortion = 15,
    ringmod = 16,
    pitch_shift = 17,
    vibrato = 18,
    reverb = 19,
    slicer = 20,

    pub fn toString(self: FxType) []const u8 {
        return switch (self) {
            .thru => "THRU",
            .stereo_delay => "STEREO DLY",
            .sync_delay => "SYNC DELAY",
            .tape_echo => "TAPE ECHO",
            .chorus => "CHORUS",
            .flanger => "FLANGER",
            .step_flanger => "STEP FLNGR",
            .phaser => "PHASER",
            .step_phaser => "STEP PHASR",
            .equalizer => "EQ",
            .compressor => "COMPRESSOR",
            .filter => "FILTER",
            .filt_drive => "FILT+DRIVE",
            .isolator => "ISOLATOR",
            .touch_wah => "TOUCH WAH",
            .distortion => "DISTORTION",
            .ringmod => "RINGMOD",
            .pitch_shift => "PITCHSHIFT",
            .vibrato => "VIBRATO",
            .reverb => "REVERB",
            .slicer => "SLICER",
        };
    }
};

/// FX2 effect types (matches SPD-SX FX2 types)
// pub const Fx2Type = enum(u8) {
//     thru = 0,
//     hall = 1,
//     room = 2,
//     plate = 3,
//     delay = 4,
//     pan_delay = 5,
//     tape_echo = 6,
//
//     pub fn toString(self: Fx2Type) []const u8 {
//         return switch (self) {
//             .thru => "THRU",
//             .hall => "HALL",
//             .room => "ROOM",
//             .plate => "PLATE",
//             .delay => "DELAY",
//             .pan_delay => "PAN DELAY",
//             .tape_echo => "TAPE ECHO",
//         };
//     }
// };

/// FX2 assignment (which pads send to FX2)
pub const Fx2Assign = enum(u8) {
    all = 0,
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

    pub fn toString(self: Fx2Assign) []const u8 {
        return switch (self) {
            .all => "ALL",
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
            .fs2 => "FS2",
        };
    }
};

/// FX parameters (20 parameters per FX unit)
pub const FxParams = struct {
    params: [20]u8 = [_]u8{0} ** 20,

    pub fn init() FxParams {
        return FxParams{};
    }

    pub fn get(self: *const FxParams, index: usize) u8 {
        if (index < 20) return self.params[index];
        return 0;
    }

    pub fn set(self: *FxParams, index: usize, value: u8) void {
        if (index < 20) self.params[index] = value;
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

/// Kit Chain - a sequence of kits that can be triggered in order
pub const KitChain = struct {
    name: BoundedString(32) = .{},
    steps: [MAX_STEPS]i16 = [_]i16{-1} ** MAX_STEPS, // Kit indices, -1 = empty
    step_count: u8 = 0,

    pub const MAX_STEPS = 20;

    pub fn init() KitChain {
        return KitChain{};
    }

    pub fn setName(self: *KitChain, new_name: []const u8) void {
        self.name.set(new_name);
    }

    pub fn getName(self: *const KitChain) []const u8 {
        return self.name.get();
    }

    /// Add a kit to the chain
    pub fn addStep(self: *KitChain, kit_index: u8) bool {
        if (self.step_count >= MAX_STEPS) return false;
        self.steps[self.step_count] = kit_index;
        self.step_count += 1;
        return true;
    }

    /// Remove a step at index
    pub fn removeStep(self: *KitChain, index: u8) bool {
        if (index >= self.step_count) return false;
        // Shift steps down
        var i: u8 = index;
        while (i < self.step_count - 1) : (i += 1) {
            self.steps[i] = self.steps[i + 1];
        }
        self.steps[self.step_count - 1] = -1;
        self.step_count -= 1;
        return true;
    }

    /// Move a step up in the chain
    pub fn moveStepUp(self: *KitChain, index: u8) bool {
        if (index == 0 or index >= self.step_count) return false;
        const temp = self.steps[index];
        self.steps[index] = self.steps[index - 1];
        self.steps[index - 1] = temp;
        return true;
    }

    /// Move a step down in the chain
    pub fn moveStepDown(self: *KitChain, index: u8) bool {
        if (index >= self.step_count - 1) return false;
        const temp = self.steps[index];
        self.steps[index] = self.steps[index + 1];
        self.steps[index + 1] = temp;
        return true;
    }

    /// Get kit index at step
    pub fn getStep(self: *const KitChain, index: u8) ?u8 {
        if (index >= self.step_count) return null;
        const step = self.steps[index];
        if (step < 0) return null;
        return @intCast(step);
    }

    /// Clear all steps
    pub fn clear(self: *KitChain) void {
        for (&self.steps) |*step| {
            step.* = -1;
        }
        self.step_count = 0;
    }

    /// Duplicate the chain
    pub fn duplicate(self: *const KitChain) KitChain {
        return self.*;
    }
};

/// Kit Chain Library - collection of all kit chains
pub const KitChainLibrary = struct {
    chains: [MAX_CHAINS]KitChain = undefined,
    count: u8 = 0,

    pub const MAX_CHAINS = 32;

    pub fn init() KitChainLibrary {
        var lib = KitChainLibrary{};
        for (&lib.chains) |*chain| {
            chain.* = KitChain.init();
        }
        return lib;
    }

    /// Add a new chain
    pub fn addChain(self: *KitChainLibrary) ?u8 {
        if (self.count >= MAX_CHAINS) return null;
        const index = self.count;
        self.chains[index] = KitChain.init();
        self.chains[index].setName("New Chain");
        self.count += 1;
        return index;
    }

    /// Delete a chain
    pub fn deleteChain(self: *KitChainLibrary, index: u8) bool {
        if (index >= self.count) return false;
        // Shift chains down
        var i: u8 = index;
        while (i < self.count - 1) : (i += 1) {
            self.chains[i] = self.chains[i + 1];
        }
        self.chains[self.count - 1] = KitChain.init();
        self.count -= 1;
        return true;
    }

    /// Get a chain by index
    pub fn getChain(self: *KitChainLibrary, index: u8) ?*KitChain {
        if (index >= self.count) return null;
        return &self.chains[index];
    }

    /// Duplicate a chain
    pub fn duplicateChain(self: *KitChainLibrary, index: u8) ?u8 {
        if (index >= self.count or self.count >= MAX_CHAINS) return null;
        const new_index = self.count;
        self.chains[new_index] = self.chains[index].duplicate();
        self.count += 1;
        return new_index;
    }
};

// Tests
const testing = @import("std").testing;

test "BoundedString basic operations" {
    var str = BoundedString(32){};
    try testing.expect(str.isEmpty());
    try testing.expectEqual(@as(usize, 0), str.len);

    str.set("Hello");
    try testing.expect(!str.isEmpty());
    try testing.expectEqualStrings("Hello", str.get());

    str.set("World");
    try testing.expectEqualStrings("World", str.get());

    str.clear();
    try testing.expect(str.isEmpty());
}

test "BoundedString truncation" {
    var str = BoundedString(8){};
    str.set("This is a very long string");
    try testing.expectEqual(@as(usize, 8), str.len);
    try testing.expectEqualStrings("This is ", str.get());
}

test "Sample initialization" {
    var sample = Sample.init();
    try testing.expect(!sample.loaded);
    try testing.expectEqual(@as(u32, 0), sample.duration_ms);
    try testing.expectEqualStrings("", sample.getName());
}

test "Pad sample operations" {
    var pad = Pad.init();
    try testing.expect(!pad.has_sample);
    try testing.expect(!pad.has_sub_sample);

    pad.loadSample("Kick", "/path/to/kick.wav");
    try testing.expect(pad.has_sample);
    try testing.expectEqualStrings("Kick", pad.sample.getName());

    pad.loadSubSample("Snare", "/path/to/snare.wav");
    try testing.expect(pad.has_sub_sample);

    pad.clearSample();
    try testing.expect(!pad.has_sample);
    try testing.expect(pad.has_sub_sample); // Sub should still exist

    pad.clearSubSample();
    try testing.expect(!pad.has_sub_sample);
}

test "Kit initialization and pad access" {
    var kit = Kit.init();
    try testing.expectEqualStrings("New Kit", kit.getName());
    try testing.expectEqual(@as(u16, 120), kit.tempo);

    // Check MIDI notes default to OFF (-1)
    try testing.expectEqual(@as(i16, -1), kit.pads[0].midi_note);
    try testing.expectEqual(@as(i16, -1), kit.pads[1].midi_note);
    try testing.expectEqual(@as(i16, -1), kit.pads[14].midi_note);

    // Test pad type checks
    try testing.expect(Kit.isMainPad(0));
    try testing.expect(Kit.isMainPad(8));
    try testing.expect(!Kit.isMainPad(9));

    try testing.expect(Kit.isTriggerPad(9));
    try testing.expect(Kit.isTriggerPad(12));
    try testing.expect(!Kit.isTriggerPad(13));

    try testing.expect(Kit.isFootswitchPad(13));
    try testing.expect(Kit.isFootswitchPad(14));
    try testing.expect(!Kit.isFootswitchPad(12));
}

test "Kit display names" {
    try testing.expectEqualStrings("PAD 1", Kit.getPadDisplayName(0));
    try testing.expectEqualStrings("PAD 9", Kit.getPadDisplayName(8));
    try testing.expectEqualStrings("TRIG 1", Kit.getPadDisplayName(9));
    try testing.expectEqualStrings("TRIG 4", Kit.getPadDisplayName(12));
    try testing.expectEqualStrings("FS 1", Kit.getPadDisplayName(13));
    try testing.expectEqualStrings("FS 2", Kit.getPadDisplayName(14));
    try testing.expectEqualStrings("?", Kit.getPadDisplayName(15));
}

test "Project kit management" {
    var project = Project.init();
    try testing.expectEqual(@as(u8, 1), project.kit_count);

    try testing.expect(project.addKit());
    try testing.expectEqual(@as(u8, 2), project.kit_count);

    try testing.expect(project.duplicateKit(0));
    try testing.expectEqual(@as(u8, 3), project.kit_count);

    try testing.expect(project.deleteKit(2));
    try testing.expectEqual(@as(u8, 2), project.kit_count);

    // Can't delete the last kit
    try testing.expect(project.deleteKit(1));
    try testing.expect(!project.deleteKit(0));
    try testing.expectEqual(@as(u8, 1), project.kit_count);
}

test "SampleLibrary operations" {
    var library = SampleLibrary.init();
    try testing.expectEqual(@as(u16, 0), library.count);

    try testing.expect(library.addSample("Kick", "/samples/kick.wav"));
    try testing.expectEqual(@as(u16, 1), library.count);

    // addOrFind should return existing
    const idx1 = library.addOrFind("Snare", "/samples/snare.wav");
    try testing.expect(idx1 != null);
    try testing.expectEqual(@as(u16, 2), library.count);

    const idx2 = library.addOrFind("Snare Dup", "/samples/snare.wav");
    try testing.expect(idx2 != null);
    try testing.expectEqual(idx1.?, idx2.?); // Same path, same index
    try testing.expectEqual(@as(u16, 2), library.count); // Count unchanged

    // Find by path
    try testing.expect(library.findByPath("/samples/kick.wav") != null);
    try testing.expect(library.findByPath("/samples/nonexistent.wav") == null);
}

test "KitChain operations" {
    var chain = KitChain.init();
    try testing.expectEqual(@as(u8, 0), chain.step_count);

    try testing.expect(chain.addStep(0));
    try testing.expect(chain.addStep(1));
    try testing.expect(chain.addStep(2));
    try testing.expectEqual(@as(u8, 3), chain.step_count);

    try testing.expectEqual(@as(u8, 0), chain.getStep(0).?);
    try testing.expectEqual(@as(u8, 2), chain.getStep(2).?);
    try testing.expect(chain.getStep(3) == null);

    // Move step
    try testing.expect(chain.moveStepDown(0));
    try testing.expectEqual(@as(u8, 1), chain.getStep(0).?);
    try testing.expectEqual(@as(u8, 0), chain.getStep(1).?);

    // Remove step
    try testing.expect(chain.removeStep(1));
    try testing.expectEqual(@as(u8, 2), chain.step_count);

    chain.clear();
    try testing.expectEqual(@as(u8, 0), chain.step_count);
}
