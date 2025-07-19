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

fn overlapping_template_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    // 1. 参数支持
    const m = 9;
    const M = 1032;
    const K = 5;
    const n = self.param.n;

    const N = n / M;
    if (N == 0) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 2. pi_term, nist book 800-22r1a 3.8
    const lambda = @as(f64, @floatFromInt(M - m + 1)) / @as(f64, @floatFromInt(1 << m));
    var pi: [6]f64 = undefined;
    if (m == 9 and M == 1032)
        pi = [_]f64 {
	    0.36409105321672786245,     // T0[[M]]/2^1032 // N (was 0.364091)
	    0.18565890010624038178,     // T1[[M]]/2^1032 // N (was 0.185659)
	    0.13938113045903269914,     // T2[[M]]/2^1032 // N (was 0.139381)
	    0.10057114399877811497,     // T3[[M]]/2^1032 // N (was 0.100571)
	    0.070432326346398449744,    // T4[[M]]/2^1032 // N (was 0.0704323)
	    0.13986544587282249192,     // 1 - previous terms (was 0.1398657)
        }
    else
        // 泊松分布近似
        pi = [_]f64 {
            math.poisson(lambda, 0),
            math.poisson(lambda, 1),
            math.poisson(lambda, 2),
            math.poisson(lambda, 3),
            math.poisson(lambda, 4),
            1.0 - math.poisson(lambda, 0)
                - math.poisson(lambda, 1)
                - math.poisson(lambda, 2)
                - math.poisson(lambda, 3)
                - math.poisson(lambda, 4),
        };

    const arr = std.heap.page_allocator.alloc(u1, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(arr);
    if (bits.fetchBits(arr) != n) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 3. 统计 v
    var v = [_]usize{0} ** (K + 1);
    for (0..N) |blk| {
        const offset = blk * M;
        var count: usize = 0;
        for (0..(M-m+1)) |i| {
            var match = true;
            for (0..m) |j| {
                // 目前仅匹配全 1 模板
                if (arr[offset + i + j] != 1) {
                    match = false;
                    break;
                }
            }
            if (match) count += 1;
        }
        if (count < K) v[count] += 1
        else v[K] += 1;
    }

    // 4. chi2 和 p-value
    var chi2: f64 = 0.0;
    for (0..K+1) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        const val = ( @as(f64, @floatFromInt(v[i])) - exp )
                  * ( @as(f64, @floatFromInt(v[i])) - exp )
                  / exp;

        chi2 += val;
    }

    const p_value = math.igamc(@as(f64, @floatFromInt(K)) / 2.0, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = chi2,
        .p_value = p_value,
        .q_value = p_value,
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
    };
    return ptr;
}
