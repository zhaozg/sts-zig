const std = @import("std");

// Define necessary types for the benchmark
const Complex = std.math.Complex(f64);

/// Simple FFT benchmark to demonstrate performance improvements
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("FFT Performance Benchmark\n", .{});
    std.debug.print("=========================\n\n", .{});

    const data_sizes = [_]usize{ 1024, 4096, 16384, 65536 };
    
    for (data_sizes) |size| {
        try benchmarkSize(allocator, size);
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

    // Benchmark optimized FFT
    const iterations = if (n <= 4096) @as(u32, 100) else if (n <= 16384) @as(u32, 50) else @as(u32, 10);
    
    const start_time = std.time.nanoTimestamp();
    
    for (0..iterations) |_| {
        try fft_optimized_radix2(input, output);
    }
    
    const end_time = std.time.nanoTimestamp();
    const total_ns = @as(u64, @intCast(end_time - start_time));
    const avg_ns = total_ns / iterations;
    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;
    
    // Calculate throughput
    const samples_per_sec = @as(f64, @floatFromInt(n)) / (avg_ms / 1000.0);
    const megasamples_per_sec = samples_per_sec / 1_000_000.0;
    
    std.debug.print("Size: {d:>6} | Avg Time: {d:>8.2}ms | Throughput: {d:>6.1} MSamples/s\n", 
          .{ n, avg_ms, megasamples_per_sec });
}

/// Simplified optimized radix-2 FFT for benchmarking
fn fft_optimized_radix2(input: []const Complex, output: []Complex) !void {
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

    // Optimized bit-reversal
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

    // Iterative FFT with optimized butterfly operations
    var stage_size: usize = 2;
    while (stage_size <= n) : (stage_size *= 2) {
        const half_stage = stage_size / 2;
        const theta = -2.0 * std.math.pi / @as(f64, @floatFromInt(stage_size));
        
        var group_start: usize = 0;
        while (group_start < n) : (group_start += stage_size) {
            for (0..half_stage) |k| {
                // Compute twiddle factor
                const w_re = std.math.cos(theta * @as(f64, @floatFromInt(k)));
                const w_im = std.math.sin(theta * @as(f64, @floatFromInt(k)));

                const even_idx = group_start + k;
                const odd_idx = group_start + k + half_stage;

                // Optimized butterfly operation
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