const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn overlapping_template_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn overlapping_template_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn overlapping_template_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const m = 3;
    const M = 1032;
    const n = data.len * 8;
    const N = n / M;
    if (N == 0) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 固定模板 "111"
    const template = [_]u8{1, 1, 1};

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };
    var bit_arr = std.heap.page_allocator.alloc(u8, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(bit_arr);
    for (0..n) |i| {
        bit_arr[i] = if (bits.fetchBit()) |b| b else 0;
    }

    // λ = (M - m + 1) / 2^m
    const lambda = @as(f64, @floatFromInt(M - m + 1)) / 8.0;

    // 统计每块模板出现次数
    const K = 5;
    var v = [_]usize{0} ** K;
    for (0..N) |blk| {
        const offset = blk * M;
        var count: usize = 0;
        var i: usize = 0;
        while (i + m <= M) : (i += 1) {
            var match = true;
            for (0..m) |j| {
                if (bit_arr[offset + i + j] != template[j]) {
                    match = false;
                    break;
                }
            }
            if (match) count += 1;
        }
        if (count <= 1) v[0] += 1
        else if (count == 2) v[1] += 1
        else if (count == 3) v[2] += 1
        else if (count == 4) v[3] += 1
        else v[4] += 1;
    }

    const pi = [_]f64{
        math.poisson(lambda, 0) + math.poisson(lambda, 1),
        math.poisson(lambda, 2),
        math.poisson(lambda, 3),
        math.poisson(lambda, 4),
        1.0 - (math.poisson(lambda, 0)
            + math.poisson(lambda, 1)
            + math.poisson(lambda, 2)
            + math.poisson(lambda, 3)
            + math.poisson(lambda, 4)),
    };

    var chi2: f64 = 0.0;
    for (0..K) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        chi2 += ( @as(f64, @floatFromInt(v[i])) - exp ) * ( @as(f64, @floatFromInt(v[i])) - exp ) / exp;
    }

    const p_value = math.igamc(2.0, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = chi2,
        .extra = null,
        .errno = null,
    };
}

pub fn overlappingTemplateDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "OverlappingTemplate",
        .param = param_ptr,
        ._init = overlapping_template_init,
        ._iterate = overlapping_template_iterate,
        ._destroy = overlapping_template_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
