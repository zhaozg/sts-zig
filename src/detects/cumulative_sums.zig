const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn cumulative_sums_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn cumulative_sums_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn cumulative_sums_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    const n = bits.len;
    var sum: i64 = 0;
    var max_abs_sum: u64 = 0;

    while (bits.fetchBit()) |bit| {
        sum += if (bit == 1) 1 else -1;
        if (@abs(sum) > max_abs_sum) {
            max_abs_sum = @abs(sum);
        }
    }

    const z = @as(f64, @floatFromInt(max_abs_sum));
    const nf = @as(f64, @floatFromInt(n));
    const p_value = 1.0 - math.erfc(z / (std.math.sqrt(nf) * std.math.sqrt(2.0)));
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = z,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn cumulativeSumsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "CumulativeSums",
        .param = param_ptr,
        ._init = cumulative_sums_init,
        ._iterate = cumulative_sums_iterate,
        ._destroy = cumulative_sums_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
