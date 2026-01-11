//! In-memory storage layer for SPD-SX data
//! Equivalent to Java DAO Mock classes

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const Kit = types.Kit;
const Wave = types.Wave;
const TagListEntry = types.TagListEntry;
const KitChain = types.KitChain;

/// Storage for kits
pub const KitStorage = struct {
    kits: std.ArrayListUnmanaged(Kit),
    allocator: Allocator,

    pub fn init(allocator: Allocator) KitStorage {
        return .{
            .kits = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KitStorage) void {
        self.kits.deinit(self.allocator);
    }

    pub fn insert(self: *KitStorage, kit: Kit) !void {
        try self.kits.append(self.allocator, kit);
    }

    pub fn insertAt(self: *KitStorage, index: usize, kit: Kit) !void {
        try self.kits.insert(self.allocator, index, kit);
    }

    pub fn delete(self: *KitStorage, index: usize) void {
        if (index < self.kits.items.len) {
            _ = self.kits.orderedRemove(index);
        }
    }

    pub fn get(self: *const KitStorage, index: usize) ?*const Kit {
        if (index < self.kits.items.len) {
            return &self.kits.items[index];
        }
        return null;
    }

    pub fn getMut(self: *KitStorage, index: usize) ?*Kit {
        if (index < self.kits.items.len) {
            return &self.kits.items[index];
        }
        return null;
    }

    pub fn getAll(self: *const KitStorage) []const Kit {
        return self.kits.items;
    }

    pub fn getAllMut(self: *KitStorage) []Kit {
        return self.kits.items;
    }

    pub fn size(self: *const KitStorage) usize {
        return self.kits.items.len;
    }

    pub fn clear(self: *KitStorage) void {
        self.kits.clearRetainingCapacity();
    }

    /// Swap two kits at given indices
    pub fn swap(self: *KitStorage, idx_a: usize, idx_b: usize) void {
        if (idx_a < self.kits.items.len and idx_b < self.kits.items.len) {
            const tmp = self.kits.items[idx_a];
            self.kits.items[idx_a] = self.kits.items[idx_b];
            self.kits.items[idx_b] = tmp;
        }
    }

    /// Rotate kits in range by given amount
    pub fn rotate(self: *KitStorage, start: usize, end: usize, amount: i32) void {
        if (start >= end or end > self.kits.items.len) return;

        const len = end - start;
        if (len == 0) return;

        // Normalize amount to positive
        var shift: usize = undefined;
        if (amount >= 0) {
            shift = @intCast(@mod(amount, @as(i32, @intCast(len))));
        } else {
            const abs_amt: usize = @intCast(-amount);
            shift = len - @mod(abs_amt, len);
        }

        if (shift == 0) return;

        // Simple rotation using reversal algorithm
        const slice = self.kits.items[start..end];
        std.mem.reverse(Kit, slice[0 .. len - shift]);
        std.mem.reverse(Kit, slice[len - shift .. len]);
        std.mem.reverse(Kit, slice);
    }

    /// Renumber all kit IDs based on current order
    pub fn renumberKitIds(self: *KitStorage) void {
        for (self.kits.items, 0..) |*kit, i| {
            kit.kit_id = @intCast(i);
        }
    }
};

/// Storage for waves
pub const WaveStorage = struct {
    waves: std.ArrayListUnmanaged(Wave),
    allocator: Allocator,
    last_wave_id: u32 = 0,

    pub fn init(allocator: Allocator) WaveStorage {
        return .{
            .waves = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WaveStorage) void {
        self.waves.deinit(self.allocator);
    }

    pub fn insert(self: *WaveStorage, wave: Wave) !void {
        try self.waves.append(self.allocator, wave);
    }

    pub fn delete(self: *WaveStorage, index: usize) void {
        if (index < self.waves.items.len) {
            _ = self.waves.orderedRemove(index);
        }
    }

    pub fn get(self: *const WaveStorage, index: usize) ?*const Wave {
        if (index < self.waves.items.len) {
            return &self.waves.items[index];
        }
        return null;
    }

    pub fn getMut(self: *WaveStorage, index: usize) ?*Wave {
        if (index < self.waves.items.len) {
            return &self.waves.items[index];
        }
        return null;
    }

    pub fn getAll(self: *const WaveStorage) []const Wave {
        return self.waves.items;
    }

    pub fn getAllMut(self: *WaveStorage) []Wave {
        return self.waves.items;
    }

    pub fn size(self: *const WaveStorage) usize {
        return self.waves.items.len;
    }

    pub fn clear(self: *WaveStorage) void {
        self.waves.clearRetainingCapacity();
        self.last_wave_id = 0;
    }

    pub fn setLastWaveId(self: *WaveStorage, id: u32) void {
        self.last_wave_id = id;
    }

    pub fn getLastWaveId(self: *const WaveStorage) u32 {
        return self.last_wave_id;
    }
};

/// Storage for tags
pub const TagStorage = struct {
    tags: std.ArrayListUnmanaged(TagListEntry),
    allocator: Allocator,

    pub fn init(allocator: Allocator) TagStorage {
        return .{
            .tags = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TagStorage) void {
        self.tags.deinit(self.allocator);
    }

    pub fn insert(self: *TagStorage, tag: TagListEntry) !void {
        try self.tags.append(self.allocator, tag);
    }

    pub fn get(self: *const TagStorage, index: usize) ?*const TagListEntry {
        if (index < self.tags.items.len) {
            return &self.tags.items[index];
        }
        return null;
    }

    pub fn getMut(self: *TagStorage, index: usize) ?*TagListEntry {
        if (index < self.tags.items.len) {
            return &self.tags.items[index];
        }
        return null;
    }

    pub fn getAll(self: *const TagStorage) []const TagListEntry {
        return self.tags.items;
    }

    pub fn getAllMut(self: *TagStorage) []TagListEntry {
        return self.tags.items;
    }

    pub fn size(self: *const TagStorage) usize {
        return self.tags.items.len;
    }

    pub fn clear(self: *TagStorage) void {
        self.tags.clearRetainingCapacity();
    }

    pub fn setList(self: *TagStorage, new_tags: []const TagListEntry) !void {
        self.clear();
        for (new_tags) |tag| {
            try self.insert(tag);
        }
    }
};

/// Storage for kit chains
pub const KitChainStorage = struct {
    chains: std.ArrayListUnmanaged(KitChain),
    allocator: Allocator,
    has_changes: bool = false,

    pub fn init(allocator: Allocator) KitChainStorage {
        return .{
            .chains = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *KitChainStorage) void {
        self.chains.deinit(self.allocator);
    }

    pub fn insert(self: *KitChainStorage, chain: KitChain) !void {
        try self.chains.append(self.allocator, chain);
    }

    pub fn get(self: *const KitChainStorage, index: usize) ?*const KitChain {
        if (index < self.chains.items.len) {
            return &self.chains.items[index];
        }
        return null;
    }

    pub fn getMut(self: *KitChainStorage, index: usize) ?*KitChain {
        if (index < self.chains.items.len) {
            return &self.chains.items[index];
        }
        return null;
    }

    pub fn getAll(self: *const KitChainStorage) []const KitChain {
        return self.chains.items;
    }

    pub fn getAllMut(self: *KitChainStorage) []KitChain {
        return self.chains.items;
    }

    pub fn size(self: *const KitChainStorage) usize {
        return self.chains.items.len;
    }

    pub fn clear(self: *KitChainStorage) void {
        self.chains.clearRetainingCapacity();
    }

    /// Update kit chain references when kit list changes
    pub fn updateKitReferences(self: *KitChainStorage, kit_storage: *KitStorage) void {
        self.has_changes = true;

        for (self.chains.items) |*chain| {
            for (&chain.steps) |*step| {
                if (step.* != -1) {
                    // Find new index for kit with old ID
                    const kit_id: u32 = @intCast(step.*);
                    var found = false;
                    for (kit_storage.getAll(), 0..) |kit, i| {
                        if (kit.kit_id == kit_id) {
                            step.* = @intCast(i);
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        step.* = -1;
                    }
                }
            }
        }

        kit_storage.renumberKitIds();
    }
};

/// Main data store combining all storage types
pub const DataStore = struct {
    kits: KitStorage,
    waves: WaveStorage,
    tags: TagStorage,
    kit_chains: KitChainStorage,
    allocator: Allocator,

    pub fn init(allocator: Allocator) DataStore {
        return .{
            .kits = KitStorage.init(allocator),
            .waves = WaveStorage.init(allocator),
            .tags = TagStorage.init(allocator),
            .kit_chains = KitChainStorage.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DataStore) void {
        self.kits.deinit();
        self.waves.deinit();
        self.tags.deinit();
        self.kit_chains.deinit();
    }

    pub fn clear(self: *DataStore) void {
        self.kits.clear();
        self.waves.clear();
        self.tags.clear();
        self.kit_chains.clear();
    }
};

// Tests
test "KitStorage basic operations" {
    var storage = KitStorage.init(std.testing.allocator);
    defer storage.deinit();

    var kit = Kit.init();
    kit.kit_id = 1;
    try storage.insert(kit);

    try std.testing.expectEqual(@as(usize, 1), storage.size());

    const retrieved = storage.get(0);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(u32, 1), retrieved.?.kit_id);

    storage.delete(0);
    try std.testing.expectEqual(@as(usize, 0), storage.size());
}

test "WaveStorage basic operations" {
    var storage = WaveStorage.init(std.testing.allocator);
    defer storage.deinit();

    var wave = Wave.init();
    wave.wave_id = 42;
    try storage.insert(wave);

    try std.testing.expectEqual(@as(usize, 1), storage.size());

    const retrieved = storage.get(0);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(u32, 42), retrieved.?.wave_id);
}

test "DataStore initialization" {
    var store = DataStore.init(std.testing.allocator);
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 0), store.kits.size());
    try std.testing.expectEqual(@as(usize, 0), store.waves.size());
    try std.testing.expectEqual(@as(usize, 0), store.tags.size());
    try std.testing.expectEqual(@as(usize, 0), store.kit_chains.size());
}
