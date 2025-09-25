const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn linear_complexity_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn linear_complexity_destroy(self: *detect.StatDetect) void {
    self.allocator.destroy(self.param);
    self.allocator.destroy(self);
}

// Berlekamp-Massey算法，返回线性复杂度
fn berlekamp_massey(seq: []const u8) usize {
    const M = seq.len;
    var c = [_]u8{0} ** 500;
    var b = [_]u8{0} ** 500;
    c[0] = 1;
    b[0] = 1;
    var L: usize = 0;
    var m: usize = 0;
    var N: usize = 0;
    while (N < M) : (N += 1) {
        var d: u8 = seq[N];
        for (1..L + 1) |i| {
            d ^= c[i] & seq[N - i];
        }
        if (d == 1) {
            const t = c;
            for (0..M - N + m) |i| {
                c[N - m + i] ^= b[i];
            }
            if (L <= N / 2) {
                L = N + 1 - L;
                m = N;
                b = t;
            }
        }
    }
    return L;
}

fn linear_complexity_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const M = 500;
    const K = 6;
    const n = self.param.n;

    const N = n / M;
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

    var bit_arr = std.heap.page_allocator.alloc(u8, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(bit_arr);
    for (0..n) |i| {
        bit_arr[i] = if (bits.fetchBit()) |b| b else 0;
    }

    // NIST推荐区间
    const pi = [_]f64{ 0.010417, 0.03125, 0.125, 0.5, 0.25, 0.083333 };
    var v = [_]usize{0} ** K;

    const mean = @as(f64, @floatFromInt(M)) / 2.0 + (9.0 + std.math.pow(f64, -1.0, @as(f64, @floatFromInt(M)))) / 36.0;

    for (0..N) |blk| {
        const offset = blk * M;
        const L = berlekamp_massey(bit_arr[offset .. offset + M]);
        const T = @as(f64, @floatFromInt(L)) - mean;
        if (T <= -2.5) v[0] += 1 else if (T <= -1.5) v[1] += 1 else if (T <= -0.5) v[2] += 1 else if (T <= 0.5) v[3] += 1 else if (T <= 1.5) v[4] += 1 else v[5] += 1;
    }

    var chi2: f64 = 0.0;
    for (0..K) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(N));
        chi2 += (@as(f64, @floatFromInt(v[i])) - exp) * (@as(f64, @floatFromInt(v[i])) - exp) / exp;
    }

    const p_value = math.igamc(2.5, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = chi2,
        .p_value = p_value,
        .q_value = p_value,
        .extra = null,
        .errno = null,
    };
}

pub fn linearComplexityDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "LinearComplexity",
        .param = param_ptr,
        .allocator = allocator,

        ._init = linear_complexity_init,
        ._iterate = linear_complexity_iterate,
        ._destroy = linear_complexity_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
