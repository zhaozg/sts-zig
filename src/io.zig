const std = @import("std");

pub const InputStream = struct {
    const Self = @This();

    /// 函数指针表（类似虚函数表）
    vtable: *const VTable,
    context: *anyopaque,

    const VTable = struct {
        reset: *const fn (context: *anyopaque) void,
        read: *const fn (context: *anyopaque, buffer: []u8) usize,
        hasMore: *const fn (context: *anyopaque) bool,
        close: *const fn (context: *anyopaque) void,
    };

    /// 读取最多 buffer.len 字节的数据
    pub fn read(self: Self, buffer: []u8) usize {
        return self.vtable.read(self.context, buffer);
    }

    /// 是否还有更多数据
    pub fn hasMore(self: Self) bool {
        return self.vtable.hasMore(self.context);
    }

    pub fn reset(self: Self) void {
        return self.vtable.reset(self.context);
    }

    pub fn readAll(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try allocator.alloc(u8, 1024);
        var total_read: usize = 0;

        while (self.hasMore()) {
            if (total_read == buffer.len) {
                buffer = try allocator.realloc(buffer, buffer.len * 2);
            }
            const n = self.read(buffer[total_read..]);
            if (n == 0) break;
            total_read += n;
        }
        return buffer[0..total_read];
    }

    /// 关闭流（释放资源）
    pub fn close(self: Self) void {
        self.vtable.close(self.context);
    }
};

const FileStream = struct {
    file: std.fs.File,
};

fn fileRead(context: *anyopaque, buffer: []u8) usize {
    const self: *FileStream = @alignCast(context);
    return self.file.read(buffer) catch 0;
}

fn fileHasMore(context: *anyopaque) bool {
    const self: *FileStream = @alignCast(context);
    const pos = self.file.getPos() catch return false;
    const end = self.file.getEndPos() catch return true;
    return pos < end;
}

fn fileClose(context: *anyopaque) void {
    const self: *FileStream = @alignCast(context);
    self.file.close();
    std.heap.c_allocator.destroy(self);
}

/// 获取文件输入流
pub fn createFileStream(file: std.fs.File) InputStream {
    const stream = std.heap.c_allocator.create(FileStream) catch unreachable;
    stream.* = FileStream{ .file = file };
    return InputStream{
        .vtable = &FileStreamVTable,
        .context = stream,
    };
}

const FileStreamVTable = InputStream.VTable{
    .read = fileRead,
    .hasMore = fileHasMore,
    .close = fileClose,
};

const MemoryStream = struct {
    data: []const u8,
    index: usize,
};

fn memoryRead(context: *anyopaque, buffer: []u8) usize {
    const self: *MemoryStream = @alignCast(@ptrCast(context));
    const remaining = self.data[self.index..];
    const to_copy = @min(buffer.len, remaining.len);
    std.mem.copyForwards(u8, buffer[0..to_copy], remaining[0..to_copy]);

    self.index += to_copy;
    return to_copy;
}

fn memoryReset(context: *anyopaque) void {
    const self: *MemoryStream = @alignCast(@ptrCast(context));
    self.index = 0;
}

fn memoryHasMore(context: *anyopaque) bool {
    const self: *MemoryStream = @alignCast(@ptrCast(context));
    return self.index < self.data.len;
}

fn memoryClose(context: *anyopaque) void {
    // 不需要做任何事
    _ = context;
}

/// 获取内存输入流
pub fn createMemoryStream(data: []const u8) InputStream {
    const stream = std.heap.c_allocator.create(MemoryStream) catch unreachable;
    stream.* = MemoryStream{
        .data = data,
        .index = 0,
    };
    return InputStream{
        .vtable = &MemoryStreamVTable,
        .context = stream,
    };
}

const MemoryStreamVTable = InputStream.VTable{
    .read = memoryRead,
    .reset = memoryReset,
    .hasMore = memoryHasMore,
    .close = memoryClose,
};

/// 1. 定义 BitStream 结构体，持有数据切片和当前 bit 索引。
/// 2. 提供 pub fn init(data: []const u8) BitStream 初始化方法。
/// 3. 实现 pub fn fetchBit(self: *BitStream) ?u1，返回下一个 bit（高位优先），并推进索引。
/// 4. 可选：实现 fetchBits(self: *BitStream, n: u8) ?uN，批量取 n 个 bit。
pub const BitStream = struct {
    data: []const u8,
    bit_index: usize, // 全局 bit 索引
    len: usize,

    pub fn init(data: []const u8) BitStream {
        return BitStream{
            .data = data,
            .bit_index = 0,
            .len = data.len * 8, // 计算总 bit 数
        };
    }

    pub fn reset(self: *BitStream) void {
        self.bit_index = 0;
    }

    pub fn setLength(self: *BitStream, length: usize) void {
        if (length > self.data.len * 8) {
            std.debug.panic("Length exceeds data size");
        }
        self.len = length;
    }

    pub fn fetchBit(self: *BitStream) ?u1 {
        if (self.bit_index >= self.len) return null;

        const byte_index = self.bit_index / 8;
        const bit_in_byte: u3 = @intCast(7 - (self.bit_index % 8)); // 高位优先
        const bit = (self.data[byte_index] >> bit_in_byte) & 0x1;
        self.bit_index += 1;
        return @intCast(bit);
    }

    pub fn get(self: *BitStream, idx: usize) ?u1 {
        if (idx >= self.len) return null;

        const byte_index = idx / 8;
        const bit_in_byte: u3 = @intCast(7 - (idx % 8)); // 高位优先
        return @intCast((self.data[byte_index] >> bit_in_byte) & 0x1);
    }

    pub fn fetchBits(self: *BitStream, n: u8) ?u64 {
        if (n > 64) return null;
        var value: u64 = 0;
        var i: u8 = 0;
        while (i < n) : (i += 1) {
            const bit = self.fetchBit() orelse return null;
            value = (value << 1) | bit;
        }
        return value;
    }
};

pub fn convertAscii2Byte(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var byte_array = try allocator.alloc(u8, (data.len + 7) / 8);
    var byte_index: usize = 0;
    var bit_index: u8 = 0;

    for(byte_array) |*byte| {
        byte.* = 0; // 初始化为 0
    }

    for (data) |bit| {
        if (bit == '1') {
            byte_array[byte_index] |= (@as(u8, 1) << @as(u3, (7 - @as(u3, @truncate(bit_index)))));
        } else if (bit != '0') {
            return error.InvalidCharacter; // 只允许 '0' 和 '1'
        }
        bit_index += 1;
        if (bit_index == 8) {
            byte_index += 1;
            bit_index = 0;
        }
    }

    return byte_array;
}

