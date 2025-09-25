const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

pub const CumulativeSumsParam = struct {
    forward: bool, // true for forward cumulative sums, false for backward cumulative sums
};

const NUMBER_OF_STATES_CUMULATIVESUMS = 2;

pub const CumulativeSumsResult = struct {
    v_value: [NUMBER_OF_STATES_CUMULATIVESUMS]f64 = .{0} ** NUMBER_OF_STATES_CUMULATIVESUMS, // 每个状态的卡方统计量
    p_value: [NUMBER_OF_STATES_CUMULATIVESUMS]f64 = .{0} ** NUMBER_OF_STATES_CUMULATIVESUMS, // 每个状态的p值
    q_value: [NUMBER_OF_STATES_CUMULATIVESUMS]f64 = .{0} ** NUMBER_OF_STATES_CUMULATIVESUMS, // 每个状态的q值
    passed: [NUMBER_OF_STATES_CUMULATIVESUMS]bool = .{true} ** NUMBER_OF_STATES_CUMULATIVESUMS, // 每个状态是否通过
};

fn cumulative_sums_print(self: *detect.StatDetect, result: *const detect.DetectResult, level: detect.PrintLevel) void {
    detect.detectPrint(self, result, level);
    if (result.extra == null) {
        return;
    }

    const results = @as(*CumulativeSumsResult, @ptrCast(@alignCast(result.extra.?)));
    var passed: usize = 0;
    for (0..results.passed.len) |i| {
        if (results.passed[i]) {
            passed += 1;
        }
    }
    std.debug.print("\tStatus passed: {d}/{d}  failed: {d}/{d}\n", .{ passed, results.passed.len, results.passed.len - passed, results.passed.len });

    if (level == .detail) {
        std.debug.print("\n", .{});
        for (0..results.passed.len) |i| {
            std.debug.print("\tState({s}): passed={s}, V = {d:10.6} P = {d:.6}\n", .{
                if (i == 0) "|==>" else "<==|",
                if (results.passed[i]) "Yes" else "No ",
                results.v_value[i],
                results.p_value[i],
            });
        }
        std.debug.print("\n", .{});
    }
}

fn cumulative_sums_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn cumulative_sums_destroy(self: *detect.StatDetect) void {
    self.allocator.destroy(self.param);
    self.allocator.destroy(self);
}

fn cumulative_sums_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const mode: [2]bool = [_]bool{ true, false };

    const n = self.param.n;

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

    var result: *CumulativeSumsResult = self.allocator.create(CumulativeSumsResult) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    var P_min: f64 = 1.0;

    for (mode, 0..NUMBER_OF_STATES_CUMULATIVESUMS) |forward, i| {
        var sum: i64 = 0;
        var z: u64 = 0;

        if (forward) {
            for (0..n) |j| {
                const bit = arr[j];
                sum += if (bit == 1) 1 else -1;
                if (@abs(sum) > z) {
                    z = @abs(sum);
                }
            }
        } else {
            var j: usize = n;
            while (j > 0) : (j -= 1) {
                const bit = arr[j - 1];
                sum += if (bit == 1) 1 else -1;
                if (@abs(sum) > z) {
                    z = @abs(sum);
                }
            }
        }

        const zf = @as(f64, @floatFromInt(z));
        const nf = @as(f64, @floatFromInt(n));

        var sum1: f64 = 0.0;
        var sum2: f64 = 0.0;

        const nz: isize = @as(isize, @intCast(@divTrunc(n, z)));

        var k = @divTrunc(-nz + 1, @as(isize, 4));
        var u = @divTrunc(nz - 1, @as(isize, 4));

        while (k <= u) : (k += 1) {
            sum1 += math.normal(@as(f64, @floatFromInt(4 * k + 1)) * zf / @sqrt(nf));
            sum1 -= math.normal(@as(f64, @floatFromInt(4 * k - 1)) * zf / @sqrt(nf));
        }

        k = @divTrunc(-nz - 3, @as(isize, 4));
        u = @divTrunc(nz - 1, @as(isize, 4));
        while (k <= u) : (k += 1) {
            sum2 += math.normal(@as(f64, @floatFromInt(4 * k + 3)) * zf / @sqrt(nf));
            sum2 -= math.normal(@as(f64, @floatFromInt(4 * k + 1)) * zf / @sqrt(nf));
        }

        const P = 1.0 - sum1 + sum2;
        if (P < P_min) {
            P_min = P;
        }

        result.passed[i] = P > 0.01;
        result.p_value[i] = P;
        result.q_value[i] = P;
        result.v_value[i] = 0.0;
    }

    return detect.DetectResult{
        .passed = P_min > 0.01,
        .v_value = 0.0,
        .p_value = P_min,
        .q_value = P_min,
        .extra = result,
        .errno = null,
    };
}

pub fn cumulativeSumsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.CumulativeSums;

    ptr.* = detect.StatDetect{
        .name = "CumulativeSums",
        .param = param_ptr,
        .allocator = allocator,

        ._init = cumulative_sums_init,
        ._iterate = cumulative_sums_iterate,
        ._destroy = cumulative_sums_destroy,

        ._reset = detect.detectReset,
        ._print = cumulative_sums_print,
    };
    return ptr;
}
