const std = @import("std");
const math = @import("../src/math.zig");

const tolerance = 1e-10;

pub fn main() !void {
    std.debug.print("Testing erf function accuracy...\n", .{});
    
    const erf_test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 0.0 },
        .{ .x = 1.0, .expected = 0.8427007929497149 },
        .{ .x = -1.0, .expected = -0.8427007929497149 },
        .{ .x = 0.5, .expected = 0.5204998778130465 },
        .{ .x = 2.0, .expected = 0.9953222650189527 },
    };

    for (erf_test_cases) |case| {
        const result = math.erf(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erf({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        if (relative_error >= tolerance) {
            std.debug.print("  FAIL: relative error too large!\n", .{});
            return;
        } else {
            std.debug.print("  PASS\n", .{});
        }
    }
    
    std.debug.print("\nTesting erfc function accuracy...\n", .{});
    
    const erfc_test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 1.0 },
        .{ .x = 1.0, .expected = 0.1572992070502851 },
        .{ .x = -1.0, .expected = 1.8427007929497149 },
        .{ .x = 0.5, .expected = 0.4795001221869535 },
        .{ .x = 2.0, .expected = 0.004677734981047266 },
    };

    for (erfc_test_cases) |case| {
        const result = math.erfc(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erfc({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        if (relative_error >= tolerance) {
            std.debug.print("  FAIL: relative error too large!\n", .{});
            return;
        } else {
            std.debug.print("  PASS\n", .{});
        }
    }
    
    std.debug.print("\n✅ All erf and erfc accuracy tests passed!\n", .{});
}