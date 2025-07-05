const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn run_distribution_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn run_distribution_destroy(self: *detect.StatDetect) void {
    _ = self;
}

// 理论概率（p=0.5, NIST推荐）
fn prob(k: usize, K: usize) f64 {
    if (k < K-1)
        return std.math.pow(f64, 0.5, @as(f64, @floatFromInt(k+1)));
    return std.math.pow(f64, 0.5, @as(f64, @floatFromInt(K))) * 2.0;
}

fn run_distribution_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

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

    // 区间：长度1,2,3,4,>=5，分别统计0-run和1-run
    const K = 5;
    var v0 = [_]usize{0} ** K;
    var v1 = [_]usize{0} ** K;

    var curr: u8 = bit_arr[0];
    var run: usize = 1;
    for (1..n) |i| {
        if (bit_arr[i] == curr) {
            run += 1;
        } else {
            const idx = if (run >= K) K-1 else run-1;
            if (curr == 0) v0[idx] += 1 else v1[idx] += 1;
            curr = bit_arr[i];
            run = 1;
        }
    }
    // 处理最后一个run
    const idx = if (run >= K) K-1 else run-1;
    if (curr == 0) v0[idx] += 1 else v1[idx] += 1;

    var pi = [_]f64{0} ** K;
    for (0..K) |k| pi[k] = prob(k, K);

    var chi2: f64 = 0.0;
    for (0..K) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(n-1));
        chi2 += ( @as(f64, @floatFromInt(v0[i])) - exp ) * ( @as(f64, @floatFromInt(v0[i])) - exp ) / exp;
        chi2 += ( @as(f64, @floatFromInt(v1[i])) - exp ) * ( @as(f64, @floatFromInt(v1[i])) - exp ) / exp;
    }

    const p_value = math.igamc(4.0, chi2 / 2.0);
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

pub fn runDistributionDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "RunDistribution",
        .param = param_ptr,
        ._init = run_distribution_init,
        ._iterate = run_distribution_iterate,
        ._destroy = run_distribution_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
