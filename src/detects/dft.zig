const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

// 使用 Zig 标准库的复数类型
const Complex = std.math.Complex(f64);

/// 执行实数到复数 FFT 并计算幅值谱
/// 纯 Zig 实现，使用 std.math.Complex 和迭代算法
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

    // 2. 创建复数输入数组
    const complex_input = try self.allocator.alloc(Complex, n);
    defer self.allocator.free(complex_input);

    for (0..n) |i| {
        complex_input[i] = Complex{ .re = x[i], .im = 0.0 };
    }

    // 3. 执行 FFT
    const complex_output = try self.allocator.alloc(Complex, n);
    defer self.allocator.free(complex_output);

    try fft_iterative(complex_input, complex_output);

    // 4. 转换为交替存储格式并计算幅值谱
    for (0..out_len) |i| {
        fft_out[2 * i] = complex_output[i].re;
        fft_out[2 * i + 1] = complex_output[i].im;
        fft_m[i] = complex_output[i].magnitude();
    }
}

/// 迭代实现的 Cooley-Tukey FFT 算法
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

/// 执行 bit-reversal 排列
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

/// 反转一个整数的二进制位
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

/// 直接离散傅里叶变换 (DFT) 实现
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
    _ = self;
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
