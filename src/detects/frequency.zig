const std = @import("std");

const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");

fn frequency_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn frequency_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    // Early return for invalid/empty data
    if (self.param.n == 0) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var n: isize = 0;

    // Step 2: compute S_n
    while (bits.fetchBit()) |bit| {
        if (bit == 1) {
            n += 1;
        } else {
            n -= 1;
        }
    }

    // Step 3: compute the test statistic
    const V: f64 = @as(f64, @floatFromInt(n)) / @as(f64, @sqrt(@as(f64, @floatFromInt(self.param.n))));

    // Step 4: compute the test P-value
    const P = math.erfc(@abs(V) / @sqrt(2.0));

    // Step 5: compute the Q-value
    const Q = math.erfc(V / @sqrt(2.0)) / 2;

    const passed = P > 0.01;

    const result = detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = P,
        .q_value = Q,

        .extra = null,
        .errno = null,
    };
    return result;
}

fn frequency_metrics(self: *detect.StatDetect, result: *const detect.DetectResult) void {
    _ = self;
    _ = result;
}

fn frequency_destroy(self: *detect.StatDetect) void {
    self.allocator.destroy(self.param);
    self.allocator.destroy(self);
}

fn frequency_summary(self: *detect.StatDetect, result: *const detect.DetectResult) void {
    _ = self;
    _ = result;
}

fn frequency_reset(self: *detect.StatDetect) void {
    _ = self;
}

pub fn frequencyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const freq_ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Frequency; // 确保类型正确

    freq_ptr.* = detect.StatDetect{
        .name = "Frequency",
        .param = param_ptr,
        .allocator = allocator,

        ._init = frequency_init,
        ._iterate = frequency_iterate,
        ._destroy = frequency_destroy,

        ._reset = detect.detectReset,
    };

    return freq_ptr;
}
