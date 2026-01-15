/// Cross-platform audio playback using SDL2
/// Supports WAV and AIFF file playback on Linux, macOS, and Windows
const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;

/// Audio playback errors
pub const AudioError = error{
    InitFailed,
    DeviceOpenFailed,
    FileLoadFailed,
    FileNotFound,
    UnsupportedFormat,
    OutOfMemory,
};

/// Audio sample data
pub const AudioSample = struct {
    data: ?[*]u8 = null,
    length: u32 = 0,
    spec: c.SDL_AudioSpec = undefined,
    loaded: bool = false,

    pub fn deinit(self: *AudioSample) void {
        if (self.data) |ptr| {
            c.SDL_FreeWAV(ptr);
            self.data = null;
        }
        self.loaded = false;
        self.length = 0;
    }
};

/// Audio player state
pub const AudioPlayer = struct {
    device_id: c.SDL_AudioDeviceID = 0,
    current_sample: ?*AudioSample = null,
    playback_position: u32 = 0,
    is_playing: bool = false,
    is_initialized: bool = false,
    volume: f32 = 1.0,
    audio_spec: c.SDL_AudioSpec = undefined,

    /// Initialize the audio player
    pub fn init() AudioPlayer {
        var player = AudioPlayer{};

        // Initialize SDL audio subsystem if not already done
        if (c.SDL_WasInit(c.SDL_INIT_AUDIO) == 0) {
            if (c.SDL_InitSubSystem(c.SDL_INIT_AUDIO) != 0) {
                std.debug.print("Failed to initialize SDL audio: {s}\n", .{c.SDL_GetError()});
                return player;
            }
        }

        // Set up desired audio spec
        player.audio_spec = std.mem.zeroes(c.SDL_AudioSpec);
        player.audio_spec.freq = 44100;
        player.audio_spec.format = c.AUDIO_S16LSB;
        player.audio_spec.channels = 2;
        player.audio_spec.samples = 4096;
        player.audio_spec.callback = audioCallback;
        player.audio_spec.userdata = @ptrCast(&player);

        // Open audio device
        player.device_id = c.SDL_OpenAudioDevice(
            null, // Use default device
            0, // Playback device (not capture)
            &player.audio_spec,
            null, // Don't allow format changes
            0,
        );

        if (player.device_id == 0) {
            std.debug.print("Failed to open audio device: {s}\n", .{c.SDL_GetError()});
            return player;
        }

        player.is_initialized = true;
        return player;
    }

    /// Deinitialize the audio player
    pub fn deinit(self: *AudioPlayer) void {
        self.stop();
        if (self.device_id != 0) {
            c.SDL_CloseAudioDevice(self.device_id);
            self.device_id = 0;
        }
        self.is_initialized = false;
    }

    /// Load a WAV or AIFF file into an AudioSample
    pub fn loadFile(self: *AudioPlayer, path: []const u8, sample: *AudioSample) AudioError!void {
        _ = self;

        // Ensure path is null-terminated for SDL
        var path_buf: [512]u8 = undefined;
        if (path.len >= path_buf.len) return AudioError.FileNotFound;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        // Free any existing data
        sample.deinit();

        // Load WAV file
        var spec: c.SDL_AudioSpec = undefined;
        var audio_buf: [*c]u8 = undefined;
        var audio_len: u32 = undefined;

        if (c.SDL_LoadWAV(&path_buf, &spec, &audio_buf, &audio_len) == null) {
            std.debug.print("Failed to load audio file: {s}\n", .{c.SDL_GetError()});
            return AudioError.FileLoadFailed;
        }

        sample.data = audio_buf;
        sample.length = audio_len;
        sample.spec = spec;
        sample.loaded = true;
    }

    /// Play an audio sample
    pub fn play(self: *AudioPlayer, sample: *AudioSample) void {
        if (!self.is_initialized or !sample.loaded) return;

        // Stop any current playback
        self.stop();

        // Set up new playback
        self.current_sample = sample;
        self.playback_position = 0;
        self.is_playing = true;

        // Start playback
        c.SDL_PauseAudioDevice(self.device_id, 0);
    }

    /// Play a file directly (convenience function)
    pub fn playFile(self: *AudioPlayer, path: []const u8, sample: *AudioSample) AudioError!void {
        try self.loadFile(path, sample);
        self.play(sample);
    }

    /// Stop playback
    pub fn stop(self: *AudioPlayer) void {
        if (!self.is_initialized) return;

        c.SDL_PauseAudioDevice(self.device_id, 1);
        self.is_playing = false;
        self.current_sample = null;
        self.playback_position = 0;
    }

    /// Pause playback
    pub fn pause(self: *AudioPlayer) void {
        if (!self.is_initialized) return;
        c.SDL_PauseAudioDevice(self.device_id, 1);
        self.is_playing = false;
    }

    /// Resume playback
    pub fn unpause(self: *AudioPlayer) void {
        if (!self.is_initialized or self.current_sample == null) return;
        c.SDL_PauseAudioDevice(self.device_id, 0);
        self.is_playing = true;
    }

    /// Set volume (0.0 to 1.0)
    pub fn setVolume(self: *AudioPlayer, volume: f32) void {
        self.volume = std.math.clamp(volume, 0.0, 1.0);
    }

    /// Check if currently playing
    pub fn isPlaying(self: *const AudioPlayer) bool {
        return self.is_playing and self.current_sample != null;
    }
};

/// SDL audio callback function (uses C calling convention for SDL compatibility)
fn audioCallback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) callconv(std.builtin.CallingConvention.c) void {
    const player: *AudioPlayer = @ptrCast(@alignCast(userdata));

    // Clear the stream
    @memset(stream[0..@intCast(len)], 0);

    if (!player.is_playing) return;

    const sample = player.current_sample orelse return;
    if (!sample.loaded) return;

    const sample_data = sample.data orelse return;

    // Calculate how much data to copy
    const remaining = sample.length - player.playback_position;
    const to_copy = @min(remaining, @as(u32, @intCast(len)));

    if (to_copy == 0) {
        // End of sample
        player.is_playing = false;
        player.playback_position = 0;
        return;
    }

    // Mix audio with volume
    const src = sample_data + player.playback_position;
    const volume_sdl: u8 = @intFromFloat(player.volume * 128.0);

    c.SDL_MixAudioFormat(
        stream,
        src,
        sample.spec.format,
        to_copy,
        @intCast(volume_sdl),
    );

    player.playback_position += to_copy;
}

/// Check if a file is a supported audio format
pub fn isSupportedAudioFile(path: []const u8) bool {
    const lower_extensions = [_][]const u8{ ".wav", ".aiff", ".aif" };
    const upper_extensions = [_][]const u8{ ".WAV", ".AIFF", ".AIF" };

    for (lower_extensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }

    for (upper_extensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) return true;
    }

    return false;
}

/// Get filename from path
pub fn getFilename(path: []const u8) []const u8 {
    var i = path.len;
    while (i > 0) {
        i -= 1;
        if (path[i] == '/' or path[i] == '\\') {
            return path[i + 1 ..];
        }
    }
    return path;
}

/// Scan a directory for audio files
pub fn scanDirectoryForAudioFiles(
    dir_path: []const u8,
    file_callback: *const fn (name: []const u8, full_path: []const u8) void,
) !void {
    var path_buf: [512]u8 = undefined;

    const dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => return error.FileNotFound,
            error.AccessDenied => return error.AccessDenied,
            else => return error.AccessDenied,
        }
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        if (isSupportedAudioFile(entry.name)) {
            // Build full path
            const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.name }) catch continue;
            file_callback(entry.name, full_path);
        }
    }
}

// Tests
test "audio format detection" {
    try std.testing.expect(isSupportedAudioFile("test.wav"));
    try std.testing.expect(isSupportedAudioFile("test.WAV"));
    try std.testing.expect(isSupportedAudioFile("test.aiff"));
    try std.testing.expect(isSupportedAudioFile("test.aif"));
    try std.testing.expect(!isSupportedAudioFile("test.mp3"));
    try std.testing.expect(!isSupportedAudioFile("test.txt"));
}

test "get filename" {
    try std.testing.expectEqualStrings("file.wav", getFilename("/path/to/file.wav"));
    try std.testing.expectEqualStrings("file.wav", getFilename("file.wav"));
    try std.testing.expectEqualStrings("file.wav", getFilename("C:\\path\\to\\file.wav"));
}
