const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

fn poker_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    const Param: *PokerParam = @ptrCast(self.param.extra);
    _ = Param;
    _ = param;
}

fn poker_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    const param: *PokerParam = @ptrCast(self.param.extra);
    const m = @as(u6, @intCast(param.m));

    if (!(m == 2 or m == 4 or m == 8)) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .errno = error.InvalidArgument,
            .extra = null
        };
    }
    const num_patterns = @as(usize, 1) << m;

    var counts = std.heap.page_allocator.alloc(usize, num_patterns) catch |err| {
        //std.debug.print("Poker Test: allocation failed: {}\n", .{err});
        _ = err catch {};
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = error.OutOfMemory,
        };
    };

    defer std.heap.page_allocator.free(counts);
    for (counts) |*c| {
        c.* = 0;
    }

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    var N: usize = 0;
    while (true) {
        var value: u8 = 0;
        var valid = true;
        for (0..m) |i| {
            _ = i;
            if (bits.fetchBit()) |bit| {
                value = (value << 1) | @as(u8, @intCast(bit));
            } else {
                valid = false;
                break;
            }
        }
        if (!valid) break;
        counts[value] += 1;
        N += 1;
    }

    var sum: f64 = 0.0;
    for (counts) |c| {
        sum += @as(f64, @floatFromInt(c)) * @as(f64, @floatFromInt(c));
    }

    const X = (@as(f64, @floatFromInt(num_patterns)) * sum / @as(f64, @floatFromInt(N))) - @as(f64, @floatFromInt(N));
    // 卡方分布自由度为 num_patterns-1
    const p_value = 1.0 - math.chi2_cdf(X, num_patterns - 1);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = X,
        .extra = null,
        .errno = null,
    };
}

fn poker_destroy(self: *detect.StatDetect) void {
    const param: *PokerParam = @ptrCast(self.param.extra);
    _ = param;
}

const PokerParam = struct {
    m: u8, // m = 2, 4, or 8,
};

pub fn pokerDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const poker_ptr = try allocator.create(detect.StatDetect);

    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Poker; // 确保类型正确
    param_ptr.*.extra = null; // 目前没有额外参数
    //
    const poker_param: *PokerParam = try allocator.create(PokerParam);
    poker_param.* = PokerParam{ .m = 2 };
    param_ptr.extra = poker_param;

    poker_ptr.* = detect.StatDetect{
        .name = "Poker",
        .param = param_ptr,
        ._init = poker_init,
        ._iterate = poker_iterate,
        ._destroy = poker_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };

    return poker_ptr;
}
