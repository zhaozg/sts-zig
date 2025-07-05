const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn maurer_universal_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn maurer_universal_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn maurer_universal_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    // 固定块长度 L=6
    const L = 6;
    const powL = 1 << L;
    const Q = 1000;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    const total_blocks = bits.len / L;
    if (total_blocks <= Q + 1) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }
    const K = total_blocks - Q;

    var T = [_]usize{0} ** powL;

    // 训练阶段
    for (0..Q) |i| {
        var block: usize = 0;
        for (0..L) |_| {
            if (bits.fetchBit()) |bit| {
                block = (block << 1) | bit;
            }
        }
        T[block] = i + 1;
    }

    // 测试阶段
    var sum: f64 = 0.0;
    for (Q..total_blocks) |i| {
        var block: usize = 0;
        for (0..L) |_| {
            if (bits.fetchBit()) |bit| {
                block = (block << 1) | bit;
            }
        }
        const last = T[block];
        const d = i + 1 - last;
        T[block] = i + 1;
        sum += std.math.log2(@as(f64, @floatFromInt(d)));
    }
    const f = sum / @as(f64, @floatFromInt(K));

    // 期望值和方差（L=6时）
    const expected_value = 5.2177052;
    const variance = 2.954; // 近似值

    const z = (f - expected_value) / std.math.sqrt(variance);
    const p_value = math.erfc(@abs(z) / std.math.sqrt(2.0));
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = f,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn maurerUniversalDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "MaurerUniversal",
        .param = param_ptr,
        ._init = maurer_universal_init,
        ._iterate = maurer_universal_iterate,
        ._destroy = maurer_universal_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
