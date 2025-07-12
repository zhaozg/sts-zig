const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const DEFAULT_BLOCK_SIZE = 128; // 默认块大小

pub const BlockFrequencyParam= struct {
    m: u8,
};

fn block_frequency_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn block_frequency_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn block_frequency_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    const param = self.param;

    var M: u8 = DEFAULT_BLOCK_SIZE;
    if (param.extra != null) {
        M = @as(*BlockFrequencyParam, @ptrCast(param.extra)).m;
    }

    var bits = io.BitStream.init(data);
    bits.setLength(self.param.num_bitstreams);

    // Step 1: N 个比特序列
    const N: usize = bits.len / M;

    var sum: f64 = 0.0;
    var i: u8 = 0;

    for (0..N) |_| {
        // Step 2: 块内 1 计数
        var ones: usize = 0;
        i = 0;

        while (bits.fetchBit()) |bit| {
            ones += bit;
            i += 1;
            if (i >= M) {
                break; // 达到块大小，停止计数
            }
        }

        const pi = @as(f64, @floatFromInt(ones)) / @as(f64, @floatFromInt(M));
        sum += (pi - 0.5) * (pi - 0.5);
    }

    // Step 3: 计算统计量
    const V: f64 = 4.0 * @as(f64, @floatFromInt(M)) * sum;

    // 计算 P 值
    const P = math.igamc(
        @as(f64, @floatFromInt(N)) / 2.0,
        V / 2.0);

    const passed = P > 0.01;
    return detect.DetectResult{
        .passed = passed,
        .v_value = V,
        .p_value = P,
        .q_value = P, // Q 值与 P 值相同
        .extra = null,
        .errno = null,
    };
}


pub fn blockFrequencyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, m: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.BlockFrequency;
    const mParam = try allocator.create(BlockFrequencyParam);
    mParam.* = BlockFrequencyParam{
        .m = m,
    };
    param_ptr.*.extra = mParam;

    ptr.* = detect.StatDetect{
        .name = "BlockFrequency",
        .param = param_ptr,
        ._init = block_frequency_init,
        ._iterate = block_frequency_iterate,
        ._destroy = block_frequency_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
