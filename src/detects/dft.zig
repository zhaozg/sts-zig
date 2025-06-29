const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

fn dft_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn dft_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;
    const n = data.len * 8;
    if (n < 100) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }
    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };
    var x = std.heap.page_allocator.alloc(f64, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(x);
    for (0..n) |i| {
        x[i] = if (bits.fetchBit()) |b| if (b == 1) 1.0 else -1.0 else -1.0;
    }
    // 计算 DFT 幅值谱
    const N = n / 2;
    var mag = std.heap.page_allocator.alloc(f64, N) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(mag);
    for (0..N) |k| {
        var sum_re: f64 = 0.0;
        var sum_im: f64 = 0.0;
        for (0..n) |t| {
            const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(k * t)) / @as(f64, @floatFromInt(n));
            sum_re += x[t] * std.math.cos(angle);
            sum_im -= x[t] * std.math.sin(angle);
        }
        mag[k] = std.math.sqrt(sum_re * sum_re + sum_im * sum_im);
    }
    // 阈值
    const threshold = std.math.sqrt(@log(1.0 / 0.05) * @as(f64, @floatFromInt(n)));
    var count: usize = 0;
    for (0..N) |k| {
        if (mag[k] > threshold) count += 1;
    }
    const expected = 0.95 * @as(f64, @floatFromInt(N));
    const diff = (@as(f64, @floatFromInt(count)) - expected) / std.math.sqrt(0.95 * 0.05 * @as(f64, @floatFromInt(N)) / 4.0);
    // 双侧正态分布
    const p_value = math.erfc(@abs(diff) / @sqrt(2.0));
    const passed = p_value > 0.01;
    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = diff,
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
    param_ptr.*.type = detect.DetectType.General;
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
