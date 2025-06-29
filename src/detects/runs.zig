const std = @import("std");

const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");

fn runs_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    const Param: *RunsParam = @ptrCast(self.param.extra);
    _ = Param;
    _ = param;
}

fn runs_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    const Param: *RunsParam = @ptrCast(self.param.extra);
    _ = Param;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };

    const n: usize = data.len * 8;
    var ones: usize = 0;
    var prev: ?u1 = null;
    var runs: usize = 0;

    while (bits.fetchBit()) |bit| {
        if (bit == 1) ones += 1;
        if (prev == null or bit != prev.?) {
            runs += 1;
        }
        prev = bit;
    }

    const pi = @as(f64, @floatFromInt(ones)) / @as(f64, @floatFromInt(n));
    // 检查 pi 是否在允许范围
    const tau = 2.0 / @sqrt(@as(f64, @floatFromInt(n)));
    var passed = false;
    var p_value: f64 = 0.0;
    var stat: f64 = 0.0;

    if (@abs(pi - 0.5) < tau) {
        // 计算统计量和P值
        const expected_runs = 2.0 * @as(f64, @floatFromInt(n)) * pi * (1.0 - pi);
        stat = @abs(@as(f64, @floatFromInt(runs)) - expected_runs)
          / (2.0 * std.math.sqrt(2.0 * @as(f64, @floatFromInt(n))) * pi * (1.0 - pi));
        p_value = math.erfc(stat);
        passed = p_value > 0.01;
    }

    const result = detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = stat,
        .extra = null,
        .errno = null,
    };
    return result;
}

fn runs_destroy(self: *detect.StatDetect) void {
    const Param: *RunsParam = @ptrCast(self.param.extra);
    _ = Param;
    // 清理
}

const RunsParam = struct {
    dummy: u8,
};

pub fn runsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const runs_ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Runs;
    const runs_param: *RunsParam = try allocator.create(RunsParam);
    runs_param.* = RunsParam{ .dummy = 0 };
    param_ptr.extra = runs_param;

    runs_ptr.* = detect.StatDetect{
        .name = "Runs",
        .param = param_ptr,
        ._init = runs_init,
        ._iterate = runs_iterate,
        ._destroy = runs_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };

    return runs_ptr;
}
