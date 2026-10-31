const std = @import("std");
const Translator = @import("translate_c").Translator;

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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_pkg_config: std.Build.Module.LinkSystemLibraryOptions = .{
        .use_pkg_config = switch (target.result.os.tag) {
            .macos, .windows => .yes,
            else => .force,
        },
    };

    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/sdl2.h"),
        .target = target,
        .optimize = optimize,
        .link_system_libs = &.{
            .{ .name = "SDL2", .options = sdl_pkg_config },
        },
    });

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = translator.mod },
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
