const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn random_excursions_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn random_excursions_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn random_excursions_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const n = data.len * 8;
    if (n < 100) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    const allocator = std.heap.page_allocator;

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };
    var bit_arr = allocator.alloc(u8, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer allocator.free(bit_arr);

    for (0..n) |i| {
        bit_arr[i] = if (bits.fetchBit()) |b| b else 0;
    }

    // 累计和S
    var S = allocator.alloc(i32, n + 1) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer allocator.free(S);
    S[0] = 0;
    for (0..n) |i| {
        if (bit_arr[i] == 1) {
            S[i + 1] = S[i] + 1;
        } else {
            S[i + 1] = S[i] - 1;
        }
    }

    // 找出所有S=0的位置
    var cycle_idx = std.ArrayList(usize).init(allocator);
    defer cycle_idx.deinit();
    for (0..(n + 1)) |i| {
        if (S[i] == 0) {
            _ = cycle_idx.append(i) catch {};
        }
    }
    const J = cycle_idx.items.len - 1;
    if (J < 1) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .stat_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 统计每个状态x在所有游程中出现的次数
    var count: [8]usize = .{0} ** 8; // x=-4..-1,1..4
    for (0..J) |j| {
        const start = cycle_idx.items[j];
        const end = cycle_idx.items[j + 1];
        for (start + 1..end + 1) |i| {
            const x = S[i];
            if (x >= -4 and x <= -1) count[@as(usize, @intCast(x + 4))] += 1;
            if (x >= 1 and x <= 4) count[@as(usize, @intCast(x + 3))] += 1;
        }
    }

    // 理论概率（NIST SP800-22, Table 4）
    const pi = [_]f64{
        0.010471, 0.03125, 0.125, 0.5, 0.5, 0.125, 0.03125, 0.010471
    };

    var chi2: f64 = 0.0;
    for (0..8) |i| {
        const exp = pi[i] * @as(f64, @floatFromInt(J));
        chi2 += ( @as(f64, @floatFromInt( count[i] )) - exp )
              * ( @as(f64, @floatFromInt( count[i] )) - exp ) / exp;
    }

    const p_value = math.igamc(4.0, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .p_value = p_value,
        .stat_value = chi2,
        .extra = null,
        .errno = null,
    };
}

pub fn randomExcursionsDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "RandomExcursions",
        .param = param_ptr,
        ._init = random_excursions_init,
        ._iterate = random_excursions_iterate,
        ._destroy = random_excursions_destroy,

        ._reset = detect.detectReset,
        ._print = detect.detectPrint,
        ._metrics = detect.detectMetrics,
        ._summary = detect.detectSummary,
    };
    return ptr;
}
