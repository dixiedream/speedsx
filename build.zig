const std = @import("std");

fn mingwLibDirFromPkgConfig(b: *std.Build) ?[]const u8 {
    const pc_env = b.graph.environ_map.get("PKG_CONFIG_PATH") orelse return null;
    return std.fs.path.dirname(pc_env);
}

/// MSYS2 MinGW: link SDL2.dll (import lib), not static libSDL2.a; SDL2main is static-only.
fn linkSdl2Windows(b: *std.Build, mod: *std.Build.Module) void {
    const no_pkg_config: std.Build.Module.LinkSystemLibraryOptions = .{ .use_pkg_config = .no };
    if (mingwLibDirFromPkgConfig(b)) |lib_dir| {
        mod.addLibraryPath(.{ .cwd_relative = lib_dir });
    }
    mod.linkSystemLibrary("mingw32", no_pkg_config);
    mod.linkSystemLibrary("SDL2main", .{
        .use_pkg_config = .no,
        .preferred_link_mode = .static,
    });
    mod.linkSystemLibrary("SDL2.dll", .{
        .use_pkg_config = .no,
        .preferred_link_mode = .dynamic,
    });
}

fn linkSdl2MacOS(mod: *std.Build.Module) void {
    const frameworks = [_][]const u8{
        "CoreMedia",
        "CoreVideo",
        "Cocoa",
        "IOKit",
        "ForceFeedback",
        "Carbon",
        "GameController",
        "CoreHaptics",
        "Metal",
        "QuartzCore",
    };
    for (frameworks) |name| {
        mod.linkFramework(name, .{});
    }
}

fn sdlBindingsModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const c_builtins = b.createModule(.{
        .root_source_file = b.path("src/bindings/c_builtins.zig"),
        .target = target,
        .optimize = optimize,
    });
    const helpers = b.createModule(.{
        .root_source_file = b.path("src/bindings/helpers.zig"),
        .target = target,
        .optimize = optimize,
    });
    const c_mod = b.createModule(.{
        .root_source_file = b.path("src/bindings/sdl2.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "c_builtins", .module = c_builtins },
            .{ .name = "helpers", .module = helpers },
        },
    });
    return c_mod;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug symbols from the executable") orelse false;

    const sdl_pkg_config: std.Build.Module.LinkSystemLibraryOptions = .{
        .use_pkg_config = switch (target.result.os.tag) {
            .macos, .windows => .yes,
            else => .force,
        },
    };

    const c_mod = sdlBindingsModule(b, target, optimize);

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_mod },
        },
    });
    if (target.result.os.tag == .windows) {
        linkSdl2Windows(b, root_module);
    } else {
        root_module.linkSystemLibrary("SDL2", sdl_pkg_config);
    }
    root_module.link_libc = true;
    if (target.result.os.tag == .macos) {
        linkSdl2MacOS(root_module);
    }

    const exe = b.addExecutable(.{
        .name = "speedsx",
        .root_module = root_module,
    });
    if (strip) root_module.strip = true;
    if (target.result.os.tag == .windows) {
        exe.subsystem = .windows;
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run SpeedSX");
    run_step.dependOn(&run_cmd.step);

    const test_models = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/models.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(test_models);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
