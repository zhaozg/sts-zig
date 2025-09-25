const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const MAX_L_UNIVERSAL = 16;

const expected_value: [MAX_L_UNIVERSAL + 1]f64 = [_]f64{ 0, 0, 0, 0, 0, 0, 5.2177052, 6.1962507, 7.1836656, 8.1764248, 9.1723243, 10.170032, 11.168765, 12.168070, 13.167693, 14.167488, 15.167379 };

const variance: [MAX_L_UNIVERSAL + 1]f64 = [_]f64{ 0, 0, 0, 0, 0, 0, 2.954, 3.125, 3.238, 3.311, 3.356, 3.384, 3.401, 3.410, 3.416, 3.419, 3.421 };

pub const MaurerUniversalParam = struct {
    L: u8,
    Q: usize,
};

fn maurer_universal_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn maurer_universal_destroy(self: *detect.StatDetect) void {
    // Free the allocated MaurerUniversalParam
    if (self.param.extra) |extra| {
        self.allocator.destroy(@as(*MaurerUniversalParam, @ptrCast(@alignCast(extra))));
    }
    // Free the allocated DetectParam
    self.allocator.destroy(self.param);
    // Free the StatDetect itself
    self.allocator.destroy(self);
}

fn maurer_universal_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    var L: u8 = 6;
    var Q: usize = 10 * (1 << 6);
    const n = self.param.n;

    if (self.param.extra) |extra| {
        const maruer: *MaurerUniversalParam = @ptrCast(@alignCast(extra));
        L = maruer.L;
        Q = maruer.Q;
    }

    const total_blocks = n / L;

    if (total_blocks <= Q + 1) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }
    const K = total_blocks - Q;

    var allocator = self.allocator;
    var T: []usize = allocator.alloc(usize, @as(usize, 1) << @as(u3, @intCast(L))) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    for (T) |*v| {
        v.* = 0;
    }
    defer allocator.free(T);

    // Step 2: 训练阶段
    for (0..Q) |i| {
        var block: usize = 0;
        for (0..L) |_| {
            if (bits.fetchBit()) |bit| {
                block = (block << 1) | bit;
            }
        }
        T[block] = i + 1;
    }

    // Step 3: 测试阶段
    var sum: f64 = 0.0;
    for (Q..total_blocks) |i| {
        var block: usize = 0;
        for (0..L) |_| {
            if (bits.fetchBit()) |bit| {
                block = (block << 1) | bit;
            }
        }
        const last = T[block];
        const d = i + 1 - last;
        T[block] = i + 1;
        sum += std.math.log2(@as(f64, @floatFromInt(d)));
    }
    const f = sum / @as(f64, @floatFromInt(K));

    // c = 0.7 - 0.8 / (double) L + (4 + 32 / (double) L) * pow(stat.K, -3.0 / (double) L) / 15;
    // stat.sigma = c * sqrt(variance[L] / (double) stat.K);
    // arg = fabs(stat.f_n - expected_value[L]) / (state->c.sqrt2 * stat.sigma);
    // p_value = erfc(arg);
    // 期望值和方差（L）
    //
    const c = 0.7 - 0.8 / @as(f64, @floatFromInt(L)) + (4 + 32 / @as(f64, @floatFromInt(L))) * std.math.pow(f64, @as(f64, @floatFromInt(K)), -3.0 / @as(f64, @floatFromInt(L))) / 15;

    var V: f64 = 0.0;
    var Pv: f64 = 0.0;
    var Qv: f64 = 0.0;

    if (variance[L] > 0.0) {
        const sigma = c * @sqrt(variance[L] / @as(f64, @floatFromInt(K)));
        V = @abs(f - expected_value[L]) / sigma;

        Pv = math.erfc(@abs(V) / @sqrt(2.0));
        Qv = 0.5 * math.erfc(V / @sqrt(2.0));
    }

    const passed = Pv > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = Pv,
        .q_value = Qv,
        .extra = null,
        .errno = null,
    };
}

pub fn maurerUniversalDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, L: u8, Q: usize) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    const maruer: *MaurerUniversalParam = try allocator.create(MaurerUniversalParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.MaurerUniversal;
    maruer.*.L = L;
    maruer.*.Q = Q;
    param_ptr.*.extra = maruer;

    ptr.* = detect.StatDetect{
        .name = "MaurerUniversal",
        .param = param_ptr,
        .allocator = allocator,

        ._init = maurer_universal_init,
        ._iterate = maurer_universal_iterate,
        ._destroy = maurer_universal_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
