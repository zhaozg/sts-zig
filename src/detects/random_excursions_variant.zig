const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn random_excursions_variant_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn random_excursions_variant_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn random_excursions_variant_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const n = data.len * 8;
    if (n < 100) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var bits = io.BitStream{ .data = data, .bit_index = 0, .len = n };
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

    // 累计和S
    var S = std.heap.page_allocator.alloc(i32, n + 1) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .v_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(S);
    S[0] = 0;
    for (0..n) |i| {
        S[i + 1] = S[i] + if (bit_arr[i] == 1) 1 else -1;
    }

    // 找出所有S=0的位置
    var cycle_idx = std.ArrayList(usize).init(std.heap.page_allocator);
    defer cycle_idx.deinit();
    for (0..(n + 1)) |i| {
        if (S[i] == 0) {
            cycle_idx.append(i) catch {};
        }
    }
    const J = cycle_idx.items.len - 1;
    if (J < 1) {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .v_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 统计每个状态x在所有游程中出现的次数
    var count = [_]usize{0} ** 18; // x=-9..-1,1..9
    for (0..J) |j| {
        const start = cycle_idx.items[j];
        const end = cycle_idx.items[j + 1];
        for (start + 1..end + 1) |i| {
            const x = S[i];
            if (x >= -9 and x <= -1) count[(x + 9) - 1] += 1;
            if (x >= 1 and x <= 9) count[(x + 9) - 1] += 1;
        }
    }

    // 理论概率（NIST SP800-22, Table 5）
    const pi = [_]f64{
        0.000000000, 0.000000002, 0.000000061, 0.000001104, 0.000010765, 0.000062209, 0.000248019, 0.000701307, 0.001655210,
        0.003248188, 0.005904900, 0.009098534, 0.012903800, 0.017099480, 0.021269400, 0.024997500, 0.027864900, 0.029599000
    };
    // 实际上NIST只推荐x=±1..9，pi对称，表中只需±1..9
    // 这里pi[0..8]为-9..-1，pi[9..17]为1..9

    var min_p_value: f64 = 1.0;
    var min_z_value: f64 = 0.0;
    for (0..18) |i| {
        const mu = @as(f64, @floatFromInt(J)) * pi[i];
        const sigma2 = @as(f64, @floatFromInt(J)) * pi[i] * (1.0 - pi[i]);
        if (sigma2 == 0.0) continue;
        const z = (@as(f64, @floatFromInt(count[i])) - mu) / std.math.sqrt(sigma2);
        const p = math.erfc(@abs(z) / std.math.sqrt(2.0));
        if (p < min_p_value) {
            min_p_value = p;
            min_z_value = z;
        }
    }
    const passed = min_p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = min_z_value,
        .p_value = min_p_value,
        .q_value = 0.0,
        .extra = null,
        .errno = null,
    };
}

pub fn randomExcursionsVariantDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "RandomExcursionsVariant",
        .param = param_ptr,

        ._init = random_excursions_variant_init,
        ._iterate = random_excursions_variant_iterate,
        ._destroy = random_excursions_variant_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
