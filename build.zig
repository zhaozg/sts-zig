
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
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    exe.linkSystemLibrary("gsl");
    b.installArtifact(exe);

   // 创建模块
    const zsts_module = b.addModule("zsts", .{
        .root_source_file = b.path("src/zsts.zig"),
    });
    const test_step = b.step("test", "Run unit tests");

    // GMT tests
    const gmt_tests = b.addTest(.{
        .root_source_file = b.path("test/GMT0005_test.zig"),
        .target = target,
    });
    gmt_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    gmt_tests.linkSystemLibrary("gsl");
    gmt_tests.root_module.addImport("zsts", zsts_module);

    const run_gmt_tests = b.addRunArtifact(gmt_tests);
    test_step.dependOn(&run_gmt_tests.step);
    b.installArtifact(gmt_tests);

    // NIST tests
    const nist_tests = b.addTest(.{
        .root_source_file = b.path("test/SP800_22r1_test.zig"),
        .target = target,
    });
    nist_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    nist_tests.linkSystemLibrary("gsl");
    nist_tests.root_module.addImport("zsts", zsts_module);

    const run_nist_tests = b.addRunArtifact(nist_tests);
    test_step.dependOn(&run_nist_tests.step);
    b.installArtifact(nist_tests);
}
