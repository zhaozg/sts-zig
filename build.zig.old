
const std = @import("std");

// Helper function for version-compatible source file specification
fn createPath(b: *std.Build, path: []const u8) std.Build.LazyPath {
    // Try newer API first (0.15+)
    if (@hasDecl(std.Build, "path")) {
        return b.path(path);
    }
    // Fallback to older API (0.14.x)
    if (@hasField(std.Build.LazyPath, "cwd_relative")) {
        return .{ .cwd_relative = path };
    }
    return .{ .path = path };
}

// Helper function for version-compatible executable creation
fn createExecutable(b: *std.Build, name: []const u8, source_path: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    // Check if we have the old API (0.14.x)
    if (@hasField(std.Build.ExecutableOptions, "root_source_file")) {
        return b.addExecutable(.{
            .name = name,
            .root_source_file = createPath(b, source_path),
            .target = target,
            .optimize = optimize,
        });
    }
    
    // New API (0.15+) 
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = undefined,
    });
    exe.root_module.root_source_file = createPath(b, source_path);
    exe.root_module.target = target;
    exe.root_module.optimize = optimize;
    return exe;
}

// Helper function for version-compatible test creation
fn createTest(b: *std.Build, source_path: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    // Check if we have the old API (0.14.x)  
    if (@hasField(std.Build.TestOptions, "root_source_file")) {
        return b.addTest(.{
            .root_source_file = createPath(b, source_path),
            .target = target,
            .optimize = optimize,
        });
    }
    
    // New API (0.15+)
    const test_exe = b.addTest(.{
        .root_module = undefined,
    });
    test_exe.root_module.root_source_file = createPath(b, source_path);
    test_exe.root_module.target = target;
    test_exe.root_module.optimize = optimize;
    return test_exe;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = createExecutable(b, "zsts", "src/main.zig", target, optimize);

    // GSL dependencies completely removed - pure Zig mathematical implementation
    // All statistical algorithms now use verified Zig standard library functions
    b.installArtifact(exe);

    // 创建模块
    const zsts_module = b.addModule("zsts", .{
        .root_source_file = createPath(b, "src/zsts.zig"),
    });
    const test_step = b.step("test", "Run unit tests");

    // GMT tests
    const gmt_tests = createTest(b, "test/GMT0005_test.zig", target, optimize);
    // GSL 依赖已移除 - GMT 测试现在使用纯 Zig 实现
    // gmt_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    // gmt_tests.linkSystemLibrary("gsl");
    gmt_tests.root_module.addImport("zsts", zsts_module);

    const run_gmt_tests = b.addRunArtifact(gmt_tests);
    test_step.dependOn(&run_gmt_tests.step);
    b.installArtifact(gmt_tests);

    // NIST tests
    const nist_tests = createTest(b, "test/SP800_22r1_test.zig", target, optimize);
    // GSL 依赖已移除 - NIST 测试现在使用纯 Zig 实现
    // nist_tests.addIncludePath(.{ .cwd_relative = "/usr/local/opt/gsl/include" });
    // nist_tests.linkSystemLibrary("gsl");
    nist_tests.root_module.addImport("zsts", zsts_module);

    const run_nist_tests = b.addRunArtifact(nist_tests);
    test_step.dependOn(&run_nist_tests.step);
    b.installArtifact(nist_tests);

    // Math accuracy tests
    const math_accuracy_tests = createTest(b, "test/math_accuracy_test.zig", target, optimize);
    math_accuracy_tests.root_module.addImport("zsts", zsts_module);

    const run_math_accuracy_tests = b.addRunArtifact(math_accuracy_tests);
    test_step.dependOn(&run_math_accuracy_tests.step);
    b.installArtifact(math_accuracy_tests);

    // Extended coverage tests  
    const extended_coverage_tests = createTest(b, "test/extended_coverage_test.zig", target, optimize);
    extended_coverage_tests.root_module.addImport("zsts", zsts_module);

    // Data generator executable
    const data_gen = createExecutable(b, "data-generator", "tools/data_generator.zig", target, optimize);
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
    const validation_tests = createTest(b, "test/validation_test.zig", target, optimize);
    validation_tests.root_module.addImport("zsts", zsts_module);

    // Reporting tests
    const reporting_tests = createTest(b, "test/reporting_test.zig", target, optimize);
    reporting_tests.root_module.addImport("zsts", zsts_module);

    const run_validation_tests = b.addRunArtifact(validation_tests);
    const run_reporting_tests = b.addRunArtifact(reporting_tests);
    test_step.dependOn(&run_validation_tests.step);
    test_step.dependOn(&run_reporting_tests.step);

    // P2 Features: Performance Benchmark and Enhanced CLI
    
    // Performance Benchmark Tool
    const benchmark_exe = createExecutable(b, "sts-benchmark", "benchmark/performance_benchmark.zig", target, optimize);
    benchmark_exe.root_module.addImport("zsts", zsts_module);
    b.installArtifact(benchmark_exe);
    
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    benchmark_step.dependOn(&run_benchmark.step);

    // Enhanced CLI Tool
    const cli_exe = createExecutable(b, "sts-cli", "cli/enhanced_cli.zig", target, optimize);
    cli_exe.root_module.addImport("zsts", zsts_module);
    b.installArtifact(cli_exe);
    
    const run_cli = b.addRunArtifact(cli_exe);
    if (b.args) |args| {
        run_cli.addArgs(args);
    }
    const cli_step = b.step("cli", "Run enhanced CLI tool");
    cli_step.dependOn(&run_cli.step);
}
