const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const MAX_EXCURSION_RND_EXCURSION_VAR = 9;
// Number of states for TEST_RND_EXCURSION_VAR
const NUMBER_OF_STATES_RND_EXCURSION_VAR = 2*MAX_EXCURSION_RND_EXCURSION_VAR;

pub const RandomExcursionsVariantResult = struct {
    counter: [NUMBER_OF_STATES_RND_EXCURSION_VAR]usize = .{0} ** NUMBER_OF_STATES_RND_EXCURSION_VAR,  // 每个状态的卡方统计量
    v_value: [NUMBER_OF_STATES_RND_EXCURSION_VAR]f64 =   .{0} ** NUMBER_OF_STATES_RND_EXCURSION_VAR,  // 每个状态的卡方统计量
    p_value: [NUMBER_OF_STATES_RND_EXCURSION_VAR]f64 =   .{0} ** NUMBER_OF_STATES_RND_EXCURSION_VAR,  // 每个状态的p值
    passed:  [NUMBER_OF_STATES_RND_EXCURSION_VAR]bool = .{true} ** NUMBER_OF_STATES_RND_EXCURSION_VAR,// 每个状态是否通过
    nCycles: usize = 0,             // 每个状态的循环数
};

fn random_excursions_variant_print(self: *detect.StatDetect, result: *const detect.DetectResult, level: detect.PrintLevel) void {
    detect.detectPrint(self, result, level);
    if (result.extra == null) {
        return;
    }

    const results = @as(*RandomExcursionsVariantResult, @alignCast(@ptrCast(result.extra.?)));
    var passed: usize = 0;
    for (0..results.passed.len) |i| {
        if (results.passed[i]) {
            passed += 1;
        }
    }
    std.debug.print("\tStatus passed: {d}/{d}  failed: {d}/{d}\n",
    .{passed, results.passed.len, results.passed.len - passed, results.passed.len});

    if (level == .detail) {
        std.debug.print("\n", .{});
        for (0..results.passed.len) |i| {
            std.debug.print("\tState {d:>3}: passed={s}, V = {d:10.6} P = {d:.6}\n",
            .{
                i,
                if (results.passed[i]) "Yes" else "No ",
                results.v_value[i],
                results.p_value[i],
            });
        }
    }
    std.debug.print("\n", .{});
}

fn random_excursions_variant_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn random_excursions_variant_destroy(self: *detect.StatDetect) void {
    if (self.state == null) return;
    const result: *RandomExcursionsVariantResult = @alignCast(@ptrCast(self.state.?));
    std.heap.page_allocator.destroy(result);
}

fn random_excursions_variant_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    _ = self;

    const n = bits.len();
    if (n < 1000) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    const arr = std.heap.page_allocator.alloc(u1, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(arr);

    if (bits.fetchBits(arr) != n) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 累计和S
    // S[0] = 0, S[i+1] = S[i] + (arr[i] == 1 ? 1 : -1)
    var S = std.heap.page_allocator.alloc(i32, n + 1) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .p_value = 0.0,
            .q_value = 0.0,
            .v_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer std.heap.page_allocator.free(S);

    var cycle_idx = std.ArrayList(usize).init(std.heap.page_allocator);
    defer cycle_idx.deinit();

    // 计算累积、收集零交叉点
    S[0] = @as(i32, if(arr[0]==1) 1 else -1); // 初始化第一个元素 ;
    for (1..n) |i| {
        S[i] = S[i-1] + @as(i32, if(arr[i]==1) 1 else -1);
        // 收集零交叉点
        if (S[i] == 0) {
            cycle_idx.append(i) catch {};
        }
    }

    if (S[n - 1] != 0) {
        cycle_idx.append(n) catch {};
    }

    const J: usize = cycle_idx.items.len;
    const min_cycles = @max(500, @as(usize, @intFromFloat(0.005 * @sqrt(@as(f64, @floatFromInt(n))))));

    // 检查最小循环数要求
    if (J < min_cycles) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    var result: *RandomExcursionsVariantResult = std.heap.page_allocator.create(RandomExcursionsVariantResult) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    for (0..NUMBER_OF_STATES_RND_EXCURSION_VAR) |k| {
        result.passed[k] = true;
        result.counter[k] = 0;
        result.v_value[k] = 0.0;
        result.p_value[k] = 0.0;
    }
    result.nCycles = J;

    // 统计每个状态 x=±1..9 在所有游程中出现的次数
    var start: usize = 0;
    var stop: usize = 0;

    for (0..J) |j| {
        start = stop;
        stop = cycle_idx.items[j];

        // 统计当前循环中各状态出现次数
        for (start..stop) |i| {
            const x = S[i];

            if (x >= -9 and x <= -1) result.counter[@as(usize, @intCast(x + 9))] += 1;
            if (x >= 1 and x <= 9) result.counter[@as(usize, @intCast(x + 8))] += 1;
        }
    }

    var min_p_value: f64 = 1.0;
    var min_z_value: f64 = 0.0;
    for (0..NUMBER_OF_STATES_RND_EXCURSION_VAR) |k| {
        const K = @as(f64, @floatFromInt(if (k < 9) @as(isize, @intCast(k)) - MAX_EXCURSION_RND_EXCURSION_VAR  else @as(isize, @intCast(k)) - 8));
        const V = @as(f64, @floatFromInt(@abs( @as(isize, @intCast(result.counter[k])) - @as(isize, @intCast(result.nCycles)))))
                / ( @sqrt(2.0 * @as(f64, @floatFromInt(result.nCycles)) * (4.0 * @abs(K) - 2.0)));
        const P = math.erfc( V );

	result.p_value[k] = P;
        result.v_value[k] = V;
        if (P < min_p_value) {
            min_p_value = P;
            min_z_value = V;
        }
    }
    const passed = min_p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = min_z_value,
        .p_value = min_p_value,
        .q_value = min_p_value,
        .extra = result,
        .errno = null,
    };
}

pub fn randomExcursionsVariantDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.RandomExcursionsVariant;
    ptr.* = detect.StatDetect{
        .name = "RandomExcursionsVariant",
        .param = param_ptr,

        ._init = random_excursions_variant_init,
        ._iterate = random_excursions_variant_iterate,
        ._destroy = random_excursions_variant_destroy,

        ._reset = detect.detectReset,
        ._print = random_excursions_variant_print,
    };
    return ptr;
}
