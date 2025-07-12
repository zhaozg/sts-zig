const detect = @import("../detect.zig");
const io = @import("../io.zig");
const math = @import("../math.zig");
const std = @import("std");

const OverlappingSequencyParam = struct {
    m: u8, // m = 3, 5, or 7,
};

fn overlapping_sequency_init(self: *detect.StatDetect, param: *const detect.DetectParam) void {
    _ = self;
    _ = param;
}

fn overlapping_sequency_destroy(self: *detect.StatDetect) void {
    _ = self;
}

fn overlapping_sequency_iterate(self: *detect.StatDetect, data: []const u8) detect.DetectResult {

    var m : u8 = 3;
    if(self.param.extra != null) {
        const osParam: *OverlappingSequencyParam = @ptrCast(self.param.extra);
        m = osParam.*.m;
    }
    var bits = io.BitStream.init(data);
    const allocator = std.heap.page_allocator;

    const n = bits.len;

    var arr: []u1 = allocator.alloc(u1, n + m - 1) catch |err| {
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

    var n_arr: [1<<8]usize = [_]usize{0}**(1<<8);
    var n1_arr: [1<<8]usize = [_]usize{0}**(1<<8);
    var n2_arr: [1<<8]usize = [_]usize{0}**(1<<8);

    var i: usize = 0;

    while(bits.fetchBit())|b| {
        arr[i] = b;
        i+=1;
    }
    for (0..m-1) |j| {
        arr[n+j] = arr[j];
    }


    for(0..n)|k| {
        var M: u8 = 0;
        for(0..m) |j| {
            M = (M << 1) | arr[k+j];
        }
        n_arr[M] += 1;
    }

    for(0..n)|k| {
        var M: u8 = 0;
        for(0..m - 1) |j| {
            M = (M << 1) | arr[k+j];
        }
        n1_arr[M] += 1;
    }

    if (m > 2) {
        for(0..n)|k| {
            var M: u8 = 0;
            for(0..m - 2) |j| {
                M = (M << 1) | arr[k+j];
            }
            n2_arr[M] += 1;
        }
    }

    // 步骤3: 计算Ψ^2统计量
    var psi2_m : f64 = 0;
    var psi2_m1 : f64 = 0;
    var psi2_m2 : f64 = 0;

    for(0 .. (@as(usize, 1) << @as(u3, @intCast(m))))|j| {
        psi2_m += @as(f64, @floatFromInt(n_arr[j])) * @as(f64, @floatFromInt(n_arr[j]));
    }

    psi2_m = (   @as(f64, @floatFromInt(@as(usize, 1) << @as(u3, @intCast(m))))
               / @as(f64, @floatFromInt(bits.len)) ) * psi2_m
           - @as(f64, @floatFromInt(bits.len));

    for(0 .. (@as(usize, 1) << @as(u3, @intCast(m-1))))|j| {
        psi2_m1 += @as(f64, @floatFromInt(n1_arr[j])) * @as(f64, @floatFromInt(n1_arr[j]));
    }

    psi2_m1 = (   @as(f64, @floatFromInt(@as(usize, 1) << @as(u3, @intCast(m-1))))
                / @as(f64, @floatFromInt(bits.len)) ) * psi2_m1
           - @as(f64, @floatFromInt(bits.len));

    if ( m > 2 ) {
        for(0 .. (@as(usize, 1) << @as(u3, @intCast(m-2))))|j| {
            psi2_m2 += @as(f64, @floatFromInt(n2_arr[j])) * @as(f64, @floatFromInt(n2_arr[j]));
        }
        psi2_m2 = (   @as(f64, @floatFromInt(@as(usize, 1) << @as(u3, @intCast(m-2))))
        / @as(f64, @floatFromInt(bits.len)) ) * psi2_m2
        - @as(f64, @floatFromInt(bits.len));
    }

    const nabla1: f64 = psi2_m - psi2_m1;
    const nabla2: f64 = psi2_m - 2 * psi2_m1 + psi2_m2;

    const P1 = math.igamc(std.math.pow(f64,2.0, @as(f64, @floatFromInt(m-2))), nabla1 / 2.0);
    const P2 = math.igamc(std.math.pow(f64,2.0, @as(f64, @floatFromInt(@as(i8,  @intCast(m))-3))), nabla2 / 2.0);

    const passed = P1 > 0.01 and P2 > 0.01;

    return detect.DetectResult{
        .passed = passed,
        .v_value = nabla1,
        .p_value = P1,
        .q_value = P2,
        .extra = null,
        .errno = null,
    };
}

pub fn overlappingSequencyDetectStatDetect(allocator: std.mem.Allocator, param: detect.DetectParam, m: u8) !*detect.StatDetect {
    const ptr = try allocator.create(detect.StatDetect);
    const param_ptr = try allocator.create(detect.DetectParam);
    param_ptr.* = param;
    param_ptr.*.type = detect.DetectType.OverlappingSequency;
    const osParam : *OverlappingSequencyParam = try allocator.create(OverlappingSequencyParam);
    osParam.*.m = m;
    param_ptr.*.extra = @ptrCast(osParam);

    ptr.* = detect.StatDetect{
        .name = "OverlappingSequency",
        .param = param_ptr,

        ._init = overlapping_sequency_init,
        ._iterate = overlapping_sequency_iterate,
        ._destroy = overlapping_sequency_destroy,

        ._reset = detect.detectReset,
    };
    return ptr;
}
