//! Core data types for SPD-SX Editor
//! Zig port of the Java business classes

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Maximum number of pads per kit
pub const MAX_PADS = 15;

/// Maximum name length for kit names
pub const KIT_NAME_LENGTH = 8;

/// Maximum sub-name length for kits
pub const KIT_SUBNAME_LENGTH = 16;

/// Maximum name length for waves
pub const WAVE_NAME_LENGTH = 12;

/// Maximum name length for tags
pub const TAG_NAME_LENGTH = 12;

/// Maximum name length for kit chains
pub const KITCHAIN_NAME_LENGTH = 10;

/// Maximum steps in a kit chain
pub const KITCHAIN_MAX_STEPS = 20;

/// Maximum FX parameters
pub const FX_PARAM_COUNT = 20;

/// Pad configuration - represents a single pad in a kit
pub const Pad = struct {
    wv: i32 = -1,
    wv_level: u8 = 100,
    wv_pan: u8 = 15,
    play_mode: u8 = 0,
    out_asgn: u8 = 0,
    mute_grp: u8 = 0,
    tempo_sync: u8 = 0,
    pad_midi_ch: i8 = -1,
    note_num: i16 = -1,
    midi_ctrl: u8 = 0,
    loop: u8 = 0,
    trig_type: u8 = 0,
    gate_time: i8 = -1,
    dynamics: u8 = 1,
    voice_asgn: u8 = 1,
    reverse: u8 = 0,
    sub_wv: i32 = -1,
    sub_wv_level: u8 = 100,
    sub_wv_pan: u8 = 15,

    /// Initialize pad with default values
    pub fn init() Pad {
        return .{};
    }

    /// Reset pad to default values
    pub fn reset(self: *Pad) void {
        self.* = Pad.init();
    }

    /// Get pan text representation (L15 to R15, CENTER)
    pub fn getPanText(pan_value: u8) []const u8 {
        const pan_texts = [_][]const u8{
            "L15", "L14", "L13", "L12", "L11", "L10", "L9", "L8",
            "L7",  "L6",  "L5",  "L4",  "L3",  "L2",  "L1", "CENTER",
            "R1",  "R2",  "R3",  "R4",  "R5",  "R6",  "R7", "R8",
            "R9",  "R10", "R11", "R12", "R13", "R14", "R15",
        };
        if (pan_value <= 30) {
            return pan_texts[pan_value];
        }
        return "?";
    }

    /// Get MIDI channel text (GLOBAL or 1-16)
    pub fn getMidiChText(ch: i8) []const u8 {
        if (ch == -1) return "GLOBAL";
        if (ch >= 0 and ch < 16) {
            const ch_texts = [_][]const u8{
                "1", "2", "3", "4", "5", "6", "7", "8",
                "9", "10", "11", "12", "13", "14", "15", "16",
            };
            return ch_texts[@intCast(ch)];
        }
        return "?";
    }
};

/// Kit configuration - represents a complete drum kit
pub const Kit = struct {
    kit_id: u32 = 0,
    level: u8 = 100,
    tempo: u16 = 1200,

    // Kit name (8 characters)
    nm: [KIT_NAME_LENGTH]u8 = [_]u8{ 78, 101, 119, 32, 75, 105, 116, 0 }, // "New Kit"

    // Kit sub-name (16 characters)
    sub_nm: [KIT_SUBNAME_LENGTH]u8 = [_]u8{0} ** KIT_SUBNAME_LENGTH,

    // FX2 assignment
    fx2_asgn: u8 = 0,

    // Link pads
    link_pad0: i8 = -1,
    link_pad1: i8 = -1,

    // FX1 settings
    fx1_sw: u8 = 1,
    fx1_type: u8 = 0,
    fx1_prm: [FX_PARAM_COUNT]u8 = [_]u8{0} ** FX_PARAM_COUNT,

    // FX2 settings
    fx2_sw: u8 = 1,
    fx2_type: u8 = 0,
    fx2_prm: [FX_PARAM_COUNT]u8 = [_]u8{0} ** FX_PARAM_COUNT,

    // Pads
    pads: [MAX_PADS]Pad = [_]Pad{Pad.init()} ** MAX_PADS,

    /// Initialize kit with default values
    pub fn init() Kit {
        var kit = Kit{};
        kit.fx1_prm[0] = 9; // Default FX1 param 0
        return kit;
    }

    /// Reset kit to default values
    pub fn reset(self: *Kit) void {
        self.* = Kit.init();
    }

    /// Reset all pads to default values
    pub fn resetPads(self: *Kit) void {
        for (&self.pads) |*pad| {
            pad.reset();
        }
    }

    /// Get kit name as string
    pub fn getName(self: *const Kit, allocator: Allocator) ![]u8 {
        const encoding = @import("encoding.zig");
        return encoding.decodeString(&self.nm, allocator);
    }

    /// Set kit name from string
    pub fn setName(self: *Kit, name: []const u8) void {
        const encoding = @import("encoding.zig");
        encoding.encodeString(name, &self.nm);
    }

    /// Get kit sub-name as string
    pub fn getSubName(self: *const Kit, allocator: Allocator) ![]u8 {
        const encoding = @import("encoding.zig");
        return encoding.decodeString(&self.sub_nm, allocator);
    }

    /// Set kit sub-name from string
    pub fn setSubName(self: *Kit, name: []const u8) void {
        const encoding = @import("encoding.zig");
        encoding.encodeString(name, &self.sub_nm);
    }

    /// Duplicate kit data from another kit
    pub fn copyFrom(self: *Kit, other: *const Kit) void {
        self.level = other.level;
        self.tempo = other.tempo;
        self.nm = other.nm;
        self.sub_nm = other.sub_nm;
        self.fx2_asgn = other.fx2_asgn;
        self.link_pad0 = other.link_pad0;
        self.link_pad1 = other.link_pad1;
        self.fx1_sw = other.fx1_sw;
        self.fx1_type = other.fx1_type;
        self.fx1_prm = other.fx1_prm;
        self.fx2_sw = other.fx2_sw;
        self.fx2_type = other.fx2_type;
        self.fx2_prm = other.fx2_prm;
        self.pads = other.pads;
    }
};

/// Wave/Sample configuration
pub const Wave = struct {
    wave_id: u32 = 0,

    // Wave name (12 characters)
    nm: [WAVE_NAME_LENGTH]u8 = [_]u8{0} ** WAVE_NAME_LENGTH,

    // File path
    path: [256]u8 = [_]u8{0} ** 256,
    path_len: usize = 0,

    // Tag assignment
    tag: u8 = 1,

    // Tempo/timing info
    tempo: u16 = 0,
    beat: u8 = 0,
    measure: u8 = 0,
    start: u32 = 0,
    end: u32 = 0,

    // Modification flag
    modified: bool = false,

    /// Initialize wave with default values
    pub fn init() Wave {
        return .{};
    }

    /// Get wave name as string
    pub fn getName(self: *const Wave, allocator: Allocator) ![]u8 {
        const encoding = @import("encoding.zig");
        return encoding.decodeString(&self.nm, allocator);
    }

    /// Set wave name from string
    pub fn setName(self: *Wave, name: []const u8) void {
        const encoding = @import("encoding.zig");
        encoding.encodeString(name, &self.nm);
    }

    /// Get path as string slice
    pub fn getPath(self: *const Wave) []const u8 {
        return self.path[0..self.path_len];
    }

    /// Set path from string
    pub fn setPath(self: *Wave, path_str: []const u8) void {
        const len = @min(path_str.len, self.path.len);
        @memcpy(self.path[0..len], path_str[0..len]);
        self.path_len = len;
    }
};

/// Tag list entry
pub const TagListEntry = struct {
    // Tag name (12 characters)
    nm: [TAG_NAME_LENGTH]u8 = [_]u8{0} ** TAG_NAME_LENGTH,

    // Order
    order: u8 = 0,

    /// Initialize tag with default values
    pub fn init() TagListEntry {
        return .{};
    }

    /// Get tag name as string
    pub fn getName(self: *const TagListEntry, allocator: Allocator) ![]u8 {
        const encoding = @import("encoding.zig");
        return encoding.decodeString(&self.nm, allocator);
    }

    /// Set tag name from string
    pub fn setName(self: *TagListEntry, name: []const u8) void {
        const encoding = @import("encoding.zig");
        encoding.encodeString(name, &self.nm);
    }
};

/// Kit Chain configuration
pub const KitChain = struct {
    // Chain name (10 characters)
    nm: [KITCHAIN_NAME_LENGTH]u8 = [_]u8{0} ** KITCHAIN_NAME_LENGTH,

    // Steps (kit indices, -1 for empty)
    steps: [KITCHAIN_MAX_STEPS]i32 = [_]i32{-1} ** KITCHAIN_MAX_STEPS,

    /// Initialize kit chain with default values
    pub fn init() KitChain {
        return .{};
    }

    /// Get chain name as string
    pub fn getName(self: *const KitChain, allocator: Allocator) ![]u8 {
        const encoding = @import("encoding.zig");
        return encoding.decodeString(&self.nm, allocator);
    }

    /// Set chain name from string
    pub fn setName(self: *KitChain, name: []const u8) void {
        const encoding = @import("encoding.zig");
        encoding.encodeString(name, &self.nm);
    }

    /// Get step at index
    pub fn getStep(self: *const KitChain, index: usize) i32 {
        if (index < KITCHAIN_MAX_STEPS) {
            return self.steps[index];
        }
        return -1;
    }

    /// Set step at index
    pub fn setStep(self: *KitChain, index: usize, kit_index: i32) void {
        if (index < KITCHAIN_MAX_STEPS) {
            self.steps[index] = kit_index;
        }
    }
};

// Tests
test "Pad initialization" {
    const pad = Pad.init();
    try std.testing.expectEqual(@as(i32, -1), pad.wv);
    try std.testing.expectEqual(@as(u8, 100), pad.wv_level);
    try std.testing.expectEqual(@as(u8, 15), pad.wv_pan);
}

test "Kit initialization" {
    const kit = Kit.init();
    try std.testing.expectEqual(@as(u8, 100), kit.level);
    try std.testing.expectEqual(@as(u16, 1200), kit.tempo);
    try std.testing.expectEqual(@as(u8, 9), kit.fx1_prm[0]);
}

test "Pan text conversion" {
    try std.testing.expectEqualStrings("L15", Pad.getPanText(0));
    try std.testing.expectEqualStrings("CENTER", Pad.getPanText(15));
    try std.testing.expectEqualStrings("R15", Pad.getPanText(30));
}
