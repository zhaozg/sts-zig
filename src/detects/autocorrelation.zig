const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const AutoCorrelationParam = struct {
    d: u8, // m = 3, 5, or 7,
};

fn autocorrelation_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn autocorrelation_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn autocorrelation_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {

    var d: u8 = 1;
    if (self.param.extra) |extra| {
        const autocorrParam: *AutoCorrelationParam = @ptrCast(extra);
        d = autocorrParam.d;
    }

    var bits = io.BitStream.init(data);
    var bit_arr = std.heap.page_allocator.alloc(u1, bits.len) catch |err| {
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
    for (0..bits.len) |i| {
        bit_arr[i] = 0;
    }

    var I: usize = 0;
    const n = bits.len;

    // 逻辑左移 d  位
    while(bits.fetchBit()) |b| {
        // 将比特流转换为 u1 数组
        bit_arr[I] = b;
        I += 1;
    }

    var V: usize = 0;
    for (0..n - d) |i| {
        // 逻辑左移 d 位
        V += bit_arr[i]^bit_arr[i + d];
    }

    const nf = @as(f64, @floatFromInt(n - d));
    const S = (2.0 * @as(f64, @floatFromInt(V)) - nf) / @sqrt(nf);
    const P = math.erfc(@abs(S) / @sqrt(2.0));
    const Q: f64 = 0.5 * math.erfc(S / @sqrt(2.0));
    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = S,
        .p_value = P,
        .q_value = Q,
        .extra = null,
        .errno = null,
    };
}

pub fn autocorrelationDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, d: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;

    const autocorrParam: *AutoCorrelationParam = try allocator.create(AutoCorrelationParam);
    autocorrParam.*.d = d;
    param_ptr.*.extra = @ptrCast(autocorrParam);

    ptr.* = detect.StatDetect{
        .name = "Autocorrelation",
        .param = param_ptr,

        ._init = autocorrelation_init,
        ._iterate = autocorrelation_iterate,
        ._destroy = autocorrelation_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
