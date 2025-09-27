const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

/// 执行实数到复数 FFT 并计算幅值谱
pub fn compute_r2c_fft(
    self: *detect.StatDetect,
    x: []const f64, // 输入实数数据
    fft_out: []f64, // 输出复数数组 (交替存储 re, im)
    fft_m: []f64, // 输出幅值谱
) !void {
    const c = @cImport({
        @cInclude("gsl/gsl_fft_real.h");
        @cInclude("gsl/gsl_fft_halfcomplex.h");
    });

    const n = x.len;
    const out_len = n / 2 + 1; // 复数输出的长度 (半复数格式)

    // 1. 检查输出缓冲区大小
    if (fft_out.len < 2 * out_len) return error.BufferTooSmall;
    if (fft_m.len < out_len) return error.BufferTooSmall;

    // 2. 复制输入数据到临时数组 (GSL 会原地修改数据)
    const tmp = try self.allocator.alloc(f64, n);
    defer self.allocator.free(tmp);
    @memcpy(tmp, x);

    // 3. 初始化 GSL FFT
    const workspace = c.gsl_fft_real_workspace_alloc(n);
    defer c.gsl_fft_real_workspace_free(workspace);
    const wavetable = c.gsl_fft_real_wavetable_alloc(n);
    defer c.gsl_fft_real_wavetable_free(wavetable);

    // 4. 执行实数 FFT (结果以半复数格式存储在 tmp 中)
    _ = c.gsl_fft_real_transform(tmp.ptr, 1, n, wavetable, workspace);

    // 5. 转换为 FFTW 兼容的复数格式 (交替存储 re, im)
    fft_out[0] = tmp[0]; // 直流分量 (纯实数)
    fft_out[1] = 0.0; // 对应的虚部为 0

    for (1..out_len) |k| {
        const re = tmp[2 * k - 1];
        const im = if (k < n / 2) tmp[2 * k] else 0.0; // 处理 Nyquist 频率
        fft_out[2 * k] = re;
        fft_out[2 * k + 1] = im;
    }

    // 6. 计算幅值谱
    for (0..out_len) |i| {
        const re = fft_out[2 * i];
        const im = fft_out[2 * i + 1];
        fft_m[i] = std.math.sqrt(re * re + im * im);
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
