const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

const c = @cImport({
    @cInclude("fftw3.h");
});

fn dft_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn dft_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    var bits = io.BitStream.init(data);
    const n = self.param.num_bitstreams;

    var x = std.heap.page_allocator.alloc(f64, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(x);

    for (0..n) |i| {
        x[i] = if (bits.fetchBit()) |b| if (b == 1) 1.0 else -1.0 else -1.0;
    }

    // FFTW 输出长度为 n/2+1 个复数
    const out_len = n / 2 + 1;
    const fft_out = std.heap.page_allocator.alloc(c.fftw_complex, out_len) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(fft_out);

    // 创建 FFTW 计划
    const plan = c.fftw_plan_dft_r2c_1d(
        @as(c_int, @intCast(n)),
        @as([*]f64, @ptrCast(x.ptr)),
        @as([*]c.fftw_complex, @ptrCast(fft_out.ptr)),
        c.FFTW_ESTIMATE,
    );
    defer c.fftw_destroy_plan(plan);

    c.fftw_execute(plan);

    // 计算幅值谱
    var fft_m = std.heap.page_allocator.alloc(f64, out_len) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(fft_m);

    for (0..out_len) |i| {
        const re = fft_out[i][0];
        const im = fft_out[i][1];
        fft_m[i] = std.math.sqrt(re * re + im * im);
    }

    // 理论期望 N0
    const N0 = 0.95 / 2.0 * @as(f64, @floatFromInt(n));

    // 阈值
    const threshold = std.math.sqrt(2.995732274 * @as(f64, @floatFromInt(n)));
    // 统计低于阈值的峰值数量 N1
    var N1: usize = 0;
    for (0.. (n / 2)) |k| {
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
        ._init = dft_init,
        ._iterate = dft_iterate,
        ._destroy = dft_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
