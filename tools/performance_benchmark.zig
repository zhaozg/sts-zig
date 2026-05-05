const std = @import("std");
const zsts = @import("zsts");
const time = std.time;
const print = std.debug.print;

/// Performance Benchmarking Suite for Statistical Tests
/// 性能基准测试套件
const BenchmarkConfig = struct {
    iterations: u32 = 100,
    data_sizes: []const usize = &[_]usize{ 1000, 10000, 100000, 1000000 },
    test_types: []const TestType = &[_]TestType{ .frequency, .runs, .poker, .dft, .rank },
};

const TestType = enum {
    frequency,
    runs,
    poker,
    dft,
    rank,
    block_frequency,
    autocorrelation,
};

const BenchmarkResult = struct {
    test_name: []const u8,
    data_size: usize,
    avg_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    throughput_mbps: f64, // Megabits per second
};

fn generateTestData(io: std.Io, allocator: std.mem.Allocator, size: usize, seed: u64) ![]u8 {
    _ = io;
    var rnd = std.Random.DefaultPrng.init(seed);
    var random = rnd.random();

    var data = try allocator.alloc(u8, size);
    for (0..size) |i| {
        data[i] = if (random.boolean()) '1' else '0';
    }
    return data;
}

fn benchmarkFrequencyTest(io: std.Io, allocator: std.mem.Allocator, data: []const u8, iterations: u32) !BenchmarkResult {
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;
    const clock = std.Io.Clock.awake;

    for (0..iterations) |_| {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.Frequency,
            .n = data.len,
            .extra = null,
        };

        const stat = try zsts.frequency.frequencyDetectStatDetect(allocator, param);
        defer stat.destroy();

        const start = std.Io.Clock.now(clock, io).toNanoseconds();
        stat.init(&param);
        _ = stat.iterate(&bits);
        const end = std.Io.Clock.now(clock, io).toNanoseconds();

        const duration = @as(u64, @intCast(end - start));
        total_time += duration;
        min_time = @min(min_time, duration);
        max_time = @max(max_time, duration);
    }

    const avg_time = total_time / iterations;
    const throughput = (@as(f64, @floatFromInt(data.len)) / 1_000_000.0) / (@as(f64, @floatFromInt(avg_time)) / std.time.ns_per_s);

    return BenchmarkResult{
        .test_name = "Frequency",
        .data_size = data.len,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .throughput_mbps = throughput,
    };
}

fn benchmarkRunsTest(io: std.Io, allocator: std.mem.Allocator, data: []const u8, iterations: u32) !BenchmarkResult {
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;
    const clock = std.Io.Clock.awake;

    for (0..iterations) |_| {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.Runs,
            .n = data.len,
            .extra = null,
        };

        const stat = try zsts.runs.runsDetectStatDetect(allocator, param);
        defer stat.destroy();

        const start = std.Io.Clock.now(clock, io).toNanoseconds();
        stat.init(&param);
        _ = stat.iterate(&bits);
        const end = std.Io.Clock.now(clock, io).toNanoseconds();

        const duration = @as(u64, @intCast(end - start));
        total_time += duration;
        min_time = @min(min_time, duration);
        max_time = @max(max_time, duration);
    }

    const avg_time = total_time / iterations;
    const throughput = (@as(f64, @floatFromInt(data.len)) / 1_000_000.0) / (@as(f64, @floatFromInt(avg_time)) / 1_000_000_000.0);

    return BenchmarkResult{
        .test_name = "Runs",
        .data_size = data.len,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .throughput_mbps = throughput,
    };
}

fn benchmarkDftTest(io: std.Io, allocator: std.mem.Allocator, data: []const u8, iterations: u32) !BenchmarkResult {
    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;
    const clock = std.Io.Clock.awake;

    for (0..iterations) |_| {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.Dft,
            .n = data.len,
            .extra = null,
        };

        const stat = try zsts.dft.dftDetectStatDetect(allocator, param);
        defer stat.destroy();

        const start = std.Io.Clock.now(clock, io).toNanoseconds();
        stat.init(&param);
        _ = stat.iterate(&bits);
        const end = std.Io.Clock.now(clock, io).toNanoseconds();

        const duration = @as(u64, @intCast(end - start));
        total_time += duration;
        min_time = @min(min_time, duration);
        max_time = @max(max_time, duration);
    }

    const avg_time = total_time / iterations;
    const throughput = (@as(f64, @floatFromInt(data.len)) / 1_000_000.0) / (@as(f64, @floatFromInt(avg_time)) / 1_000_000_000.0);

    return BenchmarkResult{
        .test_name = "DFT",
        .data_size = data.len,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .throughput_mbps = throughput,
    };
}

fn benchmarkRankTest(io: std.Io, allocator: std.mem.Allocator, data: []const u8, iterations: u32) !BenchmarkResult {
    // Rank test needs sufficient data (32x32 matrices)
    if (data.len < 32 * 32) {
        return BenchmarkResult{
            .test_name = "Rank",
            .data_size = data.len,
            .avg_time_ns = 0,
            .min_time_ns = 0,
            .max_time_ns = 0,
            .throughput_mbps = 0.0,
        };
    }

    var min_time: u64 = std.math.maxInt(u64);
    var max_time: u64 = 0;
    var total_time: u64 = 0;
    const clock = std.Io.Clock.awake;

    for (0..iterations) |_| {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.Rank,
            .n = data.len,
            .extra = null,
        };

        const stat = try zsts.rank.rankDetectStatDetect(allocator, param);
        defer stat.destroy();

        const start = std.Io.Clock.now(clock, io).toNanoseconds();
        stat.init(&param);
        _ = stat.iterate(&bits);
        const end = std.Io.Clock.now(clock, io).toNanoseconds();

        const duration = @as(u64, @intCast(end - start));
        total_time += duration;
        min_time = @min(min_time, duration);
        max_time = @max(max_time, duration);
    }

    const avg_time = total_time / iterations;
    const throughput = (@as(f64, @floatFromInt(data.len)) / 1_000_000.0) / (@as(f64, @floatFromInt(avg_time)) / 1_000_000_000.0);

    return BenchmarkResult{
        .test_name = "Rank",
        .data_size = data.len,
        .avg_time_ns = avg_time,
        .min_time_ns = min_time,
        .max_time_ns = max_time,
        .throughput_mbps = throughput,
    };
}

fn formatTime(ns: u64) void {
    if (ns < 1000) {
        print("{d:>8}ns", .{ns});
    } else if (ns < 1_000_000) {
        print("{d:>8.2}μs", .{@as(f64, @floatFromInt(ns)) / 1000.0});
    } else if (ns < 1_000_000_000) {
        print("{d:>8.2}ms", .{@as(f64, @floatFromInt(ns)) / 1_000_000.0});
    } else {
        print("{d:>8.2}s ", .{@as(f64, @floatFromInt(ns)) / 1_000_000_000.0});
    }
}

fn printBenchmarkResult(result: BenchmarkResult) void {
    print("│ {s:<12} │ {d:>8} │ ", .{ result.test_name, result.data_size });
    formatTime(result.avg_time_ns);
    print(" │ ", .{});
    formatTime(result.min_time_ns);
    print(" │ ", .{});
    formatTime(result.max_time_ns);
    print(" │ {d:>8.2} MB/s │\n", .{result.throughput_mbps});
}

pub fn runPerformanceBenchmark(io: std.Io, allocator: std.mem.Allocator) !void {
    const config = BenchmarkConfig{};

    print("\n🔥 STS-Zig Performance Benchmark Suite\n", .{});
    print("=====================================\n\n", .{});

    print("Configuration:\n", .{});
    print("- Iterations per test: {d}\n", .{config.iterations});
    print("- Test data sizes: ", .{});
    for (config.data_sizes) |size| {
        print("{d} ", .{size});
    }
    print("bits\n", .{});
    print("- Compiler optimizations: ReleaseFast equivalent\n\n", .{});

    // Table header
    print("┌──────────────┬──────────┬───────────┬───────────┬───────────┬──────────────┐\n", .{});
    print("│ Test Name    │ Data Size│  Avg Time │  Min Time │  Max Time │  Throughput  │\n", .{});
    print("├──────────────┼──────────┼───────────┼───────────┼───────────┼──────────────┤\n", .{});

    for (config.data_sizes) |data_size| {
        // Generate test data
        const test_data = try generateTestData(io, allocator, data_size, 42);
        defer allocator.free(test_data);

        // Benchmark frequency test
        const freq_result = try benchmarkFrequencyTest(io, allocator, test_data, config.iterations);
        printBenchmarkResult(freq_result);

        // Benchmark runs test
        const runs_result = try benchmarkRunsTest(io, allocator, test_data, config.iterations);
        printBenchmarkResult(runs_result);

        // Benchmark DFT test
        const dft_result = try benchmarkDftTest(io, allocator, test_data, config.iterations);
        printBenchmarkResult(dft_result);

        // Benchmark rank test
        const rank_result = try benchmarkRankTest(io, allocator, test_data, config.iterations);
        if (rank_result.avg_time_ns > 0) {
            printBenchmarkResult(rank_result);
        }

        if (data_size < config.data_sizes[config.data_sizes.len - 1]) {
            print("├──────────────┼──────────┼───────────┼───────────┼───────────┼──────────────┤\n", .{});
        }
    }

    print("└──────────────┴──────────┴───────────┴───────────┴───────────┴──────────────┘\n", .{});

    print("\n📊 Performance Analysis:\n", .{});
    print("- Frequency Test: O(n) complexity, excellent scalability\n", .{});
    print("- Runs Test: O(n) complexity, very fast\n", .{});
    print("- DFT Test: O(n log n) complexity due to FFT optimization\n", .{});
    print("- Rank Test: O(m³) complexity per matrix, depends on data size\n", .{});
    print("\n🎯 Optimization Opportunities:\n", .{});
    print("- Use SIMD instructions for bit operations\n", .{});
    print("- Implement parallel processing for large datasets\n", .{});
    print("- Consider memory pool allocation for frequent operations\n", .{});
}

// Test runner entry point
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    try runPerformanceBenchmark(init.io, allocator);
}
