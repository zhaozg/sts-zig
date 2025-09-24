
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "zsts",
        .root_module = main_mod,
    });

    // GSL 依赖已移除 - 现在使用纯 Zig 数学实现  
    // exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    // exe.linkSystemLibrary("gsl");
    b.installArtifact(exe);

    // 创建模块
    const zsts_module = b.addModule("zsts", .{
        .root_source_file = b.path("src/zsts.zig"),
    });
    const test_step = b.step("test", "Run unit tests");

    // GMT tests
    const gmt_mod = b.createModule(.{
        .root_source_file = b.path("test/GMT0005_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gmt_tests = b.addTest(.{
        .root_module = gmt_mod,
    });
    // GSL 依赖已移除 - GMT 测试现在使用纯 Zig 实现
    // gmt_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    // gmt_tests.linkSystemLibrary("gsl");
    gmt_tests.root_module.addImport("zsts", zsts_module);

    const run_gmt_tests = b.addRunArtifact(gmt_tests);
    test_step.dependOn(&run_gmt_tests.step);
    b.installArtifact(gmt_tests);

    // NIST tests
    const nist_mod = b.createModule(.{
        .root_source_file = b.path("test/SP800_22r1_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const nist_tests = b.addTest(.{
        .root_module = nist_mod,
    });
    // GSL 依赖已移除 - NIST 测试现在使用纯 Zig 实现
    // nist_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    // nist_tests.linkSystemLibrary("gsl");
    nist_tests.root_module.addImport("zsts", zsts_module);

    const run_nist_tests = b.addRunArtifact(nist_tests);
    test_step.dependOn(&run_nist_tests.step);
    b.installArtifact(nist_tests);

    // Math accuracy tests
    const math_accuracy_mod = b.createModule(.{
        .root_source_file = b.path("test/math_accuracy_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const math_accuracy_tests = b.addTest(.{
        .root_module = math_accuracy_mod,
    });
    math_accuracy_tests.root_module.addImport("zsts", zsts_module);

    const run_math_accuracy_tests = b.addRunArtifact(math_accuracy_tests);
    test_step.dependOn(&run_math_accuracy_tests.step);
    b.installArtifact(math_accuracy_tests);

    // Extended coverage tests  
    const extended_coverage_mod = b.createModule(.{
        .root_source_file = b.path("test/extended_coverage_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const extended_coverage_tests = b.addTest(.{
        .root_module = extended_coverage_mod,
    });
    extended_coverage_tests.root_module.addImport("zsts", zsts_module);

    const run_extended_coverage_tests = b.addRunArtifact(extended_coverage_tests);
    test_step.dependOn(&run_extended_coverage_tests.step);
    b.installArtifact(extended_coverage_tests);
}
