/// Cross-platform audio playback using SDL2
/// Supports WAV file playback on Linux, macOS, and Windows
/// Uses SDL_QueueAudio for simplicity (no callback required)
const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;
const file_io = @import("file_io.zig");

/// Audio playback errors
pub const AudioError = error{
    InitFailed,
    DeviceOpenFailed,
    FileLoadFailed,
    FileNotFound,
    UnsupportedFormat,
    OutOfMemory,
    ConversionFailed,
};

/// Audio sample data with converted buffer
pub const AudioSample = struct {
    // Original data from SDL_LoadWAV
    original_data: ?[*]u8 = null,
    original_length: u32 = 0,
    original_spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec),

    // Converted data for playback (may be allocated by us or point to original)
    converted_data: ?[]u8 = null,
    converted_length: u32 = 0,
    owns_converted_data: bool = false, // True if we allocated converted_data

    loaded: bool = false,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *AudioSample) void {
        // Free converted data only if we allocated it
        if (self.owns_converted_data) {
            if (self.converted_data) |data| {
                if (self.allocator) |alloc| {
                    alloc.free(data);
                }
            }
        }
        self.converted_data = null;
        self.owns_converted_data = false;

        // Free original SDL data
        if (self.original_data) |ptr| {
            c.SDL_FreeWAV(ptr);
            self.original_data = null;
        }

        self.loaded = false;
        self.original_length = 0;
        self.converted_length = 0;
    }
};

/// Audio player state using SDL_QueueAudio
pub const AudioPlayer = struct {
    device_id: c.SDL_AudioDeviceID = 0,
    is_initialized: bool = false,
    volume: u8 = 128, // SDL volume 0-128
    device_spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec),
    allocator: std.mem.Allocator,

    /// Initialize the audio player
    pub fn init(allocator: std.mem.Allocator) AudioPlayer {
        var player = AudioPlayer{
            .allocator = allocator,
        };

        // Initialize SDL audio subsystem if not already done
        if (c.SDL_WasInit(c.SDL_INIT_AUDIO) == 0) {
            if (c.SDL_InitSubSystem(c.SDL_INIT_AUDIO) != 0) {
                std.debug.print("Failed to initialize SDL audio: {s}\n", .{c.SDL_GetError()});
                return player;
            }
        }

        // Set up desired audio spec (no callback - we'll use SDL_QueueAudio)
        var desired: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
        desired.freq = 44100;
        desired.format = c.AUDIO_S16LSB;
        desired.channels = 2;
        desired.samples = 4096;
        desired.callback = null; // No callback - using queue mode
        desired.userdata = null;

        var obtained: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);

        // Open audio device
        player.device_id = c.SDL_OpenAudioDevice(
            null, // Use default device
            0, // Playback device (not capture)
            &desired,
            &obtained,
            0, // Don't allow format changes
        );

        if (player.device_id == 0) {
            std.debug.print("Failed to open audio device: {s}\n", .{c.SDL_GetError()});
            return player;
        }

        player.device_spec = obtained;
        player.is_initialized = true;

        // Start the device (unpaused so it can play queued audio)
        c.SDL_PauseAudioDevice(player.device_id, 0);

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

    /// Load a WAV file into an AudioSample
    pub fn loadFile(self: *AudioPlayer, path: []const u8, sample: *AudioSample) AudioError!void {
        if (!self.is_initialized) return AudioError.InitFailed;

        // Ensure path is null-terminated for SDL
        var path_buf: [512:0]u8 = undefined;
        if (path.len >= path_buf.len) return AudioError.FileNotFound;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        // Free any existing data
        sample.deinit();
        sample.allocator = self.allocator;

        // Load WAV file using SDL_LoadWAV_RW (the actual function, not the macro)
        const rw = c.SDL_RWFromFile(&path_buf, "rb");
        if (rw == null) {
            std.debug.print("Failed to open file: {s}\n", .{c.SDL_GetError()});
            return AudioError.FileNotFound;
        }

        var file_spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
        var audio_buf: [*c]u8 = undefined;
        var audio_len: u32 = undefined;

        const result = c.SDL_LoadWAV_RW(rw, 1, &file_spec, &audio_buf, &audio_len);
        if (result == null) {
            std.debug.print("Failed to load WAV: {s}\n", .{c.SDL_GetError()});
            return AudioError.FileLoadFailed;
        }

        sample.original_data = audio_buf;
        sample.original_length = audio_len;
        sample.original_spec = file_spec;

        // Convert audio to device format if needed
        try self.convertSample(sample);

        sample.loaded = true;
    }

    /// Convert sample to device format
    fn convertSample(self: *AudioPlayer, sample: *AudioSample) AudioError!void {
        const src_data = sample.original_data orelse return AudioError.FileLoadFailed;

        // Check if conversion is needed
        const needs_conversion = sample.original_spec.freq != self.device_spec.freq or
            sample.original_spec.format != self.device_spec.format or
            sample.original_spec.channels != self.device_spec.channels;

        if (!needs_conversion) {
            // No conversion needed - just reference original data
            sample.converted_data = src_data[0..sample.original_length];
            sample.converted_length = sample.original_length;
            sample.owns_converted_data = false;
            return;
        }

        // Build audio conversion
        var cvt: c.SDL_AudioCVT = undefined;
        const build_result = c.SDL_BuildAudioCVT(
            &cvt,
            sample.original_spec.format,
            sample.original_spec.channels,
            sample.original_spec.freq,
            self.device_spec.format,
            self.device_spec.channels,
            self.device_spec.freq,
        );

        if (build_result < 0) {
            std.debug.print("Failed to build audio converter: {s}\n", .{c.SDL_GetError()});
            // Fall back to using original data (might sound wrong but won't crash)
            sample.converted_data = src_data[0..sample.original_length];
            sample.converted_length = sample.original_length;
            sample.owns_converted_data = false;
            return;
        }

        if (build_result == 0) {
            // No conversion needed
            sample.converted_data = src_data[0..sample.original_length];
            sample.converted_length = sample.original_length;
            sample.owns_converted_data = false;
            return;
        }

        // Allocate buffer for converted audio
        const needed_len: usize = @intCast(@as(u64, sample.original_length) * @as(u64, @intCast(cvt.len_mult)));
        const conv_buf = self.allocator.alloc(u8, needed_len) catch {
            return AudioError.OutOfMemory;
        };

        // Copy original data to conversion buffer
        @memcpy(conv_buf[0..sample.original_length], src_data[0..sample.original_length]);

        cvt.len = @intCast(sample.original_length);
        cvt.buf = conv_buf.ptr;

        // Perform conversion
        if (c.SDL_ConvertAudio(&cvt) < 0) {
            std.debug.print("Audio conversion failed: {s}\n", .{c.SDL_GetError()});
            self.allocator.free(conv_buf);
            return AudioError.ConversionFailed;
        }

        sample.converted_data = conv_buf[0..@intCast(cvt.len_cvt)];
        sample.converted_length = @intCast(cvt.len_cvt);
        sample.owns_converted_data = true; // We allocated this buffer
    }

    /// Play an audio sample
    pub fn play(self: *AudioPlayer, sample: *AudioSample) void {
        if (!self.is_initialized or !sample.loaded) return;

        const data = sample.converted_data orelse return;

        // Clear any previously queued audio
        c.SDL_ClearQueuedAudio(self.device_id);

        // Apply volume by mixing into a temporary buffer
        const mixed_buf = self.allocator.alloc(u8, data.len) catch return;
        defer self.allocator.free(mixed_buf);

        // Clear and mix with volume
        @memset(mixed_buf, 0);
        c.SDL_MixAudioFormat(
            mixed_buf.ptr,
            data.ptr,
            self.device_spec.format,
            @intCast(data.len),
            self.volume,
        );

        // Queue the audio data
        if (c.SDL_QueueAudio(self.device_id, mixed_buf.ptr, @intCast(data.len)) < 0) return;

        // Make sure device is unpaused
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
        c.SDL_ClearQueuedAudio(self.device_id);
    }

    /// Set volume (0.0 to 1.0)
    pub fn setVolume(self: *AudioPlayer, volume: f32) void {
        self.volume = @intFromFloat(std.math.clamp(volume, 0.0, 1.0) * 128.0);
    }

    /// Check if currently playing
    pub fn isPlaying(self: *const AudioPlayer) bool {
        if (!self.is_initialized) return false;
        return c.SDL_GetQueuedAudioSize(self.device_id) > 0;
    }

    /// Load waveform data for display (downsampled to fit display width)
    /// Returns: total_samples, sample_rate, channels via out parameters
    pub fn loadWaveformData(self: *AudioPlayer, path: []const u8, waveform_out: []i16, total_samples: *u32, sample_rate: *u32, channels: *u8) AudioError!void {
        _ = self;

        // Ensure path is null-terminated for SDL
        var path_buf: [512:0]u8 = undefined;
        if (path.len >= path_buf.len) return AudioError.FileNotFound;
        @memcpy(path_buf[0..path.len], path);
        path_buf[path.len] = 0;

        // Load WAV file
        const rw = c.SDL_RWFromFile(&path_buf, "rb");
        if (rw == null) {
            return AudioError.FileNotFound;
        }

        var file_spec: c.SDL_AudioSpec = std.mem.zeroes(c.SDL_AudioSpec);
        var audio_buf: [*c]u8 = undefined;
        var audio_len: u32 = undefined;

        const result = c.SDL_LoadWAV_RW(rw, 1, &file_spec, &audio_buf, &audio_len);
        if (result == null) {
            return AudioError.FileLoadFailed;
        }
        defer c.SDL_FreeWAV(audio_buf);

        // Calculate sample info
        const bytes_per_sample: u32 = switch (file_spec.format) {
            c.AUDIO_S16LSB, c.AUDIO_S16MSB, c.AUDIO_U16LSB, c.AUDIO_U16MSB => 2,
            c.AUDIO_S32LSB, c.AUDIO_S32MSB, c.AUDIO_F32LSB, c.AUDIO_F32MSB => 4,
            else => 1, // 8-bit
        };
        const num_channels: u32 = @intCast(file_spec.channels);
        const frame_size = bytes_per_sample * num_channels;
        const total_frames = if (frame_size > 0) audio_len / frame_size else 0;

        total_samples.* = total_frames;
        sample_rate.* = @intCast(file_spec.freq);
        channels.* = file_spec.channels;

        if (total_frames == 0 or waveform_out.len == 0) return;

        // Downsample to waveform display size
        const samples_per_bucket = @max(1, total_frames / @as(u32, @intCast(waveform_out.len)));
        const audio_data = audio_buf[0..audio_len];

        var bucket_idx: usize = 0;
        while (bucket_idx < waveform_out.len) : (bucket_idx += 1) {
            const start_frame = bucket_idx * samples_per_bucket;
            const end_frame = @min(start_frame + samples_per_bucket, total_frames);

            var max_val: i32 = 0;
            var min_val: i32 = 0;

            var frame: usize = start_frame;
            while (frame < end_frame) : (frame += 1) {
                const byte_offset = frame * frame_size;
                if (byte_offset + bytes_per_sample > audio_len) break;

                // Read sample value (assuming 16-bit signed for now)
                const sample_val: i16 = if (bytes_per_sample == 2) blk: {
                    const lo = audio_data[byte_offset];
                    const hi = audio_data[byte_offset + 1];
                    break :blk @bitCast(@as(u16, hi) << 8 | @as(u16, lo));
                } else if (bytes_per_sample == 1) blk: {
                    // 8-bit unsigned, convert to signed
                    const val = audio_data[byte_offset];
                    break :blk @as(i16, @intCast(val)) - 128;
                } else blk: {
                    // 32-bit, take upper 16 bits
                    const b2 = audio_data[byte_offset + 2];
                    const b3 = audio_data[byte_offset + 3];
                    break :blk @bitCast(@as(u16, b3) << 8 | @as(u16, b2));
                };

                if (sample_val > max_val) max_val = sample_val;
                if (sample_val < min_val) min_val = sample_val;
            }

            // Store peak-to-peak amplitude
            waveform_out[bucket_idx] = @intCast(@divTrunc(max_val - min_val, 2));
        }
    }
};

/// Check if a file is a supported audio format (delegates to file_io)
pub const isSupportedAudioFile = file_io.isSupportedAudio;

/// Get filename from path (delegates to file_io)
pub const getFilename = file_io.getFilename;

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
