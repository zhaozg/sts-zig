
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zsts",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/fftw/include" });
    exe.linkSystemLibrary("fftw3");
    b.installArtifact(exe);

   // 创建模块
    const zsts_module = b.addModule("zsts", .{
        .root_source_file = b.path("src/zsts.zig"),
    });
    const test_step = b.step("test", "Run unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("test/GMT0005_test.zig"),
        .target = target,
    });
    unit_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/fftw/include" });
    unit_tests.linkSystemLibrary("fftw3");
    unit_tests.root_module.addImport("zsts", zsts_module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);

    b.installArtifact(unit_tests);
}
