const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

pub const LongestRunParam= struct {
    mode: u8
};

fn longest_run_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn longest_run_destroy(self: *detect.StatDetect) void {
    _ = self;
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
            0 => 0, // <=1
            1 => 0, // ==2
            2 => 1, // ==3
            3 => 2,
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
        if ( r <= 10)
          return 0;
        if (r >= 16)
          return 6;
        return @as(u3, @intCast(r-10));
    }
    return 0;
}

fn selectPi(m: u16, i: u3) f16 {
    if (m == 8) {
        const list = [_]f16{ 0.2148, 0.3672, 0.2305, 0.1875 };
        return list[i];
    } else if (m == 128) {
        const list = [_]f16{ 0.1174, 0.2430, 0.2494, 0.1752, 0.0127, 0.1124 };
        return list[i];
    } else if (m == 10000) {
        const list = [_]f16{ 0.086632, 0.208201, 0.248419, 0.193913,
                                     0.121458, 0.068011, 0.073366 };
        return list[i];
    }
    return 0.0; // 默认值
}

fn longest_run_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    var mode: u1 = 1;
    if (self.param.extra != null) {
        const longestParam: *LongestRunParam = @alignCast(@ptrCast(self.param.extra));
        mode = @as(u1, @intCast(longestParam.mode));
    }

    var bits = io.BitStream.init(data);

    const M: u16 = selectM(bits.len);

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
    const N = bits.len / M;

    // Step 2:  K + 1 个集合
    const K: u3 = if (M == 8) 3 else if (M == 128) 5 else 6;

    // K + 1 个集合
    var v = [_]usize{0} ** 7;

    for (0..N) |_| {
        // Step 2: 块内计数
        var run: u16 = 0;
        var max_run: u16 = 0;
        var i: u16 = 0;

        while (bits.fetchBit()) |bit| {
            if (bit == mode) {
                run += 1;
            } else {
                if (run > max_run) max_run = run;

                run = 0;
            }

            i += 1;
            if (i >= M) {
                if (run > max_run) max_run = run;
                break; // 达到块大小，停止计数
            }
        }

        v[selectSet(M, max_run)] += 1;
    }

    // Step 3: 计算统计量
    var V: f64 = 0.0;
    for (0..K + 1) |n| {
        const pi = selectPi(M, @as(u3, @intCast(n)));
        const f = @as(f64, @floatFromInt(v[n])) - @as(f64, @floatFromInt(N)) * pi;
        const x = ( f * f ) / (@as(f64, @floatFromInt(N)) * pi);

        V += x;
    }
    const P = math.igamc(@as(f64, @floatFromInt(K)) / 2.0, V / 2.0);
    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = P,
        .q_value = P,
        .extra = null,
        .errno = null,
    };
}

pub fn longestRunDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, mode: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.LongestRun;

    const longestParam = try allocator.create(LongestRunParam);
    longestParam.* = LongestRunParam{
        .mode = mode, // 默认模式为 1
    };

    param_ptr.*.extra = longestParam;

    ptr.* = detect.StatDetect{
        .name = "LongestRun",
        .param = param_ptr,
        ._init = longest_run_init,
        ._iterate = longest_run_iterate,
        ._destroy = longest_run_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
