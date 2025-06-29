const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn rank_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn rank_destroy(self: *detect.StatDetect) void {
    _ = self;
}

// 计算32x32二进制矩阵的秩（高斯消元）
fn binary_matrix_rank(matrix: *[32]u32) usize {
    var rank: usize = 0;
    var rows = matrix.*;

    for (0..32) |C| {
        const col:u5 = @as(u5, @intCast(C));

        var pivot_row: ?usize = null;
        for (rank..32) |row| {
            if ((rows[row] >> (31 - col)) & 1 == 1) {
                pivot_row = row;
                break;
            }
        }
        if (pivot_row) |pr| {
            if (pr != rank) {
                const tmp = rows[rank];
                rows[rank] = rows[pr];
                rows[pr] = tmp;
            }
            for (0..32) |row| {
                if (row != rank and ((rows[row] >> (31 - col)) & 1 == 1)) {
                    rows[row] ^= rows[rank];
                }
            }
            rank += 1;
        }
    }
    return rank;
}

fn rank_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const M = 32;
    const Q = 32;
    const block_bits = M * Q;
    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = data.len * 8 };
    const N = bits.len / block_bits;
    if (N == 0) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var freq = [_]usize{0} ** 3; // 32, 31, <31

    for (0..N) |_| {
        var matrix = [_]u32{0} ** 32;
        for (0..M) |row| {
            var val: u32 = 0;
            for (0..Q) |_| {
                if (bits.fetchBit()) |bit| {
                    val = (val << 1) | bit;
                }
            }
            matrix[row] = val;
        }
        const r = binary_matrix_rank(&matrix);
        if (r == 32) freq[0] += 1
        else if (r == 31) freq[1] += 1
        else freq[2] += 1;
    }

    // 理论概率（NIST SP800-22, 32x32）
    const p32 = 0.2888;
    const p31 = 0.5776;
    const p30 = 0.1336;

    const pi = [_]f64{ p32, p31, p30 };

    var chi2: f64 = 0.0;
    for (0..3) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        chi2 += ( @as(f64, @floatFromInt(freq[i])) - exp ) * ( @as(f64, @floatFromInt(freq[i])) - exp ) / exp;
    }

    const p_value = math.igamc(1.0, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = chi2,
        .extra = null,
        .errno = null,
    };
}

pub fn rankDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "Rank",
        .param = param_ptr,
        ._init = rank_init,
        ._iterate = rank_iterate,
        ._destroy = rank_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
