// 兼容层
// 允许代码在 Zig 0.14 和 0.15 之间无缝工作

const std = @import("std");
const builtin = @import("builtin");

/// 编译时检测是否为 Zig 0.15 或更新版本
pub const is_zig_015 = blk: {
    // Zig 版本号结构: major.minor.patch
    const version = builtin.zig_version;

    // 0.15.0 或更新版本
    break :blk (version.major == 0 and version.minor >= 15);
};

// 获取标准输入
pub fn getStdIn() std.fs.File {
    return if (is_zig_015)
        std.fs.File.stdin()
    else
        std.io.getStdIn();
}

// 获取标准输出
pub fn getStdOut() std.fs.File {
    return if (is_zig_015)
        std.fs.File.stdout()
    else
        std.io.getStdOut();
}

// 获取标准错误
pub fn getStdErr() std.fs.File {
    return if (is_zig_015)
        std.fs.File.stderr()
    else
        std.io.getStdErr();
}

// 根据 Zig 版本选择正确的 ArrayList 实现
pub fn ArrayList(comptime T: type) type {
    return if (is_zig_015)
        // Zig 0.15+ 的实现
        struct {
            inner: std.ArrayList(T),
            allocator: std.mem.Allocator,

            pub const Self = @This();

            pub fn init(allocator: std.mem.Allocator) Self {
                return .{
                    .inner = .empty,
                    .allocator = allocator
                };
            }

            pub fn initCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !Self {
                return .{
                    .inner = try std.ArrayList(T).initCapacity(allocator, initial_capacity),
                    .allocator = allocator
                };
            }

            pub fn deinit(self: *Self) void {
                self.inner.deinit(self.allocator);
            }

            pub fn items(self: *const Self) []T {
                return self.inner.items;
            }

            pub fn capacity(self: *const Self) usize {
                return self.inner.capacity;
            }

            pub fn clearAndFree(self: *Self) void {
                self.inner.clearAndFree();
            }

            pub fn clearRetainingCapacity(self: *Self) void {
                self.inner.clearRetainingCapacity();
            }

            pub fn append(self: *Self, item: T) !void {
                try self.inner.append(self.allocator, item);
            }

            pub fn appendSlice(self: *Self, slice: []const T) !void {
                try self.inner.appendSlice(self.allocator, slice);
            }

            pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) !void {
                try self.inner.ensureTotalCapacity(new_capacity);
            }

            pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) !void {
                try self.inner.ensureUnusedCapacity(additional_count);
            }

            pub fn expandToCapacity(self: *Self) void {
                self.inner.expandToCapacity();
            }

            pub fn addOne(self: *Self) !*T {
                return try self.inner.addOne();
            }

            pub fn addManyAsArray(self: *Self, count: usize) !*[count]T {
                return try self.inner.addManyAsArray(count);
            }

            pub fn insert(self: *Self, index: usize, item: T) !void {
                try self.inner.insert(index, item);
            }

            pub fn insertSlice(self: *Self, index: usize, slice: []const T) !void {
                try self.inner.insertSlice(index, slice);
            }

            pub fn replaceRange(self: *Self, start: usize, len: usize, new_items: []const T) !void {
                try self.inner.replaceRange(start, len, new_items);
            }

            pub fn orderedRemove(self: *Self, index: usize) T {
                return self.inner.orderedRemove(index);
            }

            pub fn swapRemove(self: *Self, index: usize) T {
                return self.inner.swapRemove(index);
            }

            pub fn pop(self: *Self) ?T {
                return self.inner.pop();
            }

            pub fn popOrNull(self: *Self) ?T {
                return self.inner.popOrNull();
            }

            pub fn toOwnedSlice(self: *Self) []T {
                return self.inner.toOwnedSlice(self.allocator) catch unreachable;
            }

            pub fn toOwnedSliceSentinel(self: *Self, comptime sentinel: T) ![:sentinel]T {
                return try self.inner.toOwnedSliceSentinel(sentinel);
            }
        }
    else
        // Zig 0.14 的实现
        struct {
            inner: std.ArrayList(T),

            pub const Self = @This();

            pub fn init(allocator: std.mem.Allocator) Self {
                return .{ .inner = std.ArrayList(T).init(allocator) };
            }

            pub fn initCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !Self {
                var list = std.ArrayList(T).init(allocator);
                try list.ensureTotalCapacity(initial_capacity);
                return .{ .inner = list };
            }

            pub fn deinit(self: *Self) void {
                self.inner.deinit();
            }

            pub fn items(self: *const Self) []T {
                return self.inner.items;
            }

            pub fn capacity(self: *const Self) usize {
                return self.inner.capacity;
            }

            pub fn clearAndFree(self: *Self) void {
                self.inner.clearAndFree();
            }

            pub fn clearRetainingCapacity(self: *Self) void {
                self.inner.clearRetainingCapacity();
            }

            pub fn append(self: *Self, item: T) !void {
                try self.inner.append(item);
            }

            pub fn appendSlice(self: *Self, slice: []const T) !void {
                try self.inner.appendSlice(slice);
            }

            pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) !void {
                try self.inner.ensureTotalCapacity(new_capacity);
            }

            pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) !void {
                try self.inner.ensureUnusedCapacity(additional_count);
            }

            pub fn expandToCapacity(self: *Self) void {
                self.inner.expandToCapacity();
            }

            pub fn addOne(self: *Self) !*T {
                return try self.inner.addOne();
            }

            pub fn addManyAsArray(self: *Self, count: usize) !*[count]T {
                return try self.inner.addManyAsArray(count);
            }

            pub fn insert(self: *Self, index: usize, item: T) !void {
                try self.inner.insert(index, item);
            }

            pub fn insertSlice(self: *Self, index: usize, slice: []const T) !void {
                try self.inner.insertSlice(index, slice);
            }

            pub fn replaceRange(self: *Self, start: usize, len: usize, new_items: []const T) !void {
                try self.inner.replaceRange(start, len, new_items);
            }

            pub fn orderedRemove(self: *Self, index: usize) T {
                return self.inner.orderedRemove(index);
            }

            pub fn swapRemove(self: *Self, index: usize) T {
                return self.inner.swapRemove(index);
            }

            pub fn pop(self: *Self) ?T {
                return self.inner.pop();
            }

            pub fn popOrNull(self: *Self) ?T {
                return self.inner.popOrNull();
            }

            pub fn toOwnedSlice(self: *Self) []T {
                return self.inner.toOwnedSlice() catch unreachable;
            }

            pub fn toOwnedSliceSentinel(self: *Self, comptime sentinel: T) ![:sentinel]T {
                return try self.inner.toOwnedSliceSentinel(sentinel);
            }
        };
}
