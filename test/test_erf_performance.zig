const std = @import("std");
const math_file = @import("../src/math.zig");

pub fn main() !void {
    std.debug.print("Testing erf and erfc functions...\n", .{});
    
    const test_values = [_]f64{0.0, 0.5, 1.0, -1.0, 2.0, -2.0};
    
    for (test_values) |x| {
        std.debug.print("Testing x = {d}...\n", .{x});
        
        const start_time = std.time.nanoTimestamp();
        const erf_result = math_file.erf(x);
        const erf_time = std.time.nanoTimestamp() - start_time;
        
        const start_time2 = std.time.nanoTimestamp();
        const erfc_result = math_file.erfc(x);
        const erfc_time = std.time.nanoTimestamp() - start_time2;
        
        std.debug.print("  erf({d}) = {d} (time: {}ns)\n", .{x, erf_result, erf_time});
        std.debug.print("  erfc({d}) = {d} (time: {}ns)\n", .{x, erfc_result, erfc_time});
        std.debug.print("  erf + erfc = {d} (should be close to 1.0)\n", .{erf_result + erfc_result});
        
        if (erf_time > 1_000_000_000 or erfc_time > 1_000_000_000) {  // 1 second
            std.debug.print("WARNING: Function took too long!\n", .{});
        }
    }
}