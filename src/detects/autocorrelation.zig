const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn autocorrelation_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn autocorrelation_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn autocorrelation_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const d = 1;
    const n = data.len * 8;
    if (n <= d) {
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

    var V: usize = 0;
    for (0..(n - d)) |i| {
        if (bit_arr[i] == bit_arr[i + d]) V += 1;
    }

    const nf = @as(f64, @floatFromInt(n - d));
    const S = 2.0 * (@as(f64, @floatFromInt(V)) - nf / 2.0) / std.math.sqrt(nf);
    const p_value = math.erfc(@abs(S) / std.math.sqrt(2.0));
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = S,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn autocorrelationDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "Autocorrelation",
        .param = param_ptr,
        ._init = autocorrelation_init,
        ._iterate = autocorrelation_iterate,
        ._destroy = autocorrelation_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
