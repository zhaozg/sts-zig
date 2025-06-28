const std = @import("std");
const detect = @import("detect.zig");

pub fn parseArgs(allocator: std.mem.Allocator, argv: [][*:0]u8) !detect.DetectParam {
    // 简化示例，实际应解析命令行参数
    _ = allocator;
    _ = argv;
    return detect.DetectParam{
        .n = 1000000,
        .num_bitstreams = 10,
    };
}
