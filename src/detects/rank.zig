const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");
const matrix = @import("../matrix.zig");

fn rank_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn rank_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn rank_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {

    const M = 32;
    const Q = 32;
    var bits = io.BitStream.init(data);
    bits.setLength(self.param.num_bitstreams);
    const N = bits.len / (M*Q);

    if (N == 0) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var mat = matrix.createMatrix(M, Q) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    var freq = [_]usize{0} ** 3; // 32, 31, <31

    for (0..N) |_| {
        matrix.resetMatrix(mat);


        for (0..M) |x| {
            for (0..Q) |y| {
                mat[x][y] = bits.fetchBit() orelse 0;
            }
        }
        const r = matrix.computeRank(mat, M, Q);

        if (r == 32)
           freq[0] += 1
        else if (r == 31)
           freq[1] += 1
        else
           freq[2] += 1;
    }

    //std.debug.print("F1={d:.6}, F2={d:.6}, F3 = {d:.6}\n", .{freq[0], freq[1], freq[2]});

    // 理论概率（NIST SP800-22, 32x32）
    const p32 = 0.2888;
    const p31 = 0.5776;
    const p30 = 0.1336;

    const pi = [_]f64{ p32, p31, p30 };

    var chi2: f64 = 0.0;
    for (0..3) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        chi2 += ( @as(f64, @floatFromInt(freq[i])) - exp )
              * ( @as(f64, @floatFromInt(freq[i])) - exp )
              / exp;
    }

    const P = math.igamc(1.0, chi2 / 2.0);
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

pub fn rankDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.Rank;
    ptr.* = detect.StatDetect{
        .name = "Rank",
        .param = param_ptr,

        ._init = rank_init,
        ._iterate = rank_iterate,
        ._destroy = rank_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
