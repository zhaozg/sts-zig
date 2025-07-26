const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn serial_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn serial_destroy(self: *detect.StatDetect) void {
    _ = self;
}


fn psi2(self: *detect.StatDetect, bit_arr: []u1, n: usize, m: u5) !f64 {
    if (m == 0) return 0.0;

    const patterns: u32 = @as(u32, 1) << m;
    var counts = try self.allocator.alloc(usize, patterns);
    defer self.allocator.free(counts);
    for(0..patterns) |i| {
        counts[i] = 0;
    }
    for (0..n) |i| {
        var idx: usize = 0;
        for (0..m) |j| {
            idx = (idx << 1) | bit_arr[(i + j) % n];
        }
        counts[idx] += 1;
    }
    var sum: f64 = 0.0;
    for (0..patterns) |i| {
        sum += @as(f64, @floatFromInt(counts[i])) * @as(f64, @floatFromInt(counts[i]));
    }
    return (sum * @as(f64, @floatFromInt(patterns)) / @as(f64, @floatFromInt(n))) - @as(f64, @floatFromInt(n));
}

fn serial_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {

    const m = 2;
    const n = self.param.n;

    if (n < 10) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    const arr = bits.bits();
    if (arr.len != n) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }
    const psi2_m   = psi2(self, arr, n, m) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    const psi2_m1  = psi2(self, arr, n, m - 1) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    const psi2_m2  = psi2(self, arr, n, m - 2) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    const delta1 = psi2_m - psi2_m1;
    const delta2 = psi2_m - 2.0 * psi2_m1 + psi2_m2;

    const p_value1 = math.igamc(1.0, delta1 / 2.0);
    const p_value2 = math.igamc(0.5, delta2 / 2.0);
    const passed = p_value1 > 0.01 and p_value2 > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = delta1,
        .p_value = p_value1,
        .q_value = p_value2,
        .extra = null,
        .errno = null,
    };
}

pub fn serialDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Serial;
    ptr.* = detect.StatDetect{
        .name = "Serial",
        .param = param_ptr,
        .allocator = allocator,

        ._init = serial_init,
        ._iterate = serial_iterate,
        ._destroy = serial_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
