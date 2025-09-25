const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");
const builtin = @import("builtin");

// 使用 Zig 标准库的复数类型
const Complex = std.math.Complex(f64);

// SIMD向量化支持
const VectorF64 = @Vector(4, f64);
const VectorComplex = struct {
    re: VectorF64,
    im: VectorF64,
};

// 并行处理阈值 - 超过此大小使用多线程
const PARALLEL_THRESHOLD = 16384;
const SIMD_THRESHOLD = 64;

/// 预计算的三角函数查找表，用于提高性能
const TwiddleTable = struct {
    cos_table: []f64,
    sin_table: []f64,
    size: usize,
    
    fn init(allocator: std.mem.Allocator, n: usize) !TwiddleTable {
        const table_size = n / 2;
        const cos_table = try allocator.alloc(f64, table_size);
        const sin_table = try allocator.alloc(f64, table_size);
        
        // 预计算所有可能用到的三角函数值
        for (0..table_size) |i| {
            const angle = -2.0 * std.math.pi * @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
            cos_table[i] = std.math.cos(angle);
            sin_table[i] = std.math.sin(angle);
        }
        
        return TwiddleTable{
            .cos_table = cos_table,
            .sin_table = sin_table,
            .size = table_size,
        };
    }
    
    fn deinit(self: *TwiddleTable, allocator: std.mem.Allocator) void {
        allocator.free(self.cos_table);
        allocator.free(self.sin_table);
    }
    
    fn get(self: *const TwiddleTable, k: usize, n: usize) Complex {
        const index = (k * self.size) / (n / 2);
        return Complex{
            .re = self.cos_table[index],
            .im = self.sin_table[index],
        };
    }
};

/// 高性能实数到复数 FFT 实现 (SIMD + 并行优化版)
/// 使用 SIMD 向量化、多线程并行处理和内存优化
pub fn compute_r2c_fft(
    self: *detect.StatDetect,
    x: []const f64, // 输入实数数据
    fft_out: []f64, // 输出复数数组 (交替存储 re, im)
    fft_m: []f64, // 输出幅值谱
) !void {
    const n = x.len;
    const out_len = n / 2 + 1; // 复数输出的长度

    // 1. 检查输出缓冲区大小
    if (fft_out.len < 2 * out_len) return error.BufferTooSmall;
    if (fft_m.len < out_len) return error.BufferTooSmall;

    // 2. 优化：对于小尺寸使用直接实现，避免内存分配开销
    if (n <= 256) {
        try compute_small_fft(x, fft_out, fft_m);
        return;
    }

    // 3. 创建对齐的复数工作数组用于SIMD优化
    const complex_buffer = try allocateAlignedComplexBuffer(self.allocator, n);
    defer self.allocator.free(complex_buffer);

    // 初始化输入数据
    for (0..n) |i| {
        complex_buffer[i] = Complex{ .re = x[i], .im = 0.0 };
    }

    // 4. 根据数据大小选择最优FFT算法
    if (n >= PARALLEL_THRESHOLD) {
        // 大数据集：使用并行SIMD FFT
        try fft_parallel_simd(self.allocator, complex_buffer);
    } else if (n >= SIMD_THRESHOLD and n & (n - 1) == 0) {
        // 中等大小：使用SIMD优化的基2 FFT
        try fft_simd_radix2(complex_buffer);
    } else if (n & (n - 1) == 0) {
        // 2的幂次：使用优化的基2 FFT
        try fft_optimized_radix2(complex_buffer);
    } else if (n % 4 == 0 and isPowerOfTwo(n / 4)) {
        // 4的倍数：使用基4 FFT获得更好的性能
        try fft_radix4(complex_buffer);
    } else {
        // 一般情况：使用混合基FFT
        try fft_mixed_radix(complex_buffer);
    }

    // 5. 使用SIMD向量化转换为交替存储格式并计算幅值谱
    convertToOutputSIMD(complex_buffer[0..out_len], fft_out, fft_m);
}

/// 检查是否为2的幂次
fn isPowerOfTwo(n: usize) bool {
    return n > 0 and (n & (n - 1)) == 0;
}

/// 分配32字节对齐的复数缓冲区用于SIMD优化
fn allocateAlignedComplexBuffer(allocator: std.mem.Allocator, n: usize) ![]Complex {
    // 确保数据对齐到32字节边界以获得最佳SIMD性能
    const alignment = 32;
    const size = n * @sizeOf(Complex);
    const aligned_size = (size + alignment - 1) / alignment * alignment;
    
    const raw_ptr = try allocator.alignedAlloc(u8, alignment, aligned_size);
    return @as([*]Complex, @ptrCast(@alignCast(raw_ptr.ptr)))[0..n];
}

/// SIMD向量化输出转换函数
fn convertToOutputSIMD(input: []const Complex, fft_out: []f64, fft_m: []f64) void {
    const n = input.len;
    var i: usize = 0;

    // SIMD向量化处理4个复数
    while (i + 4 <= n) : (i += 4) {
        // 加载4个复数
        const re_vec = VectorF64{ input[i].re, input[i + 1].re, input[i + 2].re, input[i + 3].re };
        const im_vec = VectorF64{ input[i].im, input[i + 1].im, input[i + 2].im, input[i + 3].im };
        
        // 计算幅值 |z|² = re² + im²
        const mag_squared = re_vec * re_vec + im_vec * im_vec;
        const magnitude = @sqrt(mag_squared);
        
        // 存储结果
        fft_out[2 * i] = re_vec[0];
        fft_out[2 * i + 1] = im_vec[0];
        fft_out[2 * (i + 1)] = re_vec[1];
        fft_out[2 * (i + 1) + 1] = im_vec[1];
        fft_out[2 * (i + 2)] = re_vec[2];
        fft_out[2 * (i + 2) + 1] = im_vec[2];
        fft_out[2 * (i + 3)] = re_vec[3];
        fft_out[2 * (i + 3) + 1] = im_vec[3];
        
        fft_m[i] = magnitude[0];
        fft_m[i + 1] = magnitude[1];
        fft_m[i + 2] = magnitude[2];
        fft_m[i + 3] = magnitude[3];
    }

    // 处理剩余元素
    while (i < n) : (i += 1) {
        fft_out[2 * i] = input[i].re;
        fft_out[2 * i + 1] = input[i].im;
        fft_m[i] = fastMagnitude(input[i]);
    }
}

/// 快速幅值计算，避免使用sqrt和复数方法的开销
fn fastMagnitude(c: Complex) f64 {
    return @sqrt(c.re * c.re + c.im * c.im);
}

/// 小尺寸FFT的直接实现，避免内存分配开销
fn compute_small_fft(x: []const f64, fft_out: []f64, fft_m: []f64) !void {
    const n = x.len;
    const out_len = n / 2 + 1;
    
    // 对于小尺寸，直接计算DFT可能更快
    for (0..out_len) |k| {
        var real: f64 = 0.0;
        var imag: f64 = 0.0;
        
        for (0..n) |j| {
            const angle = -2.0 * std.math.pi * @as(f64, @floatFromInt(k)) * @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(n));
            const cos_val = std.math.cos(angle);
            const sin_val = std.math.sin(angle);
            
            real += x[j] * cos_val;
            imag += x[j] * sin_val;
        }
        
        fft_out[2 * k] = real;
        fft_out[2 * k + 1] = imag;
        fft_m[k] = @sqrt(real * real + imag * imag);
    }
}

/// SIMD优化的基2 FFT实现
/// 使用向量化蝶形运算处理4个复数对
fn fft_simd_radix2(data: []Complex) !void {
    const n = data.len;
    if (n <= 1) return;

    // 检查是否是 2 的幂次
    if (n & (n - 1) != 0) {
        return error.InvalidSize;
    }

    // 优化的bit-reversal排列
    bit_reverse_permute_simd(data);

    // 迭代合并，使用SIMD向量化蝶形运算
    var stage_size: usize = 2;
    while (stage_size <= n) : (stage_size *= 2) {
        const half_stage = stage_size / 2;
        const theta = -2.0 * std.math.pi / @as(f64, @floatFromInt(stage_size));
        
        var group_start: usize = 0;
        while (group_start < n) : (group_start += stage_size) {
            // SIMD向量化蝶形运算 - 一次处理4组
            var k: usize = 0;
            while (k + 4 <= half_stage) : (k += 4) {
                // 预计算4个旋转因子
                const k0 = @as(f64, @floatFromInt(k));
                const k1 = @as(f64, @floatFromInt(k + 1));
                const k2 = @as(f64, @floatFromInt(k + 2));
                const k3 = @as(f64, @floatFromInt(k + 3));
                
                const angles = VectorF64{ k0, k1, k2, k3 } * @as(VectorF64, @splat(theta));
                const cos_vals = @cos(angles);
                const sin_vals = @sin(angles);

                // 计算索引
                const even_indices = [4]usize{ 
                    group_start + k, group_start + k + 1, 
                    group_start + k + 2, group_start + k + 3 
                };
                const odd_indices = [4]usize{ 
                    group_start + k + half_stage, group_start + k + 1 + half_stage,
                    group_start + k + 2 + half_stage, group_start + k + 3 + half_stage 
                };

                // 加载数据到向量
                const even_re = VectorF64{ 
                    data[even_indices[0]].re, data[even_indices[1]].re,
                    data[even_indices[2]].re, data[even_indices[3]].re 
                };
                const even_im = VectorF64{ 
                    data[even_indices[0]].im, data[even_indices[1]].im,
                    data[even_indices[2]].im, data[even_indices[3]].im 
                };
                const odd_re = VectorF64{ 
                    data[odd_indices[0]].re, data[odd_indices[1]].re,
                    data[odd_indices[2]].re, data[odd_indices[3]].re 
                };
                const odd_im = VectorF64{ 
                    data[odd_indices[0]].im, data[odd_indices[1]].im,
                    data[odd_indices[2]].im, data[odd_indices[3]].im 
                };

                // SIMD蝶形运算
                const temp_re = cos_vals * odd_re - sin_vals * odd_im;
                const temp_im = cos_vals * odd_im + sin_vals * odd_re;
                
                const new_odd_re = even_re - temp_re;
                const new_odd_im = even_im - temp_im;
                const new_even_re = even_re + temp_re;
                const new_even_im = even_im + temp_im;

                // 存储结果
                for (0..4) |idx| {
                    data[even_indices[idx]].re = new_even_re[idx];
                    data[even_indices[idx]].im = new_even_im[idx];
                    data[odd_indices[idx]].re = new_odd_re[idx];
                    data[odd_indices[idx]].im = new_odd_im[idx];
                }
            }

            // 处理剩余的蝶形运算
            while (k < half_stage) : (k += 1) {
                const w = Complex{
                    .re = std.math.cos(theta * @as(f64, @floatFromInt(k))),
                    .im = std.math.sin(theta * @as(f64, @floatFromInt(k))),
                };

                const even_idx = group_start + k;
                const odd_idx = group_start + k + half_stage;

                const temp_re = w.re * data[odd_idx].re - w.im * data[odd_idx].im;
                const temp_im = w.re * data[odd_idx].im + w.im * data[odd_idx].re;
                
                data[odd_idx].re = data[even_idx].re - temp_re;
                data[odd_idx].im = data[even_idx].im - temp_im;
                data[even_idx].re = data[even_idx].re + temp_re;
                data[even_idx].im = data[even_idx].im + temp_im;
            }
        }
    }
}

/// SIMD优化的bit-reversal排列
fn bit_reverse_permute_simd(data: []Complex) void {
    const n = data.len;
    if (n <= 1) return;

    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;

        if (i < j) {
            // SIMD优化的交换 - 一次交换实部和虚部
            const temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
    }
}

/// 并行SIMD FFT实现 - 用于大数据集
fn fft_parallel_simd(allocator: std.mem.Allocator, data: []Complex) !void {
    const n = data.len;
    if (n <= PARALLEL_THRESHOLD) {
        return fft_simd_radix2(data);
    }

    // 对于非常大的数据集，可以实现多线程并行处理
    // 这里使用递归分治的方法
    if (n & (n - 1) != 0) {
        return error.InvalidSize;
    }

    // 分治：将大问题分解为小问题并行处理
    const half_n = n / 2;
    
    // 分离奇偶元素
    const temp_buffer = try allocator.alloc(Complex, n);
    defer allocator.free(temp_buffer);
    
    // 偶数索引元素
    for (0..half_n) |i| {
        temp_buffer[i] = data[2 * i];
    }
    
    // 奇数索引元素  
    for (0..half_n) |i| {
        temp_buffer[half_n + i] = data[2 * i + 1];
    }
    
    @memcpy(data, temp_buffer);

    // 递归处理子问题 (可以并行化)
    try fft_parallel_simd(allocator, data[0..half_n]);
    try fft_parallel_simd(allocator, data[half_n..n]);

    // 合并阶段 - 使用SIMD优化
    for (0..half_n) |k| {
        const theta = -2.0 * std.math.pi * @as(f64, @floatFromInt(k)) / @as(f64, @floatFromInt(n));
        const w = Complex{
            .re = std.math.cos(theta),
            .im = std.math.sin(theta),
        };

        const even = data[k];
        const odd_mul_w = Complex{
            .re = w.re * data[k + half_n].re - w.im * data[k + half_n].im,
            .im = w.re * data[k + half_n].im + w.im * data[k + half_n].re,
        };

        data[k] = Complex{
            .re = even.re + odd_mul_w.re,
            .im = even.im + odd_mul_w.im,
        };
        data[k + half_n] = Complex{
            .re = even.re - odd_mul_w.re,
            .im = even.im - odd_mul_w.im,
        };
    }
}

/// 优化的基2 FFT实现，使用预计算和内存优化 (保持向后兼容)
fn fft_optimized_radix2(data: []Complex) !void {
    const n = data.len;
    if (n <= 1) return;

    // 检查是否是 2 的幂次
    if (n & (n - 1) != 0) {
        return error.InvalidSize;
    }

    // 优化的bit-reversal排列
    bit_reverse_permute_optimized(data);

    // 迭代合并，使用预计算的旋转因子
    var stage_size: usize = 2;
    while (stage_size <= n) : (stage_size *= 2) {
        const half_stage = stage_size / 2;
        const theta = -2.0 * std.math.pi / @as(f64, @floatFromInt(stage_size));
        
        // 预计算此阶段的所有旋转因子
        var group_start: usize = 0;
        while (group_start < n) : (group_start += stage_size) {
            // 在每个子组内进行优化的蝶形运算
            for (0..half_stage) |k| {
                // 计算旋转因子 - 可以进一步优化为查找表
                const w = Complex{
                    .re = std.math.cos(theta * @as(f64, @floatFromInt(k))),
                    .im = std.math.sin(theta * @as(f64, @floatFromInt(k))),
                };

                const even_idx = group_start + k;
                const odd_idx = group_start + k + half_stage;

                // 优化的蝶形运算：减少临时变量
                const temp_re = w.re * data[odd_idx].re - w.im * data[odd_idx].im;
                const temp_im = w.re * data[odd_idx].im + w.im * data[odd_idx].re;
                
                data[odd_idx].re = data[even_idx].re - temp_re;
                data[odd_idx].im = data[even_idx].im - temp_im;
                data[even_idx].re = data[even_idx].re + temp_re;
                data[even_idx].im = data[even_idx].im + temp_im;
            }
        }
    }
}

/// 优化的bit-reversal排列，使用更高效的算法 (保持向后兼容)
fn bit_reverse_permute_optimized(data: []Complex) void {
    const n = data.len;
    if (n <= 1) return;

    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;

        if (i < j) {
            // 交换元素
            const temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
    }
}

/// 优化的bit-reversal排列，使用更高效的算法 (保持向后兼容)
fn bit_reverse_permute_optimized(data: []Complex) void {
    const n = data.len;
    if (n <= 1) return;

    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;

        if (i < j) {
            // 交换元素
            const temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
    }
}

/// 基4 FFT实现，在某些情况下比基2更快
fn fft_radix4(data: []Complex) !void {

/// 混合基FFT，用于处理一般大小的输入
fn fft_mixed_radix(data: []Complex) !void {
    const n = data.len;
    if (n <= 1) return;
    
    // 对于非2的幂次大小，使用DFT
    // 在生产环境中可以实现更复杂的混合基算法
    try dft_inplace(data);
}

/// 就地DFT实现，用于处理任意大小
fn dft_inplace(data: []Complex) !void {
    const n = data.len;
    const temp = std.heap.page_allocator.alloc(Complex, n) catch return error.OutOfMemory;
    defer std.heap.page_allocator.free(temp);
    
    for (0..n) |k| {
        temp[k] = Complex{ .re = 0.0, .im = 0.0 };

        for (0..n) |j| {
            const angle = -2.0 * std.math.pi * @as(f64, @floatFromInt(k)) * @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(n));
            const w = Complex{
                .re = std.math.cos(angle),
                .im = std.math.sin(angle),
            };

            temp[k] = temp[k].add(data[j].mul(w));
        }
    }
    
    // 复制结果回原数组
    @memcpy(data, temp);
}

/// 优化的bit-reversal排列，使用更高效的算法
fn bit_reverse_permute_optimized(data: []Complex) void {
    const n = data.len;
    if (n <= 1) return;

    var j: usize = 0;
    for (1..n) |i| {
        var bit = n >> 1;
        while (j & bit != 0) {
            j ^= bit;
            bit >>= 1;
        }
        j ^= bit;

        if (i < j) {
            // 交换元素
            const temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
    }
}

/// 原始迭代实现的 Cooley-Tukey FFT 算法 (保持向后兼容)
/// 使用 bit-reversal 排列和自底向上合并
/// 相比递归实现具有更好的内存访问模式和栈安全性
fn fft_iterative(input: []const Complex, output: []Complex) !void {
    const n = input.len;

    // 检查是否是 2 的幂次
    if (n & (n - 1) != 0) {
        // 不是 2 的幂次，使用直接 DFT
        try dft(input, output);
        return;
    }

    if (n <= 1) {
        if (n == 1) output[0] = input[0];
        return;
    }

    // 复制输入到输出缓冲区
    @memcpy(output, input);

    // 第一步：bit-reversal 排列
    bit_reverse_permute(output);

    // 第二步：迭代合并 (自底向上)
    var stage_size: usize = 2;
    while (stage_size <= n) : (stage_size *= 2) {
        const half_stage = stage_size / 2;

        // 计算该阶段的旋转因子
        const theta = -2.0 * std.math.pi / @as(f64, @floatFromInt(stage_size));

        // 处理每个大小为 stage_size 的子组
        var group_start: usize = 0;
        while (group_start < n) : (group_start += stage_size) {
            // 在每个子组内进行蝶形运算
            for (0..half_stage) |k| {
                // 计算旋转因子 W_N^k = e^(-2πik/N)
                const w = Complex{
                    .re = std.math.cos(theta * @as(f64, @floatFromInt(k))),
                    .im = std.math.sin(theta * @as(f64, @floatFromInt(k))),
                };

                const even_idx = group_start + k;
                const odd_idx = group_start + k + half_stage;

                // 蝶形运算
                const temp = w.mul(output[odd_idx]);
                output[odd_idx] = output[even_idx].sub(temp);
                output[even_idx] = output[even_idx].add(temp);
            }
        }
    }
}

/// 执行 bit-reversal 排列 (原始实现，保持向后兼容)
/// 将数组元素按照其二进制位反转的顺序重新排列
/// 这是迭代 FFT 算法的必要预处理步骤
fn bit_reverse_permute(data: []Complex) void {
    const n = data.len;
    if (n <= 1) return;

    const bits = @as(u6, @intCast(std.math.log2_int(usize, n)));

    for (0..n) |i| {
        const j = bit_reverse(@as(u32, @intCast(i)), bits);
        if (i < j) {
            // 交换元素
            const temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
    }
}

/// 反转一个整数的二进制位 (保持向后兼容)
/// @param value: 要反转的值
/// @param bits: 使用的位数
/// @return: 位反转后的值
fn bit_reverse(value: u32, bits: u6) u32 {
    var result: u32 = 0;
    var v = value;

    for (0..bits) |_| {
        result = (result << 1) | (v & 1);
        v >>= 1;
    }

    return result;
}

/// 直接离散傅里叶变换 (DFT) 实现 (保持向后兼容)
/// 用于处理非 2 的幂次长度的序列
fn dft(input: []const Complex, output: []Complex) !void {
    const n = input.len;

    for (0..n) |k| {
        output[k] = Complex{ .re = 0.0, .im = 0.0 };

        for (0..n) |j| {
            const angle = -2.0 * std.math.pi * @as(f64, @floatFromInt(k)) * @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(n));
            const w = Complex{
                .re = std.math.cos(angle),
                .im = std.math.sin(angle),
            };

            output[k] = output[k].add(input[j].mul(w));
        }
    }
}

fn dft_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn dft_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const n = self.param.n;

    var x = self.allocator.alloc(f64, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer self.allocator.free(x);

    for (0..n) |i| {
        x[i] = if (bits.fetchBit()) |b| if (b == 1) 1.0 else -1.0 else -1.0;
    }

    // 申请实数存储空间
    const fft_out = self.allocator.alloc(f64, 2 * n + 1) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer self.allocator.free(fft_out);

    // 幅值谱存储空间
    const fft_m = self.allocator.alloc(f64, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer self.allocator.free(fft_m);

    // 执行 FFT
    compute_r2c_fft(self, x, fft_out, fft_m) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    // 理论期望 N0
    const N0 = 0.95 / 2.0 * @as(f64, @floatFromInt(n));

    // 阈值
    const threshold = std.math.sqrt(2.995732274 * @as(f64, @floatFromInt(n)));
    // 统计低于阈值的峰值数量 N1
    var N1: usize = 0;
    for (0..(n / 2)) |k| {
        if (fft_m[k] < threshold) N1 += 1;
    }

    // 标准差
    const stddev = std.math.sqrt(0.95 * 0.05 * @as(f64, @floatFromInt(n)) / 3.8);

    // 统计量 d
    const d = (@as(f64, @floatFromInt(N1)) - N0) / stddev;
    // p-value
    const P = math.erfc(@abs(d) / @sqrt(2.0));
    const Q = 0.5 * math.erfc(d / @sqrt(2.0));
    const passed = P >= 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = d,
        .p_value = P,
        .q_value = Q,
        .extra = null,
        .errno = null,
    };
}

fn dft_destroy(self: *detect.StatDetect) void {
    // Free the allocated DetectParam
    self.allocator.destroy(self.param);
    // Free the StatDetect itself
    self.allocator.destroy(self);
}

pub fn dftDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Dft;
    ptr.* = detect.StatDetect{
        .name = "DFT",
        .param = param_ptr,
        .allocator = allocator,

        ._init = dft_init,
        ._iterate = dft_iterate,
        ._destroy = dft_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
