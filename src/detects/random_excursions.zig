const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const MAX_EXCURSION_RND_EXCURSION = 4;
// Number of states for TEST_RND_EXCURSION
const NUMBER_OF_STATES_RND_EXCURSION = 2*MAX_EXCURSION_RND_EXCURSION;
const DEGREES_OF_FREEDOM_RND_EXCURSION = 6;

const RandomExcursionsState = struct {
    pi: [MAX_EXCURSION_RND_EXCURSION][DEGREES_OF_FREEDOM_RND_EXCURSION]f64
      = .{[_]f64{0}**DEGREES_OF_FREEDOM_RND_EXCURSION} ** MAX_EXCURSION_RND_EXCURSION,
};


pub const RandomExcursionsResult = struct {
    counter: [NUMBER_OF_STATES_RND_EXCURSION]usize = .{0} ** NUMBER_OF_STATES_RND_EXCURSION,  // 每个状态的卡方统计量
    v_value: [NUMBER_OF_STATES_RND_EXCURSION]f64 =   .{0} ** NUMBER_OF_STATES_RND_EXCURSION,  // 每个状态的卡方统计量
    p_value: [NUMBER_OF_STATES_RND_EXCURSION]f64 =   .{0} ** NUMBER_OF_STATES_RND_EXCURSION,  // 每个状态的p值
    passed:  [NUMBER_OF_STATES_RND_EXCURSION]bool = .{true} ** NUMBER_OF_STATES_RND_EXCURSION,// 每个状态是否通过
    nCycles: usize = 0,             // 每个状态的循环数
};

fn random_excursions_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = param;

    var state = std.heap.page_allocator.create(RandomExcursionsState) catch |err| {
        std.debug.print("Error allocating RandomExcursionsState: {}\n", .{err});
        return;
    };

    for(0..MAX_EXCURSION_RND_EXCURSION) |i| {
        // Compute the theoretical probabilities when k = 0
	state.pi[i][0] = 1.0 - 1.0 / (2.0 * @as(f64, @floatFromInt(i + 1)));
    }

    for(1..DEGREES_OF_FREEDOM_RND_EXCURSION - 1) |j| {
	// Compute the theoretical probabilities when 0 < k < DEGREES_OF_FREEDOM_RND_EXCURSION - 1
        for(0 .. MAX_EXCURSION_RND_EXCURSION) |i| {
	    state.pi[i][j] = 1.0 / (4.0 * std.math.pow(f64, @as(f64, @floatFromInt(i + 1)), 2))
                * std.math.pow(f64, state.pi[i][0], @as(f64, @floatFromInt(j - 1)));
        }
    }

    // Compute the theoretical probabilities when k = DEGREES_OF_FREEDOM_RND_EXCURSION - 1
    for(0..MAX_EXCURSION_RND_EXCURSION) |i| {
        // Compute the theoretical probabilities when k = 0
	state.pi[i][DEGREES_OF_FREEDOM_RND_EXCURSION - 1] =
            1.0 / (2.0 *  @as(f64, @floatFromInt(i + 1))) * std.math.pow(f64, state.pi[i][0], 4);
    }
    self.state = state;
}

fn random_excursions_destroy(self: *detect.StatDetect) void {
    const state: *RandomExcursionsState = @alignCast(@ptrCast(self.state.?));
    std.heap.page_allocator.destroy(state);
}

fn random_excursions_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const n = self.param.n;
    // 检查最小样本量要求
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

    const allocator = std.heap.page_allocator;
    // 转换比特序列为±1序列
    const arr = allocator.alloc(u1, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer allocator.free(arr);
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

    var S = allocator.alloc(i32, n) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer allocator.free(S);

    var cycle_idx = std.ArrayList(usize).init(allocator);
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

    // 定义关注的状态值
    const states = [_]i32{ -4, -3, -2, -1, 1, 2, 3, 4 };
    var freq_table = [_][DEGREES_OF_FREEDOM_RND_EXCURSION]usize{[_]usize{0} ** DEGREES_OF_FREEDOM_RND_EXCURSION} ** 8; // [状态索引][频次桶]

    // 遍历每个循环统计状态频次
    var start: usize = 0;
    var stop: usize = 0;
    for (0..J) |j| {
        start = stop;
        stop = cycle_idx.items[j];
        var count: [8]usize = .{0} ** 8;

        // 统计当前循环中各状态出现次数
        for (start..stop) |i| {
            const s_val = S[i];
            // NOTE: 如此循环效率不高
            inline for (states, 0..) |s, idx| {
                if (s_val == s) {
                    count[idx] += 1;
                }
            }
        }

        // 更新频次分布表
        inline for (count, 0..) |cnt, idx| {
            const bucket = if (cnt < DEGREES_OF_FREEDOM_RND_EXCURSION-1) cnt else DEGREES_OF_FREEDOM_RND_EXCURSION-1;
            freq_table[idx][bucket] += 1;
        }
    }

    const state: *RandomExcursionsState = @alignCast(@ptrCast(self.state.?));

    // 准备结果存储
    const result = allocator.create(RandomExcursionsResult) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    var min_p_value: f64 = 1.0;
    var min_chi2: f64 = 0.0;
    var all_passed = true;

    // 对每个状态进行卡方检验
    inline for (0..NUMBER_OF_STATES_RND_EXCURSION) |state_idx| {
        var chi2: f64 = 0.0;
        var V: f64 = 0.0;

	const x: usize = @abs(states[state_idx]);

        // 计算卡方统计量
        // ∑(0..K) (Vk - j*pi)^2 / (j*pi)
        for (0..DEGREES_OF_FREEDOM_RND_EXCURSION) |k| {
            const Vk = @as(f64, @floatFromInt(freq_table[state_idx][k]));
            const pi = state.pi[x-1][k];
            const j = @as(f64, @floatFromInt(J));

            V = (Vk - (j*pi)) * (Vk - (j*pi)) / (j*pi);

            chi2 += V; // 卡方统计量
        }


        // 计算p值 (自由度=K-1=5)
        const p_value = math.igamc(2.5, chi2 / 2.0); // 5/2=2.5, 卡方/2

        // 更新结果
        result.v_value[state_idx] = chi2;
        result.p_value[state_idx] = p_value;
        result.passed[state_idx] = (p_value >= 0.01);

        // 更新全局结果
        if (p_value < min_p_value) {
            min_p_value = p_value;
            min_chi2 = chi2;
        }
        if (p_value < 0.01) {
            all_passed = false;
        }
    }

    return detect.DetectResult{
        .passed = all_passed,
        .v_value = min_chi2,
        .p_value = min_p_value,
        .q_value = min_p_value,
        .extra = result,
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
    };
    return ptr;
}
