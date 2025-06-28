const std = @import("std");
const suite = @import("suite.zig");
const params = @import("params.zig");
const io = @import("io.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator(); // 注意这里是方法调用

    var detect_params = try params.parseArgs(allocator, std.os.argv);
    var detect_suite = try suite.DetectSuite.init(allocator);

    try detect_suite.registerAll();
    const data = try io.readInputData(allocator, detect_params);

    try detect_suite.runAll(&detect_params, data);
}
