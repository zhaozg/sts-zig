const std = @import("std");
const detect= @import("detect.zig");

pub fn readInputData(allocator: std.mem.Allocator, params: detect.DetectParam) ![]u8 {
    // 这里只是示例，实际应读取文件或标准输入
    return try allocator.alloc(u8, params.n);
}
