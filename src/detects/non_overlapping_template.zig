const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");
const compat = @import("../compat.zig");

pub const NonOverlappingTemplateResult = struct {
    n: usize,
    passed: []bool,
    template_patterns: []u32, // Store template patterns as integers instead of arrays
    v_value: []f64,
    p_value: []f64,
    template_size: u4, // Store the template size (m) to reconstruct patterns
};

fn non_overlapping_template_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn non_overlapping_template_destroy(self: *detect.StatDetect) void {
    self.allocator.destroy(self.param);
    self.allocator.destroy(self);
}

fn non_veerlapping_template_print(self: *detect.StatDetect, result: *const detect.DetectResult, level: detect.PrintLevel) void {
    detect.detectPrint(self, result, level);
    if (result.extra == null) {
        return;
    }

    const results = @as(*NonOverlappingTemplateResult, @ptrCast(@alignCast(result.extra.?)));
    var passed: usize = 0;
    for (0..results.passed.len) |i| {
        if (results.passed[i]) {
            passed += 1;
        }
    }
    std.debug.print("\tStatus passed: {d}/{d}  failed: {d}/{d}\n", .{ passed, results.passed.len, results.passed.len - passed, results.passed.len });

    if (level == .detail) {
        std.debug.print("\n", .{});
        for (0..results.n) |i| {
            // Reconstruct template pattern for display
            var template_bits = [_]u1{0} ** 9;
            patternToBits(results.template_patterns[i], results.template_size, template_bits[0..results.template_size]);

            std.debug.print("\tState {d:3}: {}{}{}{}{}{}{}{}{} passed={s}, V = {d:10.6} P = {d:.6}\n", .{
                i,
                template_bits[0],
                template_bits[1],
                template_bits[2],
                template_bits[3],
                template_bits[4],
                template_bits[5],
                template_bits[6],
                template_bits[7],
                template_bits[8],
                if (results.passed[i]) "Yes" else "No ",
                results.v_value[i],
                results.p_value[i],
            });
        }
        std.debug.print("\n", .{});
    }
}

const BLOCKS_NON_OVERLAPPING = 8; // 可根据实际情况调整

fn generateNonPeriodicTemplatePatterns(m: u4, allocator: std.mem.Allocator) ![]u32 {
    var patterns = compat.ArrayList(u32).init(allocator);
    const max_num: usize = @as(usize, 1) << m;
    for (1..max_num) |val| {
        var arr = try allocator.alloc(u1, m);
        defer allocator.free(arr);

        for (0..m) |i| {
            arr[i] = if (((val >> @as(u6, @intCast(m - 1 - i))) & 1) == 1) 1 else 0;
        }
        if (!isPeriodic(arr)) {
            try patterns.append(@as(u32, @intCast(val)));
        }
    }
    return patterns.toOwnedSlice();
}

fn patternToBits(pattern: u32, m: u4, bits: []u1) void {
    for (0..m) |i| {
        bits[i] = if (((pattern >> @as(u5, @intCast(m - 1 - i))) & 1) == 1) 1 else 0;
    }
}

fn isPeriodic(arr: []u1) bool {
    const m = arr.len;
    for (1..m) |p| {
        var periodic = true;
        for (0..m - p) |i| {
            if (arr[i] != arr[i + p]) {
                periodic = false;
                break;
            }
        }
        if (periodic) return true;
    }
    return false;
}

fn isEquals(arr: []const u1, mat: []const u1) bool {
    if (arr.len != mat.len) return false;
    for (0..arr.len) |i| {
        if (arr[i] != mat[i]) return false;
    }
    return true;
}

fn non_overlapping_template_iterate(self: *detect.StatDetect, bits: *const io.BitInputStream) detect.DetectResult {
    const m = 9;
    const n = self.param.n;
    const M = n / BLOCKS_NON_OVERLAPPING;

    if (M < m) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    const mu = @as(f64, @floatFromInt(M - m + 1)) / @as(f64, @floatFromInt(1 << m));
    const sigma_squared = @as(f64, @floatFromInt(M)) * (1.0 / @as(f64, @floatFromInt(1 << m)) -
        (2.0 * m - 1.0) / @as(f64, @floatFromInt(1 << (2 * m))));
    // std.debug.print("u={d:.6} sigma_squared = {d:.6}\n", .{mu, sigma_squared});

    const arr = bits.bits();
    if (arr.len != n) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 生成模板
    const template_patterns = generateNonPeriodicTemplatePatterns(m, self.allocator) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    defer self.allocator.free(template_patterns);

    var results: *NonOverlappingTemplateResult = self.allocator.create(NonOverlappingTemplateResult) catch |err| {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    results.n = template_patterns.len;
    results.template_size = m;
    results.template_patterns = self.allocator.alloc(u32, template_patterns.len) catch |err| {
        self.allocator.destroy(results);
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    std.mem.copyForwards(u32, results.template_patterns, template_patterns);

    results.passed = self.allocator.alloc(bool, template_patterns.len) catch |err| {
        self.allocator.free(results.template_patterns);
        self.allocator.destroy(results);
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    results.p_value = self.allocator.alloc(f64, template_patterns.len) catch |err| {
        self.allocator.free(results.template_patterns);
        self.allocator.free(results.passed);
        self.allocator.destroy(results);
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };
    results.v_value = self.allocator.alloc(f64, template_patterns.len) catch |err| {
        self.allocator.free(results.template_patterns);
        self.allocator.free(results.passed);
        self.allocator.free(results.p_value);
        self.allocator.destroy(results);
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = err,
        };
    };

    var p_min: f64 = 1.0;
    var v_min: f64 = 0.0;

    for (template_patterns, 0..template_patterns.len) |pattern, i| {
        // Temporarily reconstruct the template for processing
        const template = self.allocator.alloc(u1, m) catch |err| {
            return detect.DetectResult{
                .passed = false,
                .v_value = 0.0,
                .p_value = 0.0,
                .q_value = 0.0,
                .extra = null,
                .errno = err,
            };
        };
        defer self.allocator.free(template);
        patternToBits(pattern, m, template);

        var Wj = [_]usize{0} ** BLOCKS_NON_OVERLAPPING;
        for (0..BLOCKS_NON_OVERLAPPING) |block_idx| {
            var count: usize = 0;
            var j: usize = 0;
            while (j + m <= M) {
                var match = true;
                for (0..m) |k| {
                    if (arr[block_idx * M + j + k] != template[k]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    count += 1;
                    j += m;
                } else {
                    j += 1;
                }
            }
            Wj[block_idx] = count;
        }

        var chi2: f64 = 0.0;
        for (Wj) |w| {
            chi2 += ((@as(f64, @floatFromInt(w)) - mu) * (@as(f64, @floatFromInt(w)) - mu)) / sigma_squared;
        }
        const p_value = math.igamc(BLOCKS_NON_OVERLAPPING / 2.0, chi2 / 2.0);

        results.passed[i] = p_value > 0.01;
        results.p_value[i] = p_value;
        results.v_value[i] = chi2;

        // const mat: [9]u1 = [_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 1 };
        // if (isEquals(template, mat[0..])) {
        //     for(Wj, 0..)|w, x| {
        //         std.debug.print("Wj[{d}] = {d}\n", .{x, w});
        //     }
        // }
        //

        if (p_value < p_min) {
            p_min = p_value;
            v_min = chi2;
        }
    }
    return detect.DetectResult{
        .passed = p_min > 0.01,
        .v_value = v_min,
        .p_value = p_min,
        .q_value = p_min,
        .extra = results,
        .errno = null,
    };
}

pub fn nonOverlappingTemplateDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.General;
    ptr.* = detect.StatDetect{
        .name = "NonOverlappingTemplate",
        .param = param_ptr,
        .allocator = allocator,

        ._init = non_overlapping_template_init,
        ._iterate = non_overlapping_template_iterate,
        ._destroy = non_overlapping_template_destroy,

        ._reset = detect.detectReset,
        ._print = non_veerlapping_template_print,
    };
    return ptr;
}
