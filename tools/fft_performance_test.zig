const std = @import("std");

// 导入FFT实现
const zsts = @import("zsts");
const detect = zsts.detect;
const dft = zsts.dft;

// 定义复数类型以匹配实现
const Complex = std.math.Complex(f64);
const VectorF64 = @Vector(4, f64);

/// 性能测试主函数
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("FFT Performance Optimization Test\n");
    std.debug.print("=================================\n\n");

    const test_sizes = [_]usize{ 256, 512, 1024, 2048, 4096, 8192, 16384 };

    for (test_sizes) |size| {
        try benchmarkFFTSize(allocator, size);
        std.debug.print("\n");
    }

    std.debug.print("Testing algorithm selection logic...\n");
    try testAlgorithmSelection(allocator);
    
    std.debug.print("\nTesting SIMD magnitude calculation...\n");
    try testSIMDMagnitude(allocator);
}

/// 测试特定大小的FFT性能
fn benchmarkFFTSize(allocator: std.mem.Allocator, n: usize) !void {
    std.debug.print("Testing FFT size: {d}\n", .{n});

    // 创建DFT检测器来测试真实的FFT实现
    const param = detect.DetectParam{
        .type = detect.DetectType.Dft,
        .n = n,
        .extra = null,
    };

    var stat = try dft.dftDetectStatDetect(allocator, param);
    defer stat.destroy();

    // 生成测试数据
    var test_data = try allocator.alloc(u1, n);
    defer allocator.free(test_data);

    // 创建具有频域特性的测试信号
    for (0..n) |i| {
        test_data[i] = if (i % 4 < 2) 1 else 0; // 创建特定的频谱特征
    }

    // 创建位流
    const memory_stream = zsts.io.createMemoryStream(allocator, std.mem.sliceAsBytes(test_data));
    const bit_stream = zsts.io.BitInputStream.fromByteInputStreamWithLength(allocator, memory_stream, n);
    defer bit_stream.close();

    // 性能测试
    const iterations = if (n <= 1024) @as(u32, 100) else if (n <= 4096) @as(u32, 50) else @as(u32, 10);

    stat.init(stat.param);
    
    const start_time = std.time.nanoTimestamp();
    
    for (0..iterations) |_| {
        bit_stream.reset();
        stat.init(stat.param);
        _ = stat.iterate(&bit_stream);
    }
    
    const end_time = std.time.nanoTimestamp();
    
    const total_ns = @as(u64, @intCast(end_time - start_time));
    const avg_ns = total_ns / iterations;
    const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;
    const throughput = @as(f64, @floatFromInt(n)) / avg_ms * 1000.0; // samples per second
    
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Average time: {d:.3} ms\n", .{avg_ms});
    std.debug.print("  Throughput: {d:.0} samples/sec\n", .{throughput});
    std.debug.print("  Algorithm used: {s}\n", .{getAlgorithmName(n)});
}

/// 根据大小返回应该使用的算法名称
fn getAlgorithmName(n: usize) []const u8 {
    const PARALLEL_THRESHOLD = 16384;
    const RADIX4_THRESHOLD = 256;
    const SIMD_THRESHOLD = 64;
    
    if (n >= PARALLEL_THRESHOLD) {
        return "Parallel SIMD FFT";
    } else if (n >= RADIX4_THRESHOLD and isPowerOf4(n)) {
        return "Radix-4 SIMD FFT";
    } else if (n >= SIMD_THRESHOLD and isPowerOfTwo(n)) {
        return "SIMD Radix-2 FFT";
    } else if (isPowerOfTwo(n)) {
        return "Optimized Radix-2 FFT";
    } else {
        return "Mixed-Radix FFT";
    }
}

fn isPowerOfTwo(n: usize) bool {
    return n > 0 and (n & (n - 1)) == 0;
}

fn isPowerOf4(n: usize) bool {
    if (n == 0) return false;
    return isPowerOfTwo(n) and (n & 0x55555555) != 0;
}

/// 测试算法选择逻辑
fn testAlgorithmSelection(_: std.mem.Allocator) !void {
    const test_cases = [_]struct { size: usize, expected: []const u8 }{
        .{ .size = 32, .expected = "Optimized Radix-2 FFT" },
        .{ .size = 64, .expected = "SIMD Radix-2 FFT" },
        .{ .size = 256, .expected = "Radix-4 SIMD FFT" },
        .{ .size = 1024, .expected = "Radix-4 SIMD FFT" },
        .{ .size = 4096, .expected = "Radix-4 SIMD FFT" },
        .{ .size = 16384, .expected = "Parallel SIMD FFT" },
        .{ .size = 65536, .expected = "Parallel SIMD FFT" },
        .{ .size = 1000, .expected = "Mixed-Radix FFT" },
    };

    for (test_cases) |case| {
        const actual = getAlgorithmName(case.size);
        const matches = std.mem.eql(u8, actual, case.expected);
        std.debug.print("  Size {d:>6}: {s} {s}\n", .{
            case.size, 
            actual, 
            if (matches) "✓" else "✗"
        });
    }
}

/// 测试SIMD幅值计算的性能
fn testSIMDMagnitude(allocator: std.mem.Allocator) !void {
    const n = 4096;
    const iterations = 1000;
    
    // 创建测试数据
    var data = try allocator.alloc(Complex, n);
    defer allocator.free(data);
    
    var magnitudes = try allocator.alloc(f64, n);
    defer allocator.free(magnitudes);
    
    // 初始化复数数据
    for (0..n) |i| {
        const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        data[i] = Complex{
            .re = std.math.cos(angle),
            .im = std.math.sin(angle),
        };
    }
    
    // 标量版本测试
    const scalar_start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        for (0..n) |i| {
            magnitudes[i] = @sqrt(data[i].re * data[i].re + data[i].im * data[i].im);
        }
    }
    const scalar_end = std.time.nanoTimestamp();
    
    // SIMD版本测试
    const simd_start = std.time.nanoTimestamp();
    for (0..iterations) |_| {
        calculateMagnitudesSIMD(data, magnitudes);
    }
    const simd_end = std.time.nanoTimestamp();
    
    const scalar_time = @as(f64, @floatFromInt(scalar_end - scalar_start)) / 1_000_000.0;
    const simd_time = @as(f64, @floatFromInt(simd_end - simd_start)) / 1_000_000.0;
    const speedup = scalar_time / simd_time;
    
    std.debug.print("  Scalar magnitude calculation: {d:.3} ms\n", .{scalar_time});
    std.debug.print("  SIMD magnitude calculation: {d:.3} ms\n", .{simd_time});
    std.debug.print("  SIMD speedup: {d:.2}x\n", .{speedup});
}

/// SIMD优化的幅值计算
fn calculateMagnitudesSIMD(data: []const Complex, magnitudes: []f64) void {
    const n = data.len;
    var i: usize = 0;
    
    // SIMD向量化处理4个复数
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

    // 处理剩余元素
    while (i < n) : (i += 1) {
        magnitudes[i] = @sqrt(data[i].re * data[i].re + data[i].im * data[i].im);
    }
}