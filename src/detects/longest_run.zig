const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn longest_run_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn longest_run_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn longest_run_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    // 固定块大小 M=8
    const M = 8;
    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    const N = bits.len / M;
    if (N == 0) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 区间：<=1, 2, 3, >=4
    var v = [_]usize{0} ** 4;

    for (0..N) |_| {
        var run: usize = 0;
        var max_run: usize = 0;
        for (0..M) |_| {
            if (bits.fetchBit()) |bit| {
                if (bit == 1) {
                    run += 1;
                    if (run > max_run) max_run = run;
                } else {
                    run = 0;
                }
            }
        }
        if (max_run <= 1) v[0] += 1
        else if (max_run == 2) v[1] += 1
        else if (max_run == 3) v[2] += 1
        else v[3] += 1;
    }

    // 理论概率（NIST SP800-22, M=8）
    const pi = [_]f64{ 0.2148, 0.3672, 0.2305, 0.1875 };

    var chi2: f64 = 0.0;
    for (0..4) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        chi2 += ( @as(f64, @floatFromInt(v[i])) - exp ) * ( @as(f64, @floatFromInt(v[i])) - exp ) / exp;
    }

    const p_value = math.igamc(1.5, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = chi2,
        .extra = null,
        .errno = null,
    };
}

pub fn longestRunDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "LongestRun",
        .param = param_ptr,
        ._init = longest_run_init,
        ._iterate = longest_run_iterate,
        ._destroy = longest_run_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
