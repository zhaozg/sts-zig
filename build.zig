
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_mod = b.createModule(.{
        .root_source_file = .{ .path = "src/main.zig" },
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
        .root_source_file = .{ .path = "src/zsts.zig" },
    });
    const test_step = b.step("test", "Run unit tests");

    // GMT tests
    const gmt_mod = b.createModule(.{
        .root_source_file = .{ .path = "test/GMT0005_test.zig" },
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
        .root_source_file = .{ .path = "test/SP800_22r1_test.zig" },
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
        .root_source_file = .{ .path = "test/math_accuracy_test.zig" },
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
        .root_source_file = .{ .path = "test/extended_coverage_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    const extended_coverage_tests = b.addTest(.{
        .root_module = extended_coverage_mod,
    });
    extended_coverage_tests.root_module.addImport("zsts", zsts_module);

    // Data generator executable
    const data_gen = b.addExecutable(.{
        .name = "data-generator",
        .root_source_file = .{ .path = "tools/data_generator.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(data_gen);

    // Data generator run step
    const data_gen_cmd = b.addRunArtifact(data_gen);
    data_gen_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        data_gen_cmd.addArgs(args);
    }
    const data_gen_step = b.step("datagen", "Run test data generator");
    data_gen_step.dependOn(&data_gen_cmd.step);

    // Validation tests
    const validation_tests = b.addTest(.{
        .root_source_file = .{ .path = "test/validation_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    validation_tests.root_module.addImport("zsts", zsts_module);

    // Reporting tests
    const reporting_tests = b.addTest(.{
        .root_source_file = .{ .path = "test/reporting_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    reporting_tests.root_module.addImport("zsts", zsts_module);

    const run_validation_tests = b.addRunArtifact(validation_tests);
    const run_reporting_tests = b.addRunArtifact(reporting_tests);
    test_step.dependOn(&run_validation_tests.step);
    test_step.dependOn(&run_reporting_tests.step);

    // P2 Features: Performance Benchmark and Enhanced CLI
    
    // Performance Benchmark Tool
    const benchmark_exe = b.addExecutable(.{
        .name = "sts-benchmark",
        .root_source_file = .{ .path = "benchmark/performance_benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    benchmark_exe.root_module.addImport("zsts", zsts_module);
    b.installArtifact(benchmark_exe);
    
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    benchmark_step.dependOn(&run_benchmark.step);

    // Enhanced CLI Tool
    const cli_exe = b.addExecutable(.{
        .name = "sts-cli",
        .root_source_file = .{ .path = "cli/enhanced_cli.zig" },
        .target = target,
        .optimize = optimize,
    });
    cli_exe.root_module.addImport("zsts", zsts_module);
    b.installArtifact(cli_exe);
    
    const run_cli = b.addRunArtifact(cli_exe);
    if (b.args) |args| {
        run_cli.addArgs(args);
    }
    const cli_step = b.step("cli", "Run enhanced CLI tool");
    cli_step.dependOn(&run_cli.step);
}
