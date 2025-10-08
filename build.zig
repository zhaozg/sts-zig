const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 获取 fft-zig 依赖
    const fft_dep = b.dependency("fft", .{
        .target = target,
        .optimize = optimize,
    });

    // 创建 fft 模块
    const fft_module = b.createModule(.{
        .root_source_file = fft_dep.path("src/fft.zig"),
    });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_mod.addImport("fft", fft_module);

    const exe = b.addExecutable(.{
        .name = "zsts",
        .root_module = main_mod,
    });
    b.installArtifact(exe);

    // 创建模块
    const zsts_module = b.addModule("zsts", .{
        .root_source_file = b.path("src/zsts.zig"),
    });
    zsts_module.addImport("fft", fft_module);
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

    // FFT Performance test (consolidated)
    // const fft_perf_mod = b.createModule(.{
    //     .root_source_file = b.path("tools/fft_benchmark.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const fft_perf_exe = b.addExecutable(.{
    //     .name = "fft_perf",
    //     .root_module = fft_perf_mod,
    // });
    // fft_perf_exe.root_module.addImport("zsts", zsts_module);
    //
    // const fft_perf_step = b.step("fft-perf", "Run FFT performance tests");
    // const run_fft_perf = b.addRunArtifact(fft_perf_exe);
    // fft_perf_step.dependOn(&run_fft_perf.step);
    // b.installArtifact(fft_perf_exe);
}
