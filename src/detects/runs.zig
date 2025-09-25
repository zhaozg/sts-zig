const std = @import("std");

const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");

fn runs_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn runs_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const n: usize = self.param.n;
    
    // Early return for invalid/empty data
    if (n == 0) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }
    
    var Vobs: usize = 0;
    var ones: usize = 0;
    var prev: u1 = 0;

    // Step 1: 计算 V, 统计 1 的数量
    prev = bits.fetchBit() orelse 0; // 获取第一个比特
    if (prev == 1) ones += 1; // 如果第一个比特是 1，统计

    while (bits.fetchBit()) |bit| {
        if (bit == 1) ones += 1; // 统计 1 的数量
        if (bit != prev) {
          Vobs += 1;
        }
        prev = bit;
    }
    Vobs += 1;

    // Step 2: 计算 1 的比率
    const pi = @as(f64, @floatFromInt(ones)) / @as(f64, @floatFromInt(n));

    // Step 3: 计算统计量值
    const t = 2.0 * pi * (1.0 - pi);

    const V = (@as(f64, @floatFromInt(Vobs)) -  t * @as(f64, @floatFromInt(n)))
            / (t * @sqrt(@as(f64, @floatFromInt(n))));

    const P = math.erfc( @abs(V) / @sqrt(2.0) );
    const Q = 0.5 * math.erfc( V / @sqrt(2.0) );

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

fn runs_destroy(self: *detect.StatDetect) void {
    const Param: *RunsParam = @ptrCast(self.param.extra);
    _ = Param;
    // 清理
}

const RunsParam = struct {
    dummy: u8,
};

pub fn runsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const runs_ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Runs;
    const runs_param: *RunsParam = try allocator.create(RunsParam);
    runs_param.* = RunsParam{ .dummy = 0 };
    param_ptr.extra = runs_param;

    runs_ptr.* = detect.StatDetect{
        .name = "Runs",
        .param = param_ptr,
        .allocator = allocator,

        ._init = runs_init,
        ._iterate = runs_iterate,
        ._destroy = runs_destroy,

        ._reset = detect.detectReset,
    };

    return runs_ptr;
}
