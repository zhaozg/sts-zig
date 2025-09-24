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
    nist_tests.root_module.addImport("zsts", zsts_module);

    const run_nist_tests = b.addRunArtifact(nist_tests);
    test_step.dependOn(&run_nist_tests.step);
    b.installArtifact(nist_tests);

    // Math accuracy tests
    const math_tests = b.addTest(.{
        .root_source_file = b.path("test/math_accuracy_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    math_tests.root_module.addImport("zsts", zsts_module);

    const run_math_tests = b.addRunArtifact(math_tests);
    test_step.dependOn(&run_math_tests.step);

    // Benchmark tool
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("benchmark/performance_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_exe.root_module.addImport("zsts", zsts_module);

    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    benchmark_step.dependOn(&run_benchmark.step);
    b.installArtifact(benchmark_exe);

    // Enhanced CLI tool
    const cli_exe = b.addExecutable(.{
        .name = "cli",
        .root_source_file = b.path("cli/enhanced_cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_exe.root_module.addImport("zsts", zsts_module);

    const cli_step = b.step("cli", "Run enhanced CLI");
    const run_cli = b.addRunArtifact(cli_exe);
    if (b.args) |args| {
        run_cli.addArgs(args);
    }
    cli_step.dependOn(&run_cli.step);
    b.installArtifact(cli_exe);
}