const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn approx_entropy_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn approx_entropy_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn approx_entropy_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const m = 2;
    const n = data.len * 8;
    if (n < 10) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };

    // 读取所有位到数组，便于循环补齐
    var bit_arr = std.heap.page_allocator.alloc(u8, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(bit_arr);
    for (0..n) |i| {
        bit_arr[i] = if (bits.fetchBit()) |b| b else 0;
    }

    var counts_m = [_]usize{0} ** (1 << m);
    var counts_m1 = [_]usize{0} ** (1 << (m + 1));

    // 统计 m 位模板
    for (0..n) |i| {
        var idx: usize = 0;
        for (0..m) |j| {
            idx = (idx << 1) | bit_arr[(i + j) % n];
        }
        counts_m[idx] += 1;
    }
    // 统计 m+1 位模板
    for (0..n) |i| {
        var idx: usize = 0;
        for (0..(m + 1)) |j| {
            idx = (idx << 1) | bit_arr[(i + j) % n];
        }
        counts_m1[idx] += 1;
    }

    var sum_m: f64 = 0.0;
    for (counts_m) |c| {
        if (c > 0) {
            const p = @as(f64, @floatFromInt(c)) / @as(f64, @floatFromInt(n));
            sum_m += p * @log2(p);
        }
    }
    var sum_m1: f64 = 0.0;
    for (counts_m1) |c| {
        if (c > 0) {
            const p = @as(f64, @floatFromInt(c)) / @as(f64, @floatFromInt(n));
            sum_m1 += p * @log2(p);
        }
    }

    const ap_en = sum_m - sum_m1;
    const chi2 = 2.0 * @as(f64, @floatFromInt(n)) * (@log(2.0) - ap_en);
    const df = @as(f64, @floatFromInt(1 << m));
    const p_value = math.igamc(df / 2.0, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = chi2,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn approxEntropyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "ApproxEntropy",
        .param = param_ptr,
        ._init = approx_entropy_init,
        ._iterate = approx_entropy_iterate,
        ._destroy = approx_entropy_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
