const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

pub const CumulativeSumsParam = struct {
    forward: bool, // true for forward cumulative sums, false for backward cumulative sums
};

fn cumulative_sums_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn cumulative_sums_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn cumulative_sums_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    var forward: bool = true;
    if (self.param.extra) |extra| {
        const cumulativeSumsParam: *CumulativeSumsParam = @ptrCast(extra);
        forward = cumulativeSumsParam.forward;
    }

    const n = self.param.n;
    var sum: i64 = 0;
    var z: u64 = 0;

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

    if (forward) {
        for (0..n) |i| {
            const bit = arr[i];
            sum += if (bit == 1) 1 else -1;
            if (@abs(sum) > z) {
                z = @abs(sum);
            }
        }
    } else {
        var i: usize = n;
        while (i > 0) : (i -= 1) {
            const bit = arr[i-1];
            sum += if (bit == 1) 1 else -1;
            if (@abs(sum) > z) {
                z = @abs(sum);
            }
        }
    }

    const zf = @as(f64, @floatFromInt(z));
    const nf = @as(f64, @floatFromInt(n));

    var sum1: f64 = 0.0;
    var sum2: f64 = 0.0;

    const nz: isize = @as(isize, @intCast(@divTrunc(n, z)));

    var k = @divTrunc(-nz + 1, @as(isize, 4));
    var u = @divTrunc(nz - 1, @as(isize, 4));

    while ( k <= u ): (k+=1) {
        sum1 += math.normal(@as(f64, @floatFromInt(4 * k + 1)) * zf / @sqrt(nf));
        sum1 -= math.normal(@as(f64, @floatFromInt(4 * k - 1)) * zf / @sqrt(nf));
    }

    k = @divTrunc(-nz - 3, @as(isize, 4));
    u = @divTrunc(nz - 1, @as(isize, 4));
    while ( k <= u ): (k+=1) {
        sum2 += math.normal(@as(f64, @floatFromInt(4 * k + 3)) * zf / @sqrt(nf));
        sum2 -= math.normal(@as(f64, @floatFromInt(4 * k + 1)) * zf / @sqrt(nf));
    }

    const P = 1.0 - sum1 + sum2;

    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = 0.0,
        .p_value = P,
        .q_value = P,
        .extra = null,
        .errno = null,
    };
}

pub fn cumulativeSumsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, forward: bool) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.CumulativeSums;
    const cumulativeSumsParam = try allocator.create(CumulativeSumsParam);
    cumulativeSumsParam.*.forward = forward;
    param_ptr.*.extra = @ptrCast(cumulativeSumsParam);

    ptr.* = detect.StatDetect{
        .name = "CumulativeSums",
        .param = param_ptr,

        ._init = cumulative_sums_init,
        ._iterate = cumulative_sums_iterate,
        ._destroy = cumulative_sums_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
