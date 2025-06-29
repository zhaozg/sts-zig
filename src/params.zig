const std = @import("std");
const detect = @import("detect.zig");

pub fn parseArgs(allocator: std.mem.Allocator, argv: [][*:0]u8) ![]const detect.DetectParam {
    // 简化示例，实际应解析命令行参数
    _ = allocator;
    _ = argv;

    const static_params = [_]detect.DetectParam{
        .{
            .type = detect.DetectType.Frequency,
            .n = 1000000,
            .num_bitstreams = 10,
            .extra = null, // 可扩展更多参数
        },
    };

    // 返回切片
    return static_params[0..];
}
