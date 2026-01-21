const std = @import("std");
const sdl = @import("sdl.zig");
const c = sdl.c;
const models = @import("models.zig");
const ui = @import("ui.zig");
const file_io = @import("file_io.zig");
const spdsx_io = @import("spdsx_io.zig");
const audio = @import("audio.zig");
const user_config = @import("config.zig");

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
            .audio_player = audio.AudioPlayer.init(allocator),
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

    // Load last used path from config, or use default
    const saved_config = user_config.load();
    const last_path = saved_config.getLastPath();
    if (last_path.len > 0) {
        app.editor_ui.setStartupPath(last_path);
    } else {
        app.editor_ui.setStartupPath("/Volumes/SPD-SX_/Roland");
    }

    // Main loop
    var event: c.SDL_Event = undefined;
    while (app.running) {
        const current_time: u64 = @intCast(c.SDL_GetTicks64());
        const delta: f32 = @as(f32, @floatFromInt(current_time - app.last_time)) / 1000.0;
        app.last_time = current_time;

        // Reset per-frame state
        app.editor_ui.input.mouse_clicked = false;
        app.editor_ui.input.mouse_right_clicked = false;
        app.editor_ui.beginFrame();

        // Handle events
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    app.running = false;
                },
                c.SDL_MOUSEMOTION => {
                    app.editor_ui.input.mouse_x = event.motion.x;
                    app.editor_ui.input.mouse_y = event.motion.y;
                    // Update drag state
                    app.editor_ui.updateDrag();
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        app.editor_ui.input.mouse_down = true;
                        app.editor_ui.input.mouse_clicked = true;

                        // Close context menu on left click outside it
                        if (app.editor_ui.context_menu.open) {
                            // Menu click handling is done in drawPadContextMenu
                        }

                        // If clicking outside a focused text field, apply and unfocus
                        if (app.editor_ui.isEditingText()) {
                            // The click will be handled by drawTextInput to either
                            // focus a new field or we apply current input
                            // We'll apply on next frame if no field was clicked
                        }
                    } else if (event.button.button == c.SDL_BUTTON_RIGHT) {
                        app.editor_ui.input.mouse_right_clicked = true;
                    }
                },
                c.SDL_MOUSEBUTTONUP => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        app.editor_ui.input.mouse_down = false;

                        // Handle drop if dragging
                        if (app.editor_ui.isDragging()) {
                            _ = ui.applyDropFromLibrary(&app.editor_ui, app.project.currentKit(), &app.project.sample_library);
                        } else if (app.editor_ui.drag.drag_type != .none) {
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
                if (app.editor_ui.text_input.focused_field == .sample_browser_path) {
                    ui.applySampleBrowserPathInput(&app.editor_ui);
                    scanSampleDirectory(app);
                } else if (app.editor_ui.text_input.focused_field == .kit_chain_name) {
                    ui.applyKitChainNameInput(&app.editor_ui, &app.project);
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
                app.editor_ui.closeSampleBrowser();
                app.audio_player.stop();
            },
            c.SDLK_UP => {
                if (app.editor_ui.sample_browser.selected > 0) {
                    app.editor_ui.sample_browser.selected -= 1;
                }
            },
            c.SDLK_DOWN => {
                if (app.editor_ui.sample_browser.selected < app.editor_ui.sample_browser.file_count -| 1) {
                    app.editor_ui.sample_browser.selected += 1;
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
            if (app.editor_ui.context_menu.open) {
                app.editor_ui.closeContextMenu();
            } else if (app.editor_ui.show_sample_browser) {
                app.editor_ui.closeSampleBrowser();
            } else if (app.editor_ui.show_midi_config) {
                app.editor_ui.show_midi_config = false;
            } else if (app.editor_ui.show_settings) {
                app.editor_ui.show_settings = false;
            } else if (app.editor_ui.show_kit_chain) {
                app.editor_ui.show_kit_chain = false;
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
                app.editor_ui.invalidateSampleUsageCache();
            }
        },
        c.SDLK_n => {
            if (ctrl) {
                _ = app.project.addKit();
                app.project.selectKit(app.project.kit_count - 1);
            }
        },
        c.SDLK_TAB => {
            // Cycle through all 15 pads (9 main + 4 triggers + 2 footswitches)
            if ((mod & c.KMOD_SHIFT) != 0) {
                if (app.editor_ui.selected_pad == 0) {
                    app.editor_ui.selected_pad = models.Kit.NUM_PADS - 1;
                } else {
                    app.editor_ui.selected_pad -= 1;
                }
            } else {
                app.editor_ui.selected_pad = (app.editor_ui.selected_pad + 1) % models.Kit.NUM_PADS;
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
            if (app.editor_ui.show_sample_browser) {
                app.editor_ui.closeSampleBrowser();
            } else {
                app.editor_ui.openSampleBrowser();
            }
        },
        c.SDLK_F4 => {
            app.editor_ui.show_kit_chain = !app.editor_ui.show_kit_chain;
        },
        // Number keys for pad triggers (play sample + visual flash)
        c.SDLK_1, c.SDLK_KP_1 => playPadSample(app, 0),
        c.SDLK_2, c.SDLK_KP_2 => playPadSample(app, 1),
        c.SDLK_3, c.SDLK_KP_3 => playPadSample(app, 2),
        c.SDLK_4, c.SDLK_KP_4 => playPadSample(app, 3),
        c.SDLK_5, c.SDLK_KP_5 => playPadSample(app, 4),
        c.SDLK_6, c.SDLK_KP_6 => playPadSample(app, 5),
        c.SDLK_7, c.SDLK_KP_7 => playPadSample(app, 6),
        c.SDLK_8, c.SDLK_KP_8 => playPadSample(app, 7),
        c.SDLK_9, c.SDLK_KP_9 => playPadSample(app, 8),
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
            app.editor_ui.invalidateSampleUsageCache();
            app.editor_ui.enterEditor();
            user_config.saveLastPath(path); // Remember this path for next startup
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
    }

    app.editor_ui.setStartupError("Directory not found");
}

fn startNewProject(app: *App) void {
    app.project = models.Project.init();
    app.editor_ui.enterEditor();
}

fn saveProject(app: *App) void {
    const path = app.project.getFilePath();

    // If we have a valid path that looks like SPD-SX, save in SPD-SX format
    if (path.len > 0 and spdsx_io.isValidSpdSxPath(path)) {
        spdsx_io.saveConfiguration(app.allocator, &app.project, path) catch {
            app.editor_ui.showError("Failed to save SPD-SX configuration");
            return;
        };
        app.editor_ui.showSuccess("Project saved");
        return;
    }

    if (path.len > 0) {
        // Save to SPD-SX format at the specified path (creating structure if needed)
        spdsx_io.createSpdSxStructure(path) catch {};
        spdsx_io.saveConfiguration(app.allocator, &app.project, path) catch {
            app.editor_ui.showError("Failed to save project");
            return;
        };
        app.editor_ui.showSuccess("Project saved");
        return;
    }

    app.editor_ui.showError("No project path set");
}

fn loadProject(app: *App) void {
    const path = app.project.getFilePath();

    if (path.len == 0) {
        app.editor_ui.showError("No project path set");
        return;
    }

    // If we have a valid SPD-SX path, load from that
    if (spdsx_io.isValidSpdSxPath(path)) {
        if (spdsx_io.loadConfiguration(app.allocator, path)) |result| {
            app.project = result.project;
            app.editor_ui.invalidateSampleUsageCache();
            app.editor_ui.showSuccess("Project reloaded");
        } else |_| {
            app.editor_ui.showError("Failed to reload SPD-SX configuration");
        }
        return;
    }

    app.editor_ui.showError("Invalid SPD-SX path");
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
    app.editor_ui.sample_browser.scanning = true;

    // Try to open and scan the directory
    var path_buf: [512]u8 = undefined;
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| {
        switch (err) {
            error.FileNotFound => app.editor_ui.setSampleBrowserError("Directory not found"),
            error.AccessDenied => app.editor_ui.setSampleBrowserError("Access denied"),
            error.NotDir => app.editor_ui.setSampleBrowserError("Path is not a directory"),
            else => app.editor_ui.setSampleBrowserError("Error opening directory"),
        }
        app.editor_ui.sample_browser.scanning = false;
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
            _ = app.editor_ui.sample_browser.addFile(entry.name, full_path);
        }
    }

    app.editor_ui.sample_browser.scanning = false;

    if (app.editor_ui.sample_browser.file_count == 0) {
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

/// Load the selected sample into the project's sample library (wave list)
/// Pad assignment is done separately via drag & drop from the wave list
fn loadSelectedSample(app: *App) void {
    const file = app.editor_ui.getSelectedSampleFile() orelse return;
    const file_name = file.getName();
    const file_path = file.getPath();

    if (file_path.len == 0) return;

    // Add to sample library only - pad assignment is a separate action
    const wave_idx = app.project.sample_library.addOrFind(file_name, file_path);

    // Select the newly added wave in the wave list
    if (wave_idx) |idx| {
        app.editor_ui.selected_wave = idx;
    }

    // Close the browser
    app.editor_ui.closeSampleBrowser();
}

/// Play the sample from a specific pad
fn playPadSample(app: *App, pad_index: u8) void {
    const pad = app.project.currentKit().getPad(pad_index);

    if (!pad.has_sample) return;

    const sample_path = pad.sample.getPath();
    if (sample_path.len == 0) return;

    // Stop any current playback
    app.audio_player.stop();

    // Load and play the sample
    app.audio_player.playFile(sample_path, &app.current_sample) catch {
        app.editor_ui.showError("Failed to play sample");
        return;
    };

    // Trigger visual flash
    app.editor_ui.triggerPadFlash(pad_index);
}

/// Play the sample from the currently selected pad
fn playCurrentPadSample(app: *App) void {
    playPadSample(app, app.editor_ui.selected_pad);
}

/// Delete a wave from the sample library and its physical files
fn deleteWave(app: *App, wave_index: u16) void {
    if (wave_index >= app.project.sample_library.count) return;

    // Get the sample path before removing
    const sample = &app.project.sample_library.samples[wave_index];
    const sample_path = sample.getPath();
    const base_path = app.project.getFilePath();

    // Delete physical files (WAV and .spd parameter file)
    if (base_path.len > 0) {
        spdsx_io.deleteWaveFiles(base_path, wave_index, sample_path);
    }

    // Remove from the in-memory sample library
    _ = app.project.sample_library.removeSample(wave_index);

    // Adjust selected wave if it's now out of bounds
    if (app.editor_ui.selected_wave >= app.project.sample_library.count and app.project.sample_library.count > 0) {
        app.editor_ui.selected_wave = app.project.sample_library.count - 1;
    }

    app.editor_ui.showSuccess("Wave deleted");
}

fn update(app: *App, delta: f32) void {
    app.editor_ui.update(delta);

    // Check if we should unfocus text field (clicked outside)
    if (app.editor_ui.shouldUnfocusTextField()) {
        if (app.editor_ui.isInStartup()) {
            ui.applyStartupPathInput(&app.editor_ui);
        } else if (app.editor_ui.text_input.focused_field == .sample_browser_path) {
            ui.applySampleBrowserPathInput(&app.editor_ui);
        } else if (app.editor_ui.text_input.focused_field == .kit_chain_name) {
            ui.applyKitChainNameInput(&app.editor_ui, &app.project);
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

    // Main content area - using Layout constants
    const L = ui.Layout;
    const content_y = L.content_y;

    // Left panel: Kit Settings (Kit, Main, Mode, Sub, MIDI sections) - scrollable
    const left_panel_height = height - content_y - L.status_bar_height - L.file_bar_height - 20;
    ui.drawKitSettingsPanel(r, &app.editor_ui, L.left_panel_x, content_y + 8, left_panel_height, app.project.currentKit(), app.project.currentKit().getPad(app.editor_ui.selected_pad));

    // Center: Pad grid
    const grid_x = L.left_panel_width + L.grid_offset_x;
    const grid_y = content_y + L.grid_offset_y;
    ui.drawPadGrid(r, &app.editor_ui, grid_x, grid_y, app.project.currentKit());

    // Auxiliary pads section (triggers & footswitches) below main pad grid
    const aux_section_y = grid_y + L.pad_grid_height;
    ui.drawAuxPadSection(r, &app.editor_ui, grid_x, aux_section_y, app.project.currentKit());

    // Right side panels
    const right_panel_x = grid_x + L.pad_grid_width + L.right_panel_gap;

    // Wave list panel
    if (app.editor_ui.show_wave_list) {
        ui.drawWaveListPanel(r, &app.editor_ui, right_panel_x, content_y + 8, &app.project);
    }

    // Kit list panel
    const kit_list_x = right_panel_x + L.kit_list_width;
    if (app.editor_ui.show_kit_list) {
        ui.drawKitListPanel(r, &app.editor_ui, kit_list_x, content_y + 8, &app.project);
    }

    // Action buttons (right side, below kit list)
    const action_result = ui.drawActionButtons(r, &app.editor_ui, right_panel_x, content_y + L.action_buttons_y, &app.project);
    if (action_result.play_sample) {
        playCurrentPadSample(app);
    }
    if (action_result.stop_sample) {
        app.audio_player.stop();
    }
    if (action_result.delete_wave) {
        deleteWave(app, action_result.wave_to_delete);
    }

    // File bar at bottom (with Open/Reload/Save)
    const file_bar_y = height - L.file_bar_height;
    const file_action = ui.drawFileBar(r, &app.editor_ui, 0, file_bar_y, width, &app.project);
    if (file_action.needs_open) {
        // Return to startup screen to select a different folder
        app.editor_ui.enterStartup();
    }
    if (file_action.needs_reload) {
        loadProject(app);
    }
    if (file_action.needs_save) {
        saveProject(app);
    }

    // Status bar
    ui.drawStatusBar(r, height - L.status_bar_height, width, &app.project, &app.editor_ui);

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
            app.editor_ui.closeSampleBrowser();
            app.audio_player.stop();
        }
    }

    if (app.editor_ui.show_midi_config) {
        ui.drawMidiConfig(r, &app.editor_ui, center_x, center_y, &app.midi_config);
    }

    if (app.editor_ui.show_settings) {
        ui.drawSettings(r, &app.editor_ui, center_x, center_y, &app.project);
    }

    if (app.editor_ui.show_kit_chain) {
        const chain_action = ui.drawKitChainEditor(r, &app.editor_ui, center_x, center_y, &app.project);
        if (chain_action.close) {
            app.editor_ui.show_kit_chain = false;
        }
    }

    // Wave editor modal
    if (app.editor_ui.show_wave_editor) {
        const wave_idx = app.editor_ui.wave_editor.wave_index;
        if (wave_idx < app.project.sample_library.count) {
            const sample = &app.project.sample_library.samples[wave_idx];
            const wave_action = ui.drawWaveEditor(r, &app.editor_ui, center_x, center_y, sample);

            if (wave_action.play_preview) {
                // Play the sample with current start/end (for now just play the whole sample)
                const sample_path = sample.getPath();
                if (sample_path.len > 0) {
                    app.audio_player.playFile(sample_path, &app.current_sample) catch {};
                }
            }
            if (wave_action.save) {
                // Apply wave editor changes to the sample
                app.editor_ui.applyWaveEditorChanges(sample);
            }
            if (wave_action.close) {
                app.editor_ui.closeWaveEditor();
            }
        } else {
            app.editor_ui.closeWaveEditor();
        }
    }

    // Draw context menus (on top of most elements)
    _ = ui.drawPadContextMenu(r, &app.editor_ui, app.project.currentKit());

    // Wave context menu
    const wave_menu_action = ui.drawWaveContextMenu(r, &app.editor_ui, &app.project);
    if (wave_menu_action.open_editor) {
        const wave_idx = app.editor_ui.context_menu.wave;
        if (wave_idx < app.project.sample_library.count) {
            const sample = &app.project.sample_library.samples[wave_idx];
            app.editor_ui.openWaveEditor(wave_idx, sample);

            // Load waveform data
            const sample_path = sample.getPath();
            if (sample_path.len > 0) {
                app.audio_player.loadWaveformData(
                    sample_path,
                    &app.editor_ui.wave_editor.waveform_data,
                    &app.editor_ui.wave_editor.total_samples,
                    &app.editor_ui.wave_editor.sample_rate,
                    &app.editor_ui.wave_editor.channels,
                ) catch {};
                app.editor_ui.wave_editor.waveform_loaded = true;

                // Set end point to total samples if not set
                if (app.editor_ui.wave_editor.end_point == 0) {
                    app.editor_ui.wave_editor.end_point = app.editor_ui.wave_editor.total_samples;
                }
            }
        }
    }
    if (wave_menu_action.delete_wave) {
        deleteWave(app, wave_menu_action.wave_to_delete);
    }

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
