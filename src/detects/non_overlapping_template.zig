const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

fn non_overlapping_template_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn non_overlapping_template_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn non_overlapping_template_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {
    _ = self;

    const m = 3;
    const n = data.len * 8;
    if (n < m) {
        return detect.DetectResult{
            .passed = false,
            .v_value = 0.0,
            .p_value = 0.0,
            .q_value = 0.0,
            .extra = null,
            .errno = null,
        };
    }

    // 固定模板 "111"
    const template = [_]u8{1, 1, 1};

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

    // 统计非重叠出现次数
    var W: usize = 0;
    var i: usize = 0;
    while (i + m <= n) {
        var match = true;
        for (0..m) |j| {
            if (bit_arr[i + j] != template[j]) {
                match = false;
                break;
            }
        }
        if (match) {
            W += 1;
            i += m;
        } else {
            i += 1;
        }
    }

    const mu = @as(f64, @floatFromInt(n - m + 1)) / 8.0;
    const sigma2 = @as(f64, @floatFromInt(n)) * (1.0 / 8.0 - (2.0 * m - 1.0) / 64.0);
    const chi2 = ( @as(f64, @floatFromInt(W)) - mu ) * ( @as(f64, @floatFromInt(W)) - mu ) / sigma2;
    const p_value = math.igamc(0.5, chi2 / 2.0);
    const passed = p_value > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = chi2,
        .p_value = p_value,
        .q_value = 0.0,
        .extra = null,
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

        ._init = non_overlapping_template_init,
        ._iterate = non_overlapping_template_iterate,
        ._destroy = non_overlapping_template_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
