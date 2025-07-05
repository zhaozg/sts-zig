const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn binary_derivative_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn binary_derivative_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn binary_derivative_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const n = data.len * 8;
    if (n < 2) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };
    var bit_arr = std.heap.page_allocator.alloc(u8, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(bit_arr);
    for (0..n) |i| {
        bit_arr[i] = if (bits.fetchBit()) |b| b else 0;
    }

    // 计算一次二进制差分序列
    var S: usize = 0;
    for (0..n) |i| {
        if ((bit_arr[i] ^ bit_arr[(i + 1) % n]) == 1) S += 1;
    }

    const nf = @as(f64, @floatFromInt(n));
    const P = 2.0 * (@as(f64, @floatFromInt(S)) - nf / 2.0) / std.math.sqrt(nf);
    const p_value = math.erfc(@abs(P) / std.math.sqrt(2.0));
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = P,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn binaryDerivativeDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "BinaryDerivative",
        .param = param_ptr,
        ._init = binary_derivative_init,
        ._iterate = binary_derivative_iterate,
        ._destroy = binary_derivative_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
