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
    const math_mod = b.createModule(.{
        .root_source_file = b.path("test/math_accuracy_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const math_tests = b.addTest(.{
        .root_module = math_mod,
    });
    math_tests.root_module.addImport("zsts", zsts_module);

    const run_math_tests = b.addRunArtifact(math_tests);
    test_step.dependOn(&run_math_tests.step);
    b.installArtifact(math_tests);

    // Validation tests
    const validation_mod = b.createModule(.{
        .root_source_file = b.path("test/validation_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const validation_tests = b.addTest(.{
        .root_module = validation_mod,
    });
    validation_tests.root_module.addImport("zsts", zsts_module);

    const run_validation_tests = b.addRunArtifact(validation_tests);
    test_step.dependOn(&run_validation_tests.step);
    b.installArtifact(validation_tests);

    // Reporting tests
    const reporting_mod = b.createModule(.{
        .root_source_file = b.path("test/reporting_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const reporting_tests = b.addTest(.{
        .root_module = reporting_mod,
    });
    reporting_tests.root_module.addImport("zsts", zsts_module);

    const run_reporting_tests = b.addRunArtifact(reporting_tests);
    test_step.dependOn(&run_reporting_tests.step);
    b.installArtifact(reporting_tests);

    // Benchmark tool
    const benchmark_mod = b.createModule(.{
        .root_source_file = b.path("tools/performance_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = benchmark_mod,
    });
    benchmark_exe.root_module.addImport("zsts", zsts_module);

    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    benchmark_step.dependOn(&run_benchmark.step);
    b.installArtifact(benchmark_exe);

    // Enhanced CLI tool
    const cli_mod = b.createModule(.{
        .root_source_file = b.path("tools/enhanced_cli.zig"),
        .target = target,
        .optimize = optimize,
    });
    const cli_exe = b.addExecutable(.{
        .name = "cli",
        .root_module = cli_mod,
    });
    cli_exe.root_module.addImport("zsts", zsts_module);

    const cli_step = b.step("cli", "Run enhanced CLI");
    const run_cli = b.addRunArtifact(cli_exe);
    if (b.args) |args| {
        run_cli.addArgs(args);
    }
    cli_step.dependOn(&run_cli.step);
    b.installArtifact(cli_exe);

    // Data generator tool
    const datagen_mod = b.createModule(.{
        .root_source_file = b.path("tools/data_generator.zig"),
        .target = target,
        .optimize = optimize,
    });
    const datagen_exe = b.addExecutable(.{
        .name = "datagen",
        .root_module = datagen_mod,
    });

    const datagen_step = b.step("datagen", "Run data generator");
    const run_datagen = b.addRunArtifact(datagen_exe);
    if (b.args) |args| {
        run_datagen.addArgs(args);
    }
    datagen_step.dependOn(&run_datagen.step);
    b.installArtifact(datagen_exe);
}
