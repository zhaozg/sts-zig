const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const BinaryDerivativeParam = struct {
    k: u8, // m = 3, 5, or 7,
};

fn binary_derivative_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn binary_derivative_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn binary_derivative_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    var k: u8 = 1;
    if (self.param.extra) |extra| {
        const binaryDerivativeParam: *BinaryDerivativeParam = @ptrCast(extra);
        k = binaryDerivativeParam.k;
    }

    const n = self.param.n;

    var arr = std.heap.page_allocator.alloc(u1, n) catch |err| {
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

    for (0..k) |i| {
        for (0..n-i-1) |j| {
            arr[j] = arr[j] ^ arr[j+1];
        }
    }

    var S: isize = 0;
    for (0..n-k) |i| {
        S += if (arr[i]==1) 1 else -1;
    }

    const V = @as(f64, @floatFromInt(S)) / @sqrt(@as(f64, @floatFromInt(n - k)));

    const P = math.erfc(@abs(V) / @sqrt(2.0));
    const Q = 0.5 * math.erfc(V / @sqrt(2.0));
    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = P,
        .q_value = Q,
        .extra = null,
        .errno = null,
    };
}

pub fn binaryDerivativeDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, k: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.BinaryDerivative;

    const binaryDerivativeParam: *BinaryDerivativeParam = try allocator.create(BinaryDerivativeParam);
    binaryDerivativeParam.* = BinaryDerivativeParam{
        .k = k, // 默认值
    };
    param_ptr.*.extra = @ptrCast(binaryDerivativeParam);

    ptr.* = detect.StatDetect{
        .name = "BinaryDerivative",
        .param = param_ptr,

        ._init = binary_derivative_init,
        ._iterate = binary_derivative_iterate,
        ._destroy = binary_derivative_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
