const std = @import("std");

const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");

fn frequency_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;

    _ = param;
}

fn frequency_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };

    var n: isize = 0;

    // Step 1: compute S_n
    while (bits.fetchBit()) |bit| {
        if (bit == 1) {
            n += 1;
        } else {
            n -= 1;
        }
    }

    // Step 2: compute the test statistic
    const S: f64 = @as(f64, @floatFromInt(@abs(n))) / @as(f64, @sqrt(@as(f64, @floatFromInt(bits.len))));

    // Step 3: compute the test P-value
    const p_value = math.erfc(S / std.math.sqrt(2.0));
    const passed = p_value > 0.01;

    const result = detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = S,
        .extra = null,
        .errno = null,
    };
    return result;
}

fn frequency_metrics(self: *detect.StatDetect, result: *const detect.DetectResult) void {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;

    std.debug.print("Frequency Test Metrics: p_value={}\n", .{result.p_value});
}

fn frequency_destroy(self: *detect.StatDetect) void {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;

    // 清理
}

fn frequency_summary(self: *detect.StatDetect, result: *const detect.DetectResult) void {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;
    _ = result;
}

fn frequency_reset(self: *detect.StatDetect) void {
    const Param: *FrequencyParam = @ptrCast(self.param.extra);
    _ = Param;
}

const FrequencyParam = struct {
    dummy: u8,
};

pub fn frequencyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const freq_ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Frequency; // 确保类型正确
    const freq_param: *FrequencyParam = try allocator.create(FrequencyParam);
    freq_param.* = FrequencyParam{ .dummy = 0 };
    param_ptr.extra = freq_param;

    freq_ptr.* = detect.StatDetect{
        .name = "Frequency",
        .param = param_ptr,
        ._init = frequency_init,
        ._iterate = frequency_iterate,
        ._destroy = frequency_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };

    return freq_ptr;
}
