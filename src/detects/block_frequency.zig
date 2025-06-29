const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn block_frequency_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn block_frequency_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn block_frequency_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    const block_size = 128;
    const N = bits.len / block_size;
    var sum: f64 = 0.0;

    for (0..N) |_| {
        var ones: usize = 0;

        while (bits.fetchBit()) |bit| {
            ones += bit;
        }

        const pi = @as(f64, @floatFromInt(ones)) / @as(f64, @floatFromInt(block_size));
        sum += (pi - 0.5) * (pi - 0.5);
    }

    const chi2 = 4.0 * @as(f64, @floatFromInt(N)) * sum;
    const p_value = 1.0 - math.igamc(@as(f64, @floatFromInt(N)) / 2.0, chi2 / 2.0);
    const passed = p_value > 0.01;
    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = chi2,
        .extra = null,
        .errno = null,
    };
}


pub fn blockFrequencyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "BlockFrequency",
        .param = param_ptr,
        ._init = block_frequency_init,
        ._iterate = block_frequency_iterate,
        ._destroy = block_frequency_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
