const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const ApproxEntropyParam = struct {
    m: u8,
};

fn approx_entropy_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn approx_entropy_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn approx_entropy_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    var m: u8 = 2;
    if(self.param.extra) |extra| {
        const approxEntropyParam: *ApproxEntropyParam = @ptrCast(extra);
        m = approxEntropyParam.m;
    }

    const n = self.param.n;

    // 读取所有位到数组，便于循环补齐
    const arr = bits.bits();

    var V :[]usize = self.allocator.alloc(usize, @as(usize, 1) << @as(u3, @intCast((m + 1)))) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer self.allocator.free(V);
    for(V)|*v|{
        v.* = 0; // 初始化
    }

    // 统计 m 位模板
    for (0..n) |i| {
        var idx: usize = 0;
        for (0..m) |j| {
            idx = (idx << 1) | arr[(i + j) % n];
        }
        V[idx] += 1;
    }

    var sum: f64 = 0.0;
    for (0..(@as(usize, 1) << @as(u3, @intCast(m)))) |i| {
        var C: f64 = 0;
        if (V[i] != 0) {
            C = @as(f64, @floatFromInt(V[i])) / @as(f64, @floatFromInt(n));

            sum +=  C * @log(C);
        }
    }

    // 统计 m+1 位模板
    for(V) |*v|{
        v.* = 0;
    }

    for (0..n) |i| {
        var idx: usize = 0;
        for (0..(m+1)) |j| {
            idx = (idx << 1) | arr[(i + j) % n];
        }
        V[idx] += 1;
    }


    var sum_1: f64 = 0.0;

    for (0..(@as(usize, 1) << @as(u3, @intCast(m+1)))) |i| {
        var C: f64 = 0;
        if (V[i] != 0) {
            C = @as(f64, @floatFromInt(V[i])) / @as(f64, @floatFromInt(n));

            sum_1 +=  C * @log(C);
        }
    }
    const ap_en = sum - sum_1;
    const chi2 = 2.0 * @as(f64, @floatFromInt(n)) * (@log(2.0) - ap_en);
    const df = @as(f64, @floatFromInt(@as(usize, 1) << @as(u3, @intCast(m-1))));

    const P = math.igamc(df, chi2 / 2.0);
    const passed = P > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = chi2,
        .p_value = P,
        .q_value = P,
        .extra = null,
        .errno = null,
    };
}

pub fn approxEntropyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, m: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.ApproxEntropy;

    const ApenParam: *ApproxEntropyParam = try allocator.create(ApproxEntropyParam);
    ApenParam.*.m = m;
    param_ptr.*.extra = @ptrCast(ApenParam);

    ptr.* = detect.StatDetect{
        .name = "ApproxEntropy",
        .param = param_ptr,
        .allocator = allocator,

        ._init = approx_entropy_init,
        ._iterate = approx_entropy_iterate,
        ._destroy = approx_entropy_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
