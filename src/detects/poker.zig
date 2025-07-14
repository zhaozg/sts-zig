const detect = @import("../detect.zig");
const io = @import("../io.zig");
const std = @import("std");
const math = @import("../math.zig");

fn poker_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn poker_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    if (self.param.extra == null) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .errno = error.InvalidArgument,
            .extra = null
        };
    }

    const param: *PokerParam = @ptrCast(self.param.extra);
    const m = @as(u4, @intCast(param.m));

    if (!(m == 2 or m == 4 or m == 8)) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .errno = error.InvalidArgument,
            .extra = null
        };
    }
    const M = @as(u16, 1) << m;

    var counts = std.heap.page_allocator.alloc(usize, M) catch |err| {
        //std.debug.print("Poker Test: allocation failed: {}\n", .{err});
        _ = err catch {};
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = error.OutOfMemory,
        };
    };

    defer std.heap.page_allocator.free(counts);
    for (counts) |*c| {
        c.* = 0;
    }

    // 解读公式：$ V = \frac{2^m}{N} \sum_{i=1}^{2^m} n_i^2 - N $

    // ### 1. **公式结构**
    // $$
    // V = \frac{2^m}{N} \sum_{i=1}^{2^m} n_i^2 - N
    // $$
    //
    // - $ V $：最终计算得到的统计量。
    // - $ 2^m $：表示序列的长度或分组数量，其中 $ m $ 是一个正整数。
    // - $ N $：总样本数量或序列长度。
    // - $ n_i $：第 $ i $ 个分组或元素的计数值。
    // - $ \sum_{i=1}^{2^m} n_i^2 $：对所有 $ n_i $ 的平方求和。
    // - 如果 $ m = 3 $，则 $ 2^m = 8 $，表示将序列分为 8 个分组。
    // - 这种分组方式常见于频率测试（Frequency Test）或块频率测试（Block Frequency Test），用于分析二进制序列的分布特性。

    // #### (2) **$ n_i $**
    // - $ n_i $ 表示第 $ i $ 个分组中 `'1'` 或 `'0'` 的计数值。
    // - 例如，在频率测试中，$ n_i $ 可以是某个区间内 `'1'` 的个数。

    // #### (3) **$ \sum_{i=1}^{2^m} n_i^2 $**
    // - 对每个分组的计数值 $ n_i $ 求平方，并对所有分组的平方值求和。
    // - 这一步是为了衡量每个分组的偏差程度，平方操作可以放大偏离平均值较大的分组的影响。
    //
    // #### (4) **$ \frac{2^m}{N} $**
    // - $ \frac{2^m}{N} $ 是一个缩放因子，用于调整公式的结果范围。
    // - $ N $ 是总样本数量，通常是序列的长度。
    // - $ \frac{2^m}{N} $ 的作用是根据序列长度和分组数量进行归一化，确保结果具有可比性。
    //
    // #### (5) **$ - N $**
    // - 最后减去 $ N $，这是为了进一步调整公式的结果，使其符合特定的统计分布（如标准正态分布）。

    // Step 1: 计算 N
    const N: usize = bits.len() / m;

    // Step 2.1: 子序列计数
    var Ni: usize = 0;
    while (Ni < N) {

        var value: u8 = 0;
        for (0..m) |_| {
            if (bits.fetchBit()) |bit| {
                value = (value << 1) | @as(u8, @intCast(bit));
            }
        }

        counts[value] += 1;

        Ni += 1;
    }

    // Step 2.2: 计算统计值
    var sum: f64 = 0.0;
    for (counts) |c| {
        sum += @as(f64, @floatFromInt(c)) * @as(f64, @floatFromInt(c));
    }

    const V = @as(f64, @floatFromInt(M)) * sum / @as(f64, @floatFromInt(N))
            - @as(f64, @floatFromInt(N));

    // 卡方分布自由度为 num_patterns-1
    const P = math.igamc(( @as(f64, @floatFromInt(M)) - 1) / 2, V / 2 );
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

fn poker_destroy(self: *detect.StatDetect) void {
    const param: *PokerParam = @ptrCast(self.param.extra);
    _ = param;
}

const PokerParam = struct {
    m: u8, // m = 2, 4, or 8,
};

pub fn pokerDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, m: u8) !*detect.StatDetect {
    const poker_ptr = try allocator.create(detect.StatDetect);

    const param_ptr = try allocator.create(detect.DetectParam);

    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Poker; // 确保类型正确
    param_ptr.*.extra = null; // 目前没有额外参数
    //
    const poker_param: *PokerParam = try allocator.create(PokerParam);
    poker_param.* = PokerParam{ .m = m };
    param_ptr.extra = poker_param;

    poker_ptr.* = detect.StatDetect{
        .name = "Poker",
        .param = param_ptr,

        ._init = poker_init,
        ._iterate = poker_iterate,
        ._destroy = poker_destroy,

        ._reset = detect.detectReset,
    };

    return poker_ptr;
}
