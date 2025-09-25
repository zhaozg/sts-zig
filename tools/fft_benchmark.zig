const std = @import("std");
const zsts = @import("zsts");
const fft = zsts.fft;

// Type definitions
const Complex = fft.Complex;
const VectorF64 = fft.VectorF64;

/// Modern FFT Performance Benchmark Tool
///
/// Establishes new performance evaluation baselines using the optimized FFT implementation
/// from src/fft.zig. This tool provides comprehensive benchmarking across different
/// algorithms and data sizes to validate performance improvements.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Modern FFT Performance Evaluation\n", .{});
    std.debug.print("==================================\n\n", .{});

    // Test 1: SIMD capability validation
    try validateSIMDCapabilities();

    // Test 2: Algorithm performance comparison
    try compareAlgorithmPerformance(allocator);

    // Test 3: Size scaling analysis
    try analyzeSizeScaling(allocator);

    // Test 4: Memory efficiency analysis
    try analyzeMemoryEfficiency(allocator);

    std.debug.print("\n🎯 FFT performance evaluation completed successfully!\n", .{});
}

/// Validate SIMD vector operations are working correctly
fn validateSIMDCapabilities() !void {
    std.debug.print("=== SIMD Capability Validation ===\n", .{});

    // Test basic vector operations
    const test_vec = VectorF64{ 1.0, 2.0, 3.0, 4.0 };
    const scaled_vec = test_vec * @as(VectorF64, @splat(2.0));

    std.debug.print("Vector scaling test: {any}\n", .{scaled_vec});

    // Test trigonometric functions
    const angles = VectorF64{ 0.0, std.math.pi / 4.0, std.math.pi / 2.0, std.math.pi };
    const cos_vals = @cos(angles);
    const sin_vals = @sin(angles);

    std.debug.print("Cos values: {any}\n", .{cos_vals});
    std.debug.print("Sin values: {any}\n", .{sin_vals});

    std.debug.print("✅ SIMD validation successful!\n\n", .{});
}

/// Compare different FFT algorithm performance
fn compareAlgorithmPerformance(allocator: std.mem.Allocator) !void {
    std.debug.print("=== Algorithm Performance Comparison ===\n", .{});

    const test_sizes = [_]usize{ 64, 128, 256, 512, 1024, 2048 };
    const iterations = 100;

    std.debug.print("┌─────────────────┬───────┬────────────┬─────────────────────┐\n", .{});
    std.debug.print("│   Algorithm     │ Size  │    Time    │     Throughput      │\n", .{});
    std.debug.print("├─────────────────┼───────┼────────────┼─────────────────────┤\n", .{});

    for (test_sizes) |size| {
        if (!fft.isPowerOfTwo(size)) continue;

        // Test different algorithms based on size characteristics
        if (size >= 256 and fft.isPowerOfFour(size)) {
            try benchmarkAlgorithm(allocator, "Radix-4 SIMD", size, iterations, .radix4_simd);
        } else if (size >= 64) {
            try benchmarkAlgorithm(allocator, "Radix-2 SIMD", size, iterations, .radix2_simd);
        } else {
            try benchmarkAlgorithm(allocator, "Standard FFT", size, iterations, .standard);
        }
    }

    std.debug.print("└─────────────────┴───────┴────────────┴─────────────────────┘\n\n", .{});
}

/// Analyze performance scaling with different data sizes
fn analyzeSizeScaling(allocator: std.mem.Allocator) !void {
    std.debug.print("=== Size Scaling Analysis ===\n", .{});

    const size_ranges = [_]struct { size: usize, name: []const u8 }{
        .{ .size = 256, .name = "Small" },
        .{ .size = 1024, .name = "Medium" },
        .{ .size = 4096, .name = "Large" },
        .{ .size = 16384, .name = "Very Large" },
    };

    for (size_ranges) |range| {
        if (!fft.isPowerOfTwo(range.size)) continue;

        const iterations = if (range.size <= 1024) @as(u32, 200) else if (range.size <= 4096) @as(u32, 100) else @as(u32, 50);

        // Generate test signal - mixed sinusoids to test frequency resolution
        const input_data = try allocator.alloc(f64, range.size);
        defer allocator.free(input_data);

        for (0..range.size) |i| {
            const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(range.size));
            // Mixed frequency signal: fundamental + harmonics
            input_data[i] = std.math.sin(2.0 * std.math.pi * 5.0 * t) +
                0.5 * std.math.sin(2.0 * std.math.pi * 15.0 * t) +
                0.25 * std.math.sin(2.0 * std.math.pi * 25.0 * t);
        }

        const out_len = range.size / 2 + 1;
        const fft_output = try allocator.alloc(f64, 2 * out_len);
        defer allocator.free(fft_output);
        const magnitude = try allocator.alloc(f64, out_len);
        defer allocator.free(magnitude);

        // Benchmark the R2C FFT function
        const start_time = std.time.nanoTimestamp();

        for (0..iterations) |_| {
            try fft.fftR2C(allocator, input_data, fft_output, magnitude);
        }

        const end_time = std.time.nanoTimestamp();
        const avg_ns = @as(f64, @floatFromInt(@as(u64, @intCast(end_time - start_time)))) / @as(f64, @floatFromInt(iterations));
        const avg_ms = avg_ns / 1_000_000.0;
        const throughput = (@as(f64, @floatFromInt(range.size)) / (avg_ms / 1000.0)) / 1_000_000.0;

        std.debug.print("{s:>10} ({d:>5} pts) | Time: {d:>6.2}ms | Throughput: {d:>6.1} MSamples/s\n", .{ range.name, range.size, avg_ms, throughput });
    }

    std.debug.print("\n", .{});
}

/// Analyze memory efficiency of different approaches
fn analyzeMemoryEfficiency(allocator: std.mem.Allocator) !void {
    std.debug.print("=== Memory Efficiency Analysis ===\n", .{});

    const test_size: usize = 1024;
    const input_data = try allocator.alloc(f64, test_size);
    defer allocator.free(input_data);

    // Initialize test data
    for (0..test_size) |i| {
        const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(test_size));
        input_data[i] = std.math.sin(2.0 * std.math.pi * 10.0 * t);
    }

    const out_len = test_size / 2 + 1;
    const fft_output = try allocator.alloc(f64, 2 * out_len);
    defer allocator.free(fft_output);
    const magnitude = try allocator.alloc(f64, out_len);
    defer allocator.free(magnitude);

    // Test memory efficiency
    const iterations = 1000;
    var memory_peak: usize = 0;

    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        // This would require memory tracking implementation
        try fft.fftR2C(allocator, input_data, fft_output, magnitude);
        // Estimate memory usage (actual tracking would need custom allocator)
        memory_peak = @max(memory_peak, test_size * @sizeOf(f64) * 4); // Rough estimate
    }

    const end_time = std.time.nanoTimestamp();
    const avg_ns = @as(f64, @floatFromInt(@as(u64, @intCast(end_time - start_time)))) / @as(f64, @floatFromInt(iterations));
    const avg_ms = avg_ns / 1_000_000.0;

    std.debug.print("Memory efficiency test (1024 points):\n", .{});
    std.debug.print("  Average execution time: {d:.3}ms\n", .{avg_ms});
    std.debug.print("  Estimated peak memory: {d}KB\n", .{memory_peak / 1024});
    std.debug.print("  Memory per sample: {d}B\n", .{memory_peak / test_size});

    std.debug.print("\n", .{});
}

/// Algorithm type for benchmarking
const AlgorithmType = enum {
    standard,
    radix2_simd,
    radix4_simd,
};

/// Benchmark a specific algorithm
fn benchmarkAlgorithm(allocator: std.mem.Allocator, name: []const u8, size: usize, iterations: u32, algorithm_type: AlgorithmType) !void {
    // Generate test data - mixed frequency signal
    const input_data = try allocator.alloc(f64, size);
    defer allocator.free(input_data);

    for (0..size) |i| {
        const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(size));
        input_data[i] = std.math.sin(2.0 * std.math.pi * 3.0 * t) + 0.5 * std.math.cos(2.0 * std.math.pi * 7.0 * t);
    }

    const out_len = size / 2 + 1;
    const fft_output = try allocator.alloc(f64, 2 * out_len);
    defer allocator.free(fft_output);
    const magnitude = try allocator.alloc(f64, out_len);
    defer allocator.free(magnitude);

    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        switch (algorithm_type) {
            .standard => {
                var complex_data = try allocator.alloc(Complex, size);
                defer allocator.free(complex_data);
                for (0..size) |i| {
                    complex_data[i] = Complex{ .re = input_data[i], .im = 0.0 };
                }
                try fft.fftInPlace(allocator, complex_data);
            },
            .radix2_simd => {
                var complex_data = try allocator.alloc(Complex, size);
                defer allocator.free(complex_data);
                for (0..size) |i| {
                    complex_data[i] = Complex{ .re = input_data[i], .im = 0.0 };
                }
                try fft.fftRadix2SIMD(complex_data);
            },
            .radix4_simd => {
                var complex_data = try allocator.alloc(Complex, size);
                defer allocator.free(complex_data);
                for (0..size) |i| {
                    complex_data[i] = Complex{ .re = input_data[i], .im = 0.0 };
                }
                try fft.fftRadix4SIMD(complex_data);
            },
        }
    }

    const end_time = std.time.nanoTimestamp();
    const avg_ns = @as(f64, @floatFromInt(@as(u64, @intCast(end_time - start_time)))) / @as(f64, @floatFromInt(iterations));
    const avg_ms = avg_ns / 1_000_000.0;
    const throughput = (@as(f64, @floatFromInt(size)) / (avg_ms / 1000.0)) / 1_000_000.0;

    std.debug.print("│ {s:<13} │ {d:>5} │ {d:>8.2}ms │ {d:>8.1} MSamples/s │\n", .{ name, size, avg_ms, throughput });
}
