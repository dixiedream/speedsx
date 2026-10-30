const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/sdl2.h"),
        .target = target,
        .optimize = optimize,
        .link_system_libs = &.{
            .{ .name = "SDL2" },
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
    root_module.linkSystemLibrary("SDL2", .{});
    root_module.link_libc = true;

    const exe = b.addExecutable(.{
        .name = "speedsx",
        .root_module = root_module,
    });

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
