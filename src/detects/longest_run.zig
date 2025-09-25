const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const NUMBER_OF_STATES_LONGEST_RUN = 2;

pub const LongestRunResult = struct {
    v_value: [NUMBER_OF_STATES_LONGEST_RUN]f64 = .{0} ** NUMBER_OF_STATES_LONGEST_RUN, // 每个状态的卡方统计量
    p_value: [NUMBER_OF_STATES_LONGEST_RUN]f64 = .{0} ** NUMBER_OF_STATES_LONGEST_RUN, // 每个状态的p值
    q_value: [NUMBER_OF_STATES_LONGEST_RUN]f64 = .{0} ** NUMBER_OF_STATES_LONGEST_RUN, // 每个状态的q值
    passed: [NUMBER_OF_STATES_LONGEST_RUN]bool = .{true} ** NUMBER_OF_STATES_LONGEST_RUN, // 每个状态是否通过
};

fn longest_run_print(self: *detect.StatDetect, result: *const detect.DetectResult, level: detect.PrintLevel) void {
    detect.detectPrint(self, result, level);
    if (result.extra == null) {
        return;
    }

    const results = @as(*LongestRunResult, @ptrCast(@alignCast(result.extra.?)));
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
            std.debug.print("\tState({d}): passed={s}, V = {d:10.6} P = {d:.6}\n", .{
                i,
                if (results.passed[i]) "Yes" else "No ",
                results.v_value[i],
                results.p_value[i],
            });
        }
        std.debug.print("\n", .{});
    }
}
fn longest_run_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn longest_run_destroy(self: *detect.StatDetect) void {
    self.allocator.destroy(self.param);
    self.allocator.destroy(self);
}

fn selectM(n: usize) u16 {
    return if (n >= 75000)
        10000
    else if (n >= 6272)
        128
    else if (n >= 128)
        8
    else
        0;
    //FIXME: return zsts.errors.Error.InvalidBlockSize;
}

fn selectSet(m: u16, r: u16) u3 {
    if (m == 8) {
        return switch (r) {
            0 => 0,
            1 => 0, // <=1
            2 => 1, // ==2
            3 => 2, // ==3
            else => 3, // >=4
        };
    } else if (m == 128) {
        return switch (r) {
            0 => 0,
            1 => 0,
            2 => 0,
            3 => 0,
            4 => 0, // <=4
            5 => 1,
            6 => 2,
            7 => 3,
            8 => 4,
            else => 5, // >= 9
        };
    } else if (m == 10000) {
        if (r <= 10)
            return 0;
        if (r >= 16)
            return 6;
        return @as(u3, @intCast(r - 10));
    }
    return 0;
}

fn selectPi(m: u16, i: u3) f64 {
    if (m == 8) {
        const list = [_]f64{ 0.2148, 0.3672, 0.2305, 0.1875 };
        return list[i];
    } else if (m == 128) {
        const list = [_]f64{ 0.1174, 0.2430, 0.2494, 0.1752, 0.0127, 0.1124 };
        return list[i];
    } else if (m == 10000) {
        const list = [_]f64{ 0.086632, 0.208201, 0.248419, 0.193913, 0.121458, 0.068011, 0.073366 };
        return list[i];
    }
    return 0.0; // 默认值
}

fn longest_run_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const n = self.param.n;

    const M: u16 = selectM(n);

    if (M != 8 and M != 128 and M != 10000) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // Step 1: N 个比特序列
    const N: usize = @divTrunc(n, M);

    // Step 2:  K + 1 个集合
    const K: u3 = if (M == 8) 3 else if (M == 128) 5 else 6;

    // K + 1 个集合
    var v0 = [_]usize{0} ** 7;
    var v1 = [_]usize{0} ** 7;

    for (0..N) |_| {
        // Step 2: 块内计数
        var run0: u16 = 0;
        var max_run0: u16 = 0;
        var run1: u16 = 0;
        var max_run1: u16 = 0;

        for (0..M) |_| {
            const bit = bits.fetchBit() orelse 0;
            if (bit == 0) {
                if (run1 > max_run1) max_run1 = run1;
                run1 = 0;

                run0 += 1;
                if (run0 > max_run0) max_run0 = run0;
            } else {
                if (run0 > max_run0) max_run0 = run0;
                run0 = 0;

                run1 += 1;
                if (run1 > max_run1) max_run1 = run1;
            }
        }

        v0[selectSet(M, max_run0)] += 1;
        v1[selectSet(M, max_run1)] += 1;
    }

    // Step 3: 计算统计量
    var V0: f64 = 0.0;
    var V1: f64 = 0.0;

    for (0..K + 1) |i| {
        const pi: f64 = selectPi(M, @as(u3, @intCast(i)));

        const f0 = @as(f64, @floatFromInt(v0[i])) - @as(f64, @floatFromInt(N)) * pi;
        const x0 = (f0 * f0) / (@as(f64, @floatFromInt(N)) * pi);
        V0 += x0;

        const f1 = @as(f64, @floatFromInt(v1[i])) - @as(f64, @floatFromInt(N)) * pi;
        const x1 = (f1 * f1) / (@as(f64, @floatFromInt(N)) * pi);
        V1 += x1;
    }

    const P0 = math.igamc(@as(f64, @floatFromInt(K)) / 2.0, V0 / 2.0);
    const P1 = math.igamc(@as(f64, @floatFromInt(K)) / 2.0, V1 / 2.0);

    const P = if (P0 < P1) P0 else P1;
    const V = if (P0 < P1) V0 else V1;

    const result: *LongestRunResult = self.allocator.create(LongestRunResult) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    result.* = LongestRunResult{
        .v_value = .{ V0, V1 },
        .p_value = .{ P0, P1 },
        .q_value = .{ P0, P1 },
        .passed = .{ P0 > 0.01, P1 > 0.01 },
    };

    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = P,
        .q_value = P,
        .extra = result,
        .errno = null,
    };
}

pub fn longestRunDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.LongestRun;

    ptr.* = detect.StatDetect{
        .name = "LongestRun",
        .param = param_ptr,
        .allocator = allocator,

        ._init = longest_run_init,
        ._iterate = longest_run_iterate,
        ._destroy = longest_run_destroy,

        ._reset = detect.detectReset,
        ._print = longest_run_print,
    };
    return ptr;
}
