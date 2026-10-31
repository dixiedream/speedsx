//! Entry point for CI and `zig build test-core`: pure unit tests only (no SDL, no fixtures).
const _models = @import("models.zig");
const _file_io = @import("file_io.zig");
const _config = @import("config.zig");
const _font = @import("font.zig");
const _encoding = @import("cli/encoding.zig");
const _types = @import("cli/types.zig");
const _paths = @import("cli/paths.zig");
const _storage = @import("cli/storage.zig");
const _xml = @import("cli/xml.zig");

comptime {
    _ = _models;
    _ = _file_io;
    _ = _config;
    _ = _font;
    _ = _encoding;
    _ = _types;
    _ = _paths;
    _ = _storage;
    _ = _xml;
}
