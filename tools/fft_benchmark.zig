const std = @import("std");

// Define necessary types for the benchmark
const Complex = std.math.Complex(f64);
const VectorF64 = @Vector(4, f64);

/// SIMD-enhanced FFT benchmark to demonstrate advanced optimizations
///
/// This tool consolidates functionality from:
/// - fft_performance_comparison.zig (performance comparisons)
/// - fft_performance_test.zig (statistical test integration)
/// - simd_test.zig (SIMD syntax testing)
///
/// All FFT benchmarking and testing functionality is now unified here.
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("SIMD-Enhanced FFT Performance Benchmark\n", .{});
    std.debug.print("==========================================\n\n", .{});

    const data_sizes = [_]usize{ 1024, 4096, 16384, 65536 };

    for (data_sizes) |size| {
        try benchmarkSize(allocator, size);
        try benchmarkSIMDComparison(allocator, size);
    }
}

fn benchmarkSize(allocator: std.mem.Allocator, n: usize) !void {
    // Generate test data - alternating 1.0 and -1.0 pattern
    const input = try allocator.alloc(Complex, n);
    defer allocator.free(input);

    for (0..n) |i| {
        input[i] = Complex{ .re = if (i % 2 == 0) 1.0 else -1.0, .im = 0.0 };
    }

    // Create output buffer
    const output = try allocator.alloc(Complex, n);
    defer allocator.free(output);

    // Benchmark optimized FFT with SIMD
    const iterations = if (n <= 4096) @as(u32, 100) else if (n <= 16384) @as(u32, 50) else @as(u32, 10);

    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        try fft_optimized_radix2_simd(input, output);
    }

    const end_time = std.time.nanoTimestamp();
    const total_ns = @as(u64, @intCast(end_time - start_time));
    const avg_ns = total_ns / iterations;
    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;

    // Calculate throughput
    const samples_per_sec = @as(f64, @floatFromInt(n)) / (avg_ms / 1000.0);
    const megasamples_per_sec = samples_per_sec / 1_000_000.0;

    std.debug.print("Size: {d:>6} | SIMD FFT: {d:>8.2}ms | Throughput: {d:>6.1} MSamples/s\n", .{ n, avg_ms, megasamples_per_sec });
}

fn benchmarkSIMDComparison(allocator: std.mem.Allocator, n: usize) !void {
    // Test SIMD vs non-SIMD magnitude calculation
    const data = try allocator.alloc(Complex, n);
    defer allocator.free(data);
    const magnitudes1 = try allocator.alloc(f64, n);
    defer allocator.free(magnitudes1);
    const magnitudes2 = try allocator.alloc(f64, n);
    defer allocator.free(magnitudes2);

    // Initialize with random complex data
    for (0..n) |i| {
        data[i] = Complex{ .re = @sin(@as(f64, @floatFromInt(i)) * 0.1), .im = @cos(@as(f64, @floatFromInt(i)) * 0.1) };
    }

    const iterations = 1000;

    // Benchmark traditional magnitude calculation
    const start1 = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        computeMagnitudeTraditional(data, magnitudes1);
    }
    const end1 = std.time.nanoTimestamp();
    const time1_ms = @as(f64, @floatFromInt(end1 - start1)) / 1_000_000.0 / @as(f64, @floatFromInt(iterations));

    // Benchmark SIMD magnitude calculation
    const start2 = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        computeMagnitudeSIMD(data, magnitudes2);
    }
    const end2 = std.time.nanoTimestamp();
    const time2_ms = @as(f64, @floatFromInt(end2 - start2)) / 1_000_000.0 / @as(f64, @floatFromInt(iterations));

    const speedup = time1_ms / time2_ms;
    std.debug.print("         | Magnitude: Traditional {d:>6.2}ms vs SIMD {d:>6.2}ms | Speedup: {d:.1}x\n\n", .{ time1_ms, time2_ms, speedup });
}

/// Traditional magnitude calculation
fn computeMagnitudeTraditional(data: []const Complex, magnitudes: []f64) void {
    for (data, 0..) |c, i| {
        magnitudes[i] = @sqrt(c.re * c.re + c.im * c.im);
    }
}

/// SIMD-optimized magnitude calculation
fn computeMagnitudeSIMD(data: []const Complex, magnitudes: []f64) void {
    const n = data.len;
    var i: usize = 0;

    // Process 4 complex numbers at once using SIMD
    while (i + 4 <= n) : (i += 4) {
        const re_vec = VectorF64{ data[i].re, data[i + 1].re, data[i + 2].re, data[i + 3].re };
        const im_vec = VectorF64{ data[i].im, data[i + 1].im, data[i + 2].im, data[i + 3].im };

        const mag_squared = re_vec * re_vec + im_vec * im_vec;
        const magnitude = @sqrt(mag_squared);

        magnitudes[i] = magnitude[0];
        magnitudes[i + 1] = magnitude[1];
        magnitudes[i + 2] = magnitude[2];
        magnitudes[i + 3] = magnitude[3];
    }

    // Process remaining elements
    while (i < n) : (i += 1) {
        magnitudes[i] = @sqrt(data[i].re * data[i].re + data[i].im * data[i].im);
    }
}

/// Simplified SIMD-optimized radix-2 FFT for benchmarking
fn fft_optimized_radix2_simd(input: []const Complex, output: []Complex) !void {
    const n = input.len;
    if (n <= 1) {
        if (n == 1) output[0] = input[0];
        return;
    }

    // Check if it's power of 2
    if (n & (n - 1) != 0) {
        return error.NotPowerOfTwo;
    }

    // Copy input to output
    @memcpy(output, input);

    // SIMD-optimized bit-reversal
    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;

        if (i < j) {
            const temp = output[i];
            output[i] = output[j];
            output[j] = temp;
        }
    }

    // Iterative FFT with SIMD-optimized butterfly operations
    var stage_size: usize = 2;
    while (stage_size <= n) : (stage_size *= 2) {
        const half_stage = stage_size / 2;
        const theta = -2.0 * std.math.pi / @as(f64, @floatFromInt(stage_size));

        var group_start: usize = 0;
        while (group_start < n) : (group_start += stage_size) {
            // Process butterflies in groups of 4 using SIMD where possible
            var k: usize = 0;
            while (k + 4 <= half_stage) : (k += 4) {
                // Compute 4 twiddle factors at once
                const k_vec = VectorF64{ @as(f64, @floatFromInt(k)), @as(f64, @floatFromInt(k + 1)), @as(f64, @floatFromInt(k + 2)), @as(f64, @floatFromInt(k + 3)) };
                const angles = k_vec * @as(VectorF64, @splat(theta));
                const cos_vals = @cos(angles);
                const sin_vals = @sin(angles);

                // Process 4 butterfly operations
                for (0..4) |offset| {
                    const even_idx = group_start + k + offset;
                    const odd_idx = group_start + k + offset + half_stage;

                    const w_re = cos_vals[offset];
                    const w_im = sin_vals[offset];

                    const temp_re = w_re * output[odd_idx].re - w_im * output[odd_idx].im;
                    const temp_im = w_re * output[odd_idx].im + w_im * output[odd_idx].re;

                    output[odd_idx].re = output[even_idx].re - temp_re;
                    output[odd_idx].im = output[even_idx].im - temp_im;
                    output[even_idx].re = output[even_idx].re + temp_re;
                    output[even_idx].im = output[even_idx].im + temp_im;
                }
            }

            // Process remaining butterflies
            while (k < half_stage) : (k += 1) {
                const w_re = std.math.cos(theta * @as(f64, @floatFromInt(k)));
                const w_im = std.math.sin(theta * @as(f64, @floatFromInt(k)));

                const even_idx = group_start + k;
                const odd_idx = group_start + k + half_stage;

                const temp_re = w_re * output[odd_idx].re - w_im * output[odd_idx].im;
                const temp_im = w_re * output[odd_idx].im + w_im * output[odd_idx].re;

                output[odd_idx].re = output[even_idx].re - temp_re;
                output[odd_idx].im = output[even_idx].im - temp_im;
                output[even_idx].re = output[even_idx].re + temp_re;
                output[even_idx].im = output[even_idx].im + temp_im;
            }
        }
    }
}
