const std = @import("std");
const detect = @import("detect.zig");
const frequency = @import("detects/frequency.zig");

pub const DetectSuite = struct {
    allocator: std.mem.Allocator,
    detects: std.ArrayList(*detect.StatDetect),

    pub fn init(allocator: std.mem.Allocator) !DetectSuite {
        return DetectSuite{
            .allocator = allocator,
            .detects = try std.ArrayList(*detect.StatDetect).initCapacity(allocator, 8),
        };
    }

    pub fn registerAll(self: *DetectSuite) !void {
        try self.detects.append(try frequency.frequencyDetectStatDetect(self.allocator));
        // 继续注册其他测试
    }

    pub fn runAll(self: *DetectSuite, params: *const detect.DetectParam, data: []const u8) !void {
        for (self.detects.items) |t| {
            t.init(t, params);
            //var results = try std.ArrayList(detect.DetectResult).init(self.allocator);
            // 这里只做一次，实际可多次迭代
            const result = t.iterate(t, data);
            var results = std.ArrayList(detect.DetectResult).init(self.allocator);
            results.append(result) catch |err| {
                std.debug.print("Error appending result: {}\n", .{err});
                return err;
            };
            t.metrics(t, results.items);
            t.print(t, results.items);
            t.destroy(t);
        }
    }
};
