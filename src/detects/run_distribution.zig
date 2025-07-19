const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn run_distribution_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn run_distribution_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn calcK(n: usize) usize {

    for (1..n+1) |k| {
        const e: f64 = @as(f64, @floatFromInt(n - k + 3))
                     / @as(f64, @floatFromInt(std.math.pow(u64,2, k+2)));
        if (e < 5.0)
            return k - 1;
    }
    return 64;
}

fn run_distribution_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const n = self.param.n;

    // Step 1: 计算 k 游程长度
    const k = calcK(n);

    // Step 2: 分别统计0-run和1-run
    var v0: [64]usize = [_]usize{0} ** 64;
    var v1: [64]usize = [_]usize{0} ** 64;
    var e: [64]f64= [_]f64{0.0} ** 64;

    var l0: usize = 1;
    var l1: usize = 1;
    var prev: u1 = bits.fetchBit() orelse 0; // 获取第一个比特

    while (bits.fetchBit()) |bit| {
        if (bit == prev) {
            if (prev == 0) l0 += 1 else l1 += 1;
        } else {
            if (prev == 0) {
                if (l0 >= k) l0 = k;
                v0[l0] += 1;
            } else {
                if (l1 >= k) l1 = k;
                v1[l1] += 1;
            }
            l0 = 1;
            l1 = 1;
            prev = bit;
        }
    }

    if (prev == 0) {
        if (l0 >= k) l0 = k;
        v0[l0] += 1;
    } else {
        if (l1 >= k) l1 = k;
        v1[l1] += 1;
    }

    // Step 3: 计算 T
    var T: usize = 0;
    for (1..k+1) |i| {
        T += v0[i] + v1[i];
    }

    // Step 4: 计算 e
    for (1..k+1) |i| {
        if (i == k) {
            e[i] = @as(f64, @floatFromInt(T))
                 / @as(f64, @floatFromInt(std.math.pow(u64, 2, k)));
        } else {
            e[i] = @as(f64, @floatFromInt(T))
                 / @as(f64, @floatFromInt(std.math.pow(u64, 2, i + 1)));
        }
    }

    // Step 5: 计算 V
    var V: f64 = 0.0;
    for (1..k+1) |i| {
        const f0: f64 = @as(f64, @floatFromInt(v0[i]));
        const f1: f64 = @as(f64, @floatFromInt(v1[i]));
        const fe = e[i];

        V += ( f0 - fe ) * ( f0 - fe ) / fe + (f1 - fe) * (f1 - fe) / fe;
    }

    // Step 6: 计算 P 值
    const P = math.igamc(@as(f64, @floatFromInt(k-1)), V / 2.0);
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

pub fn runDistributionDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "RunDistribution",
        .param = param_ptr,
        .allocator = allocator,

        ._init = run_distribution_init,
        ._iterate = run_distribution_iterate,
        ._destroy = run_distribution_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
