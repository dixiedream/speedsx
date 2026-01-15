const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;
const models = @import("models.zig");
const ui = @import("ui.zig");
const file_io = @import("file_io.zig");
const spdsx_io = @import("spdsx_io.zig");
const audio = @import("audio.zig");

const Config = struct {
    window_width: i32 = 1100,
    window_height: i32 = 720,
    title: [*:0]const u8 = "SpeedSX",
};

const App = struct {
    project: models.Project,
    editor_ui: ui.EditorUI,
    midi_config: models.MidiConfig,
    config: Config,
    renderer: ui.Renderer,
    running: bool,
    last_time: u64,
    allocator: std.mem.Allocator,
    audio_player: audio.AudioPlayer,
    current_sample: audio.AudioSample,

    pub fn init(sdl_renderer: *c.SDL_Renderer, allocator: std.mem.Allocator) App {
        return App{
            .project = models.Project.init(),
            .editor_ui = ui.EditorUI.init(),
            .midi_config = models.MidiConfig{},
            .config = Config{},
            .renderer = ui.Renderer.init(sdl_renderer),
            .running = true,
            .last_time = @intCast(c.SDL_GetTicks64()),
            .allocator = allocator,
            .audio_player = audio.AudioPlayer.init(),
            .current_sample = audio.AudioSample{},
        };
    }

    pub fn deinit(self: *App) void {
        self.audio_player.deinit();
        self.current_sample.deinit();
        self.renderer.deinit();
    }
};

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize SDL2 with video, events, and audio
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS | c.SDL_INIT_AUDIO) != 0) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    const config = Config{};

    // Create window
    const window = c.SDL_CreateWindow(
        config.title,
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        config.window_width,
        config.window_height,
        c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE,
    ) orelse {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        return error.WindowCreationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    // Create renderer
    const sdl_renderer = c.SDL_CreateRenderer(
        window,
        -1,
        c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC,
    ) orelse {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{c.SDL_GetError()});
        return error.RendererCreationFailed;
    };
    defer c.SDL_DestroyRenderer(sdl_renderer);

    // Enable alpha blending
    _ = c.SDL_SetRenderDrawBlendMode(sdl_renderer, c.SDL_BLENDMODE_BLEND);

    var app = App.init(sdl_renderer, allocator);
    defer app.deinit();

    // Set a default path hint for the startup screen
    app.editor_ui.setStartupPath("/Volumes/SPD-SX_/Roland");

    // Main loop
    var event: c.SDL_Event = undefined;
    while (app.running) {
        const current_time: u64 = @intCast(c.SDL_GetTicks64());
        const delta: f32 = @as(f32, @floatFromInt(current_time - app.last_time)) / 1000.0;
        app.last_time = current_time;

        // Reset per-frame state
        app.editor_ui.mouse_clicked = false;
        app.editor_ui.mouse_right_clicked = false;
        app.editor_ui.beginFrame();

        // Handle events
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    app.running = false;
                },
                c.SDL_MOUSEMOTION => {
                    app.editor_ui.mouse_x = event.motion.x;
                    app.editor_ui.mouse_y = event.motion.y;
                    // Update drag state
                    app.editor_ui.updateDrag();
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        app.editor_ui.mouse_down = true;
                        app.editor_ui.mouse_clicked = true;

                        // Close context menu on left click outside it
                        if (app.editor_ui.context_menu_open) {
                            // Menu click handling is done in drawPadContextMenu
                        }

                        // If clicking outside a focused text field, apply and unfocus
                        if (app.editor_ui.isEditingText()) {
                            // The click will be handled by drawTextInput to either
                            // focus a new field or we apply current input
                            // We'll apply on next frame if no field was clicked
                        }
                    } else if (event.button.button == c.SDL_BUTTON_RIGHT) {
                        app.editor_ui.mouse_right_clicked = true;
                    }
                },
                c.SDL_MOUSEBUTTONUP => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        app.editor_ui.mouse_down = false;

                        // Handle drop if dragging
                        if (app.editor_ui.isDragging()) {
                            _ = ui.applyDropFromLibrary(&app.editor_ui, app.project.currentKit(), &app.project.sample_library);
                        } else if (app.editor_ui.drag_type != .none) {
                            // Cancel drag if we never started actually dragging
                            app.editor_ui.cancelDrag();
                        }
                    }
                },
                c.SDL_KEYDOWN => {
                    handleKeyDown(&app, event.key.keysym);
                },
                c.SDL_TEXTINPUT => {
                    handleTextInput(&app, &event.text.text);
                },
                c.SDL_MOUSEWHEEL => {
                    app.editor_ui.handleMouseWheel(event.wheel.y);
                },
                else => {},
            }
        }

        // Update
        update(&app, delta);

        // Get window size
        var width: c_int = 0;
        var height: c_int = 0;
        c.SDL_GetWindowSize(window, &width, &height);

        // Draw
        draw(&app, width, height);
    }
}

fn initDemoData(project: *models.Project) void {
    // Add samples to the library first
    const library = &project.sample_library;

    // Demo sample library - these represent all available waves
    const demo_samples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "Kick 1", .path = "/samples/kick1.wav" },
        .{ .name = "Kick 2", .path = "/samples/kick2.wav" },
        .{ .name = "Kick 808", .path = "/samples/kick808.wav" },
        .{ .name = "Snare 1", .path = "/samples/snare1.wav" },
        .{ .name = "Snare 2", .path = "/samples/snare2.wav" },
        .{ .name = "Snare Rim", .path = "/samples/snare_rim.wav" },
        .{ .name = "Hi-Hat Closed", .path = "/samples/hihat_closed.wav" },
        .{ .name = "Hi-Hat Open", .path = "/samples/hihat_open.wav" },
        .{ .name = "Hi-Hat Pedal", .path = "/samples/hihat_pedal.wav" },
        .{ .name = "Tom 1", .path = "/samples/tom1.wav" },
        .{ .name = "Tom 2", .path = "/samples/tom2.wav" },
        .{ .name = "Tom Floor", .path = "/samples/tom_floor.wav" },
        .{ .name = "Crash", .path = "/samples/crash.wav" },
        .{ .name = "Crash 2", .path = "/samples/crash2.wav" },
        .{ .name = "Ride", .path = "/samples/ride.wav" },
        .{ .name = "Ride Bell", .path = "/samples/ride_bell.wav" },
        .{ .name = "Clap", .path = "/samples/clap.wav" },
        .{ .name = "Cowbell", .path = "/samples/cowbell.wav" },
        .{ .name = "Tambourine", .path = "/samples/tambourine.wav" },
        .{ .name = "Shaker", .path = "/samples/shaker.wav" },
        .{ .name = "Conga Hi", .path = "/samples/conga_hi.wav" },
        .{ .name = "Conga Lo", .path = "/samples/conga_lo.wav" },
        .{ .name = "Bongo Hi", .path = "/samples/bongo_hi.wav" },
        .{ .name = "Bongo Lo", .path = "/samples/bongo_lo.wav" },
        .{ .name = "FX Sweep", .path = "/samples/fx_sweep.wav" },
    };

    for (demo_samples) |sample| {
        _ = library.addOrFind(sample.name, sample.path);
    }

    // Set up Kit 1 - Demo Kit
    const kit = project.currentKit();
    kit.setName("Demo Kit 1");
    kit.tempo = 120;

    // Load samples from library to pads (using library paths)
    kit.pads[0].loadSample("Kick 1", "/samples/kick1.wav");
    kit.pads[0].volume = 100;
    kit.pads[0].play_mode = .single;

    kit.pads[1].loadSample("Snare 1", "/samples/snare1.wav");
    kit.pads[1].volume = 95;
    kit.pads[1].play_mode = .single;

    kit.pads[2].loadSample("Hi-Hat Closed", "/samples/hihat_closed.wav");
    kit.pads[2].volume = 80;
    kit.pads[2].mute_group = .group1;

    kit.pads[3].loadSample("Hi-Hat Open", "/samples/hihat_open.wav");
    kit.pads[3].volume = 85;
    kit.pads[3].mute_group = .group1;

    kit.pads[4].loadSample("Tom 1", "/samples/tom1.wav");
    kit.pads[4].volume = 90;

    kit.pads[5].loadSample("Tom 2", "/samples/tom2.wav");
    kit.pads[5].volume = 90;

    kit.pads[6].loadSample("Crash", "/samples/crash.wav");
    kit.pads[6].volume = 85;
    kit.pads[6].play_mode = .single;

    kit.pads[7].loadSample("Ride", "/samples/ride.wav");
    kit.pads[7].volume = 80;

    // Set up Kit 2 - Electronic Kit (uses some different samples)
    _ = project.addKit();
    project.kits[1].setName("Electronic Kit");
    project.kits[1].tempo = 140;
    project.kits[1].pads[0].loadSample("Kick 808", "/samples/kick808.wav");
    project.kits[1].pads[0].volume = 100;
    project.kits[1].pads[1].loadSample("Clap", "/samples/clap.wav");
    project.kits[1].pads[1].volume = 95;

    // Set up Kit 3 - Acoustic Kit
    _ = project.addKit();
    project.kits[2].setName("Acoustic Kit");
    project.kits[2].tempo = 100;
}

fn handleKeyDown(app: *App, keysym: c.SDL_Keysym) void {
    const mod = keysym.mod;
    const ctrl = (mod & c.KMOD_CTRL) != 0;

    // Handle startup screen keys
    if (app.editor_ui.isInStartup()) {
        handleStartupKeyDown(app, keysym);
        return;
    }

    // If editing text, handle text input keys first
    if (app.editor_ui.isEditingText()) {
        switch (keysym.sym) {
            c.SDLK_ESCAPE => {
                app.editor_ui.cancelTextInput();
            },
            c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                // Apply the text input to the appropriate field
                if (app.editor_ui.focused_field == .sample_browser_path) {
                    ui.applySampleBrowserPathInput(&app.editor_ui);
                    scanSampleDirectory(app);
                } else {
                    ui.applyTextInputToKit(&app.editor_ui, app.project.currentKit());
                }
            },
            c.SDLK_BACKSPACE => {
                app.editor_ui.handleBackspace();
            },
            c.SDLK_DELETE => {
                app.editor_ui.handleDelete();
            },
            c.SDLK_LEFT => {
                app.editor_ui.moveCursorLeft();
            },
            c.SDLK_RIGHT => {
                app.editor_ui.moveCursorRight();
            },
            c.SDLK_HOME => {
                app.editor_ui.moveCursorHome();
            },
            c.SDLK_END => {
                app.editor_ui.moveCursorEnd();
            },
            else => {},
        }
        return;
    }

    // Handle sample browser keyboard shortcuts
    if (app.editor_ui.show_sample_browser) {
        switch (keysym.sym) {
            c.SDLK_ESCAPE => {
                app.editor_ui.show_sample_browser = false;
                app.audio_player.stop();
            },
            c.SDLK_UP => {
                if (app.editor_ui.sample_browser_selected > 0) {
                    app.editor_ui.sample_browser_selected -= 1;
                }
            },
            c.SDLK_DOWN => {
                if (app.editor_ui.sample_browser_selected < app.editor_ui.sample_browser_file_count -| 1) {
                    app.editor_ui.sample_browser_selected += 1;
                }
            },
            c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                // Play selected sample
                playSelectedSample(app);
            },
            c.SDLK_SPACE => {
                // Toggle play/stop
                if (app.audio_player.isPlaying()) {
                    app.audio_player.stop();
                } else {
                    playSelectedSample(app);
                }
            },
            else => {},
        }
        return;
    }

    switch (keysym.sym) {
        c.SDLK_ESCAPE => {
            if (app.editor_ui.context_menu_open) {
                app.editor_ui.closeContextMenu();
            } else if (app.editor_ui.show_sample_browser) {
                app.editor_ui.show_sample_browser = false;
            } else if (app.editor_ui.show_midi_config) {
                app.editor_ui.show_midi_config = false;
            } else if (app.editor_ui.show_settings) {
                app.editor_ui.show_settings = false;
            }
        },
        c.SDLK_s => {
            if (ctrl) saveProject(app);
        },
        c.SDLK_o => {
            if (ctrl) loadProject(app);
        },
        c.SDLK_c => {
            if (ctrl) {
                // Copy selected pad
                const pad = app.project.currentKit().getPad(app.editor_ui.selected_pad);
                app.editor_ui.copyPad(pad);
            }
        },
        c.SDLK_v => {
            if (ctrl) {
                // Paste to selected pad
                const pad = app.project.currentKit().getPad(app.editor_ui.selected_pad);
                app.editor_ui.pastePad(pad);
            }
        },
        c.SDLK_n => {
            if (ctrl) {
                _ = app.project.addKit();
                app.project.selectKit(app.project.kit_count - 1);
            }
        },
        c.SDLK_TAB => {
            if ((mod & c.KMOD_SHIFT) != 0) {
                if (app.editor_ui.selected_pad == 0) {
                    app.editor_ui.selected_pad = 8;
                } else {
                    app.editor_ui.selected_pad -= 1;
                }
            } else {
                app.editor_ui.selected_pad = (app.editor_ui.selected_pad + 1) % 9;
            }
        },
        c.SDLK_PAGEUP => {
            if (app.project.current_kit_index > 0) {
                app.project.selectKit(app.project.current_kit_index - 1);
            }
        },
        c.SDLK_PAGEDOWN => {
            if (app.project.current_kit_index < app.project.kit_count - 1) {
                app.project.selectKit(app.project.current_kit_index + 1);
            }
        },
        c.SDLK_F1 => {
            app.editor_ui.show_settings = !app.editor_ui.show_settings;
        },
        c.SDLK_F2 => {
            app.editor_ui.show_midi_config = !app.editor_ui.show_midi_config;
        },
        c.SDLK_F3 => {
            app.editor_ui.show_sample_browser = !app.editor_ui.show_sample_browser;
        },
        // Number keys for pad triggers
        c.SDLK_1, c.SDLK_KP_1 => app.editor_ui.triggerPadFlash(0),
        c.SDLK_2, c.SDLK_KP_2 => app.editor_ui.triggerPadFlash(1),
        c.SDLK_3, c.SDLK_KP_3 => app.editor_ui.triggerPadFlash(2),
        c.SDLK_4, c.SDLK_KP_4 => app.editor_ui.triggerPadFlash(3),
        c.SDLK_5, c.SDLK_KP_5 => app.editor_ui.triggerPadFlash(4),
        c.SDLK_6, c.SDLK_KP_6 => app.editor_ui.triggerPadFlash(5),
        c.SDLK_7, c.SDLK_KP_7 => app.editor_ui.triggerPadFlash(6),
        c.SDLK_8, c.SDLK_KP_8 => app.editor_ui.triggerPadFlash(7),
        c.SDLK_9, c.SDLK_KP_9 => app.editor_ui.triggerPadFlash(8),
        else => {},
    }
}

fn handleTextInput(app: *App, text: [*c]const u8) void {
    if (!app.editor_ui.isEditingText()) return;

    // Process each character in the text input
    var i: usize = 0;
    while (text[i] != 0) : (i += 1) {
        const char = text[i];
        if (char >= 32 and char < 127) {
            app.editor_ui.handleCharInput(char);
        }
    }
}

fn handleStartupKeyDown(app: *App, keysym: c.SDL_Keysym) void {
    // Handle text input for the path field
    if (app.editor_ui.isEditingText()) {
        switch (keysym.sym) {
            c.SDLK_ESCAPE => {
                app.editor_ui.cancelTextInput();
            },
            c.SDLK_RETURN, c.SDLK_KP_ENTER => {
                // Apply path input and try to open
                ui.applyStartupPathInput(&app.editor_ui);
                tryOpenProject(app);
            },
            c.SDLK_BACKSPACE => {
                app.editor_ui.handleBackspace();
            },
            c.SDLK_DELETE => {
                app.editor_ui.handleDelete();
            },
            c.SDLK_LEFT => {
                app.editor_ui.moveCursorLeft();
            },
            c.SDLK_RIGHT => {
                app.editor_ui.moveCursorRight();
            },
            c.SDLK_HOME => {
                app.editor_ui.moveCursorHome();
            },
            c.SDLK_END => {
                app.editor_ui.moveCursorEnd();
            },
            else => {},
        }
        return;
    }

    // Global startup screen keys
    switch (keysym.sym) {
        c.SDLK_RETURN, c.SDLK_KP_ENTER => {
            tryOpenProject(app);
        },
        c.SDLK_ESCAPE => {
            // Start with new project
            startNewProject(app);
        },
        else => {},
    }
}

fn tryOpenProject(app: *App) void {
    const path = app.editor_ui.getStartupPath();
    if (path.len == 0) {
        app.editor_ui.setStartupError("Please enter a path");
        return;
    }

    // Check if the path looks like a valid SPD-SX configuration path
    if (spdsx_io.isValidSpdSxPath(path)) {
        // Load from real SPD-SX format
        if (spdsx_io.loadConfiguration(app.allocator, path)) |result| {
            app.project = result.project;
            app.editor_ui.enterEditor();

            // Log loaded counts for debugging
            std.debug.print("Loaded {d} kits and {d} waves from SPD-SX\n", .{ result.kit_count, result.wave_count });
        } else |err| {
            switch (err) {
                spdsx_io.SpdSxError.FileNotFound => {
                    app.editor_ui.setStartupError("SPD-SX configuration not found");
                },
                spdsx_io.SpdSxError.InvalidPath => {
                    app.editor_ui.setStartupError("Invalid path");
                },
                spdsx_io.SpdSxError.ReadError => {
                    app.editor_ui.setStartupError("Error reading configuration");
                },
                spdsx_io.SpdSxError.AccessDenied => {
                    app.editor_ui.setStartupError("Access denied - check permissions");
                },
                else => {
                    app.editor_ui.setStartupError("Error loading SPD-SX configuration");
                },
            }
        }
    } else {
        // Try legacy project.spdx file first
        var full_path: [512]u8 = undefined;
        const project_file = std.fmt.bufPrint(&full_path, "{s}/project.spdx", .{path}) catch {
            app.editor_ui.setStartupError("Path too long");
            return;
        };

        // Try to load the project
        if (file_io.loadProject(project_file)) |loaded_project| {
            app.project = loaded_project;
            app.project.setFilePath(path);
            app.editor_ui.enterEditor();
        } else |err| {
            // If file doesn't exist, check if the directory exists
            switch (err) {
                file_io.FileError.FileNotFound => {
                    // Check if directory exists - if so, start with empty project at that path
                    if (std.fs.cwd().openDir(path, .{})) |dir| {
                        var d = dir;
                        d.close();
                        // Directory exists, start with new project at this path
                        app.project = models.Project.init();
                        app.project.setFilePath(path);
                        initDemoData(&app.project);
                        app.editor_ui.enterEditor();
                    } else |_| {
                        app.editor_ui.setStartupError("Directory not found");
                    }
                },
                file_io.FileError.InvalidMagic => {
                    app.editor_ui.setStartupError("Invalid project file format");
                },
                file_io.FileError.UnsupportedVersion => {
                    app.editor_ui.setStartupError("Unsupported project version");
                },
                file_io.FileError.AccessDenied => {
                    app.editor_ui.setStartupError("Access denied - check permissions");
                },
                else => {
                    app.editor_ui.setStartupError("Error loading project");
                },
            }
        }
    }
}

fn startNewProject(app: *App) void {
    app.project = models.Project.init();
    initDemoData(&app.project);
    app.editor_ui.enterEditor();
}

fn saveProject(app: *App) void {
    const path = app.project.getFilePath();

    // If we have a valid path that looks like SPD-SX, save in SPD-SX format
    if (path.len > 0 and spdsx_io.isValidSpdSxPath(path)) {
        spdsx_io.saveConfiguration(app.allocator, &app.project, path) catch |err| {
            std.debug.print("Error saving SPD-SX configuration: {}\n", .{err});
            return;
        };
        std.debug.print("Saved configuration to SPD-SX at: {s}\n", .{path});
    } else if (path.len > 0) {
        // Save to SPD-SX format at the specified path (creating structure if needed)
        spdsx_io.createSpdSxStructure(path) catch {};
        spdsx_io.saveConfiguration(app.allocator, &app.project, path) catch |err| {
            std.debug.print("Error saving configuration: {}\n", .{err});
            // Fall back to legacy format
            file_io.saveProject(&app.project, "project.spdx") catch return;
            return;
        };
        std.debug.print("Saved configuration to: {s}\n", .{path});
    } else {
        // No path set, use legacy format
        file_io.saveProject(&app.project, "project.spdx") catch return;
    }
}

fn loadProject(app: *App) void {
    const path = app.project.getFilePath();

    // If we have a valid SPD-SX path, load from that
    if (path.len > 0 and spdsx_io.isValidSpdSxPath(path)) {
        if (spdsx_io.loadConfiguration(app.allocator, path)) |result| {
            app.project = result.project;
            std.debug.print("Reloaded {d} kits and {d} waves from SPD-SX\n", .{ result.kit_count, result.wave_count });
        } else |err| {
            std.debug.print("Error reloading SPD-SX configuration: {}\n", .{err});
        }
    } else {
        // Fall back to legacy format
        app.project = file_io.loadProject("project.spdx") catch return;
    }
}

/// Scan a directory for audio files and populate the sample browser
fn scanSampleDirectory(app: *App) void {
    const path = app.editor_ui.getSampleBrowserPath();
    if (path.len == 0) {
        app.editor_ui.setSampleBrowserError("Please enter a path");
        return;
    }

    app.editor_ui.clearSampleBrowserError();
    app.editor_ui.clearSampleBrowserFiles();
    app.editor_ui.sample_browser_scanning = true;

    // Try to open and scan the directory
    var path_buf: [512]u8 = undefined;
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => app.editor_ui.setSampleBrowserError("Directory not found"),
            error.AccessDenied => app.editor_ui.setSampleBrowserError("Access denied"),
            error.NotDir => app.editor_ui.setSampleBrowserError("Path is not a directory"),
            else => app.editor_ui.setSampleBrowserError("Error opening directory"),
        }
        app.editor_ui.sample_browser_scanning = false;
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;

        // Check if it's a supported audio file
        if (audio.isSupportedAudioFile(entry.name)) {
            // Build full path
            const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ path, entry.name }) catch continue;
            _ = app.editor_ui.addSampleBrowserFile(entry.name, full_path);
        }
    }

    app.editor_ui.sample_browser_scanning = false;

    if (app.editor_ui.sample_browser_file_count == 0) {
        app.editor_ui.setSampleBrowserError("No audio files found (WAV, AIFF)");
    }
}

/// Play the currently selected sample in the browser
fn playSelectedSample(app: *App) void {
    const file = app.editor_ui.getSelectedSampleFile() orelse return;
    const file_path = file.getPath();

    if (file_path.len == 0) return;

    // Stop any current playback
    app.audio_player.stop();

    // Load and play the sample
    app.audio_player.playFile(file_path, &app.current_sample) catch |err| {
        switch (err) {
            audio.AudioError.FileLoadFailed => app.editor_ui.setSampleBrowserError("Failed to load audio file"),
            audio.AudioError.FileNotFound => app.editor_ui.setSampleBrowserError("File not found"),
            else => app.editor_ui.setSampleBrowserError("Error playing audio"),
        }
    };
}

/// Load the selected sample into the project's sample library and assign to current pad
fn loadSelectedSample(app: *App) void {
    const file = app.editor_ui.getSelectedSampleFile() orelse return;
    const file_name = file.getName();
    const file_path = file.getPath();

    if (file_path.len == 0) return;

    // Add to sample library
    _ = app.project.sample_library.addOrFind(file_name, file_path);

    // Also load it onto the currently selected pad
    const pad = app.project.currentKit().getPad(app.editor_ui.selected_pad);
    pad.loadSample(file_name, file_path);

    // Close the browser
    app.editor_ui.show_sample_browser = false;
}

fn update(app: *App, delta: f32) void {
    app.editor_ui.update(delta);

    // Check if we should unfocus text field (clicked outside)
    if (app.editor_ui.shouldUnfocusTextField()) {
        if (app.editor_ui.isInStartup()) {
            ui.applyStartupPathInput(&app.editor_ui);
        } else if (app.editor_ui.focused_field == .sample_browser_path) {
            ui.applySampleBrowserPathInput(&app.editor_ui);
        } else {
            ui.applyTextInputToKit(&app.editor_ui, app.project.currentKit());
        }
    }
}

fn draw(app: *App, width: c_int, height: c_int) void {
    const r = &app.renderer;

    r.clear();

    // Handle startup screen
    if (app.editor_ui.isInStartup()) {
        const action = ui.drawStartupScreen(r, &app.editor_ui, width, height);
        switch (action) {
            .open_project => {
                ui.applyStartupPathInput(&app.editor_ui);
                tryOpenProject(app);
            },
            .new_project => {
                startNewProject(app);
            },
            .none => {},
        }
        r.present();
        return;
    }

    // Draw toolbar
    ui.drawToolbar(r, &app.editor_ui, 0, width);

    // Main content area
    const content_y: i32 = 50;

    // Left panel: Kit Settings (Kit, Main, Mode, Sub sections)
    const left_panel_x: i32 = 15;
    const left_panel_w: i32 = 200;
    ui.drawKitSettingsPanel(r, &app.editor_ui, left_panel_x, content_y + 8, app.project.currentKit(), app.project.currentKit().getPad(app.editor_ui.selected_pad));

    // Center: Pad grid
    const grid_x = left_panel_w + 30;
    const grid_y = content_y + 45;
    ui.drawPadGrid(r, &app.editor_ui, grid_x, grid_y, app.project.currentKit());

    // Device visualization below pad grid
    const device_y = grid_y + 300;
    if (app.editor_ui.show_device_view) {
        ui.drawDeviceView(r, &app.editor_ui, grid_x, device_y);
    }

    // Right side panels
    const right_panel_x = grid_x + 320;

    // Wave list panel
    if (app.editor_ui.show_wave_list) {
        ui.drawWaveListPanel(r, &app.editor_ui, right_panel_x, content_y + 8, &app.project);
    }

    // Kit list panel
    const kit_list_x = right_panel_x + 150;
    if (app.editor_ui.show_kit_list) {
        ui.drawKitListPanel(r, &app.editor_ui, kit_list_x, content_y + 8, &app.project);
    }

    // Action buttons (right side, below kit list)
    const action_btn_x = right_panel_x;
    const action_btn_y = content_y + 380;
    ui.drawActionButtons(r, &app.editor_ui, action_btn_x, action_btn_y, &app.project);

    // File bar at bottom (with Open/Save)
    const file_bar_y = height - 50;
    const file_action = ui.drawFileBar(r, &app.editor_ui, 0, file_bar_y, width, &app.project);
    if (file_action.needs_open) {
        loadProject(app);
    }
    if (file_action.needs_save) {
        saveProject(app);
    }

    // Status bar
    ui.drawStatusBar(r, height - 22, width, &app.project, &app.editor_ui);

    // Modals
    const center_x = @divFloor(width, 2);
    const center_y = @divFloor(height, 2);

    if (app.editor_ui.show_sample_browser) {
        const sample_action = ui.drawSampleBrowser(r, &app.editor_ui, center_x, center_y);
        if (sample_action.scan_path) {
            ui.applySampleBrowserPathInput(&app.editor_ui);
            scanSampleDirectory(app);
        }
        if (sample_action.play_selected) {
            playSelectedSample(app);
        }
        if (sample_action.load_selected) {
            loadSelectedSample(app);
        }
        if (sample_action.close) {
            app.editor_ui.show_sample_browser = false;
            app.audio_player.stop();
        }
    }

    if (app.editor_ui.show_midi_config) {
        ui.drawMidiConfig(r, &app.editor_ui, center_x, center_y, &app.midi_config);
    }

    if (app.editor_ui.show_settings) {
        ui.drawSettings(r, &app.editor_ui, center_x, center_y, &app.project);
    }

    // Draw context menu (on top of most elements)
    _ = ui.drawPadContextMenu(r, &app.editor_ui, app.project.currentKit());

    // Draw drag indicator last (on top of everything)
    ui.drawDragIndicator(r, &app.editor_ui);

    r.present();
}

test "project initialization" {
    var project = models.Project.init();
    try std.testing.expect(project.kit_count == 1);
    try std.testing.expectEqualStrings("Untitled Project", project.getName());
}

test "kit operations" {
    var project = models.Project.init();
    try std.testing.expect(project.addKit());
    try std.testing.expect(project.kit_count == 2);
    try std.testing.expect(project.deleteKit(1));
    try std.testing.expect(project.kit_count == 1);
    try std.testing.expect(!project.deleteKit(0));
}

test "pad sample loading" {
    var pad = models.Pad.init();
    try std.testing.expect(!pad.has_sample);
    pad.loadSample("Test Sample", "/path/to/sample.wav");
    try std.testing.expect(pad.has_sample);
    try std.testing.expectEqualStrings("Test Sample", pad.sample.getName());
    pad.clearSample();
    try std.testing.expect(!pad.has_sample);
}
