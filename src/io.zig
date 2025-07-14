const std = @import("std");

pub const InputStream = struct {
    const Self = @This();

    /// Function pointer table (similar to a vtable)
    vtable: *const VTable,
    context: *anyopaque,

    const VTable = struct {
        reset: *const fn (context: *anyopaque) void,
        read: *const fn (context: *anyopaque, buffer: []u8) usize,
        readAt: *const fn (context: *anyopaque, idx: usize, buffer: []u8) usize,
        hasNext: *const fn (context: *anyopaque) bool,
        close: *const fn (context: *anyopaque) void,

        len: *const fn (context: *anyopaque) usize,
        avail: *const fn (context: *anyopaque) usize,
    };

    /// Read up to buffer.len bytes of data
    pub fn read(self: Self, buffer: []u8) usize {
        return self.vtable.read(self.context, buffer);
    }

    /// Read up to buffer.len bytes of data from a specific index
    /// note: This is not supported by all streams
    /// note: Note update the stream position
    pub fn readAt(self: Self, idx: usize, buffer: []u8) usize {
        return self.vtable.readAt(self.context, idx, buffer);
    }

    /// Check if more data is available
    pub fn hasNext(self: Self) bool {
        return self.vtable.hasNext(self.context);
    }

    /// Reset the stream to its initial position
    pub fn reset(self: Self) void {
        return self.vtable.reset(self.context);
    }

    /// Tell data length
    pub fn len(self: Self) usize {
        return self.vtable.len(self.context);
    }

    /// Tell available data length
    pub fn avail(self: Self) usize {
        return self.vtable.avail(self.context);
    }

    /// Read all available data from the stream
    pub fn readAll(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try allocator.alloc(u8, self.avail());
        var total_read: usize = 0;

        while (self.hasNext()) {
            const n = self.read(buffer[total_read..]);
            if (n == 0) break;
            total_read += n;
        }

        return buffer[0..total_read];
    }

    /// Close the stream and release resources
    pub fn close(self: Self) void {
        self.vtable.close(self.context);
    }

    /// Create an InputStream from a file
    pub fn fromFile(file: std.fs.File) InputStream {
        return createFileStream(file);
    }

    /// Create an InputStream from memory
    pub fn fromMemory(data: []const u8) InputStream {
        return createMemoryStream(data);
    }

    /// Create an InputStream from a fixed-size array
    pub fn fromArray(comptime T: type, data: []const T, length: usize) InputStream {
        return createMemoryStream(std.mem.sliceAsBytes(data[0..length]));
    }

    /// Create an InputStream from a null-terminated string
    pub fn fromCString(str: [*:0]const u8) InputStream {
        const length = std.mem.len(str);
        return createMemoryStream(str[0..length]);
    }
};

// ===== Concrete InputStream Implementations =====

const FileStream = struct {
    file: std.fs.File,
    pos: usize = 0,
    end_pos: ?usize = null,

    fn read(context: *anyopaque, buffer: []u8) usize {
        const self: *FileStream = @ptrCast(@alignCast(context));
        const n = self.file.read(buffer) catch return 0;
        self.pos += n;
        return n;
    }

    fn readAt(context: *anyopaque, idx: usize, buffer: []u8) usize {
        const self: *FileStream = @ptrCast(@alignCast(context));
        self.file.seekTo(idx) catch return 0;
        const n = self.file.read(buffer) catch return 0;
        self.file.seekTo(self.pos) catch {};
        return n;
    }

    fn hasNext(context: *anyopaque) bool {
        const self: *FileStream = @ptrCast(@alignCast(context));
        if (self.end_pos == null) {
            self.end_pos = self.file.getEndPos() catch return false;
        }
        return self.pos < self.end_pos.?;
    }

    fn len(context: *anyopaque) usize {
        const self: *FileStream = @ptrCast(@alignCast(context));
        if (self.end_pos == null) {
            self.end_pos = self.file.getEndPos() catch return 0;
        }
        return self.end_pos.?;
    }

    fn avail(context: *anyopaque) usize {
        const self: *FileStream = @ptrCast(@alignCast(context));
        if (self.end_pos == null) {
            self.end_pos = self.file.getEndPos() catch return 0;
        }
        return (self.end_pos.? - self.pos);
    }

    fn reset(context: *anyopaque) void {
        const self: *FileStream = @ptrCast(@alignCast(context));
        _ = self.file.seekTo(0) catch {};
        self.pos = 0;
    }

    fn close(context: *anyopaque) void {
        const self: *FileStream = @ptrCast(@alignCast(context));
        self.end_pos = 0;
        self.pos = 0;
        std.heap.page_allocator.destroy(self);
    }

    const vtable = InputStream.VTable{
        .read = read,
        .readAt = readAt,

        .hasNext = hasNext,
        .len = len,
        .avail = avail,

        .reset = reset,
        .close = close,
    };
};

/// Create a file-based InputStream
pub fn createFileStream(file: std.fs.File) InputStream {
    const stream = std.heap.page_allocator.create(FileStream) catch unreachable;
    stream.* = .{ .file = file };
    return InputStream{
        .vtable = &FileStream.vtable,
        .context = stream,
    };
}

const MemoryStream = struct {
    data: []const u8,
    index: usize = 0,

    fn read(context: *anyopaque, buffer: []u8) usize {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        const remaining = self.data[self.index..];
        const to_copy = @min(buffer.len, remaining.len);
        @memcpy(buffer[0..to_copy], remaining[0..to_copy]);
        self.index += to_copy;
        return to_copy;
    }

    fn readAt(context: *anyopaque, idx: usize, buffer: []u8) usize {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        if (idx >= self.data.len) return 0;

        const remaining = self.data[idx..];
        const to_copy = @min(buffer.len, remaining.len);
        @memcpy(buffer[0..to_copy], remaining[0..to_copy]);
        return to_copy;
    }

    fn hasNext(context: *anyopaque) bool {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        return self.index < self.data.len;
    }

    fn reset(context: *anyopaque) void {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        self.index = 0;
    }

    fn len(context: *anyopaque) usize {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        return self.data.len;
    }

    fn avail(context: *anyopaque) usize {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        return self.data.len - self.index;
    }

    fn close(context: *anyopaque) void {
        const self: *MemoryStream = @ptrCast(@alignCast(context));
        self.index = self.data.len;
        std.heap.page_allocator.destroy(self);
    }

    const vtable = InputStream.VTable{
        .read = read,
        .readAt = readAt,

        .hasNext = hasNext,
        .len = len,
        .avail = avail,

        .reset = reset,
        .close = close,
    };
};

/// Create a memory-based InputStream
pub fn createMemoryStream(data: []const u8) InputStream {
    const stream = std.heap.page_allocator.create(MemoryStream) catch unreachable;
    stream.* = .{ .data = data };
    return InputStream{
        .vtable = &MemoryStream.vtable,
        .context = stream,
    };
}

// ===== BitInputStream =====

pub const BitInputStream = struct {
    const Self = @This();

    vtable: *const VTable,
    context: *anyopaque,

    pub const VTable = struct {
        fetchBit: *const fn (ctx: *anyopaque) ?u1,
        fetchBits: ?*const fn (ctx: *anyopaque, bits: []u1) usize = null,
        len: *const fn (ctx: *anyopaque) usize,
        reset: *const fn (ctx: *anyopaque) void,
        close: *const fn (ctx: *anyopaque) void,
    };

    /// Fetch a single bit
    pub fn fetchBit(self: Self) ?u1 {
        return self.vtable.fetchBit(self.context);
    }

    /// Fetch multiple bits as a slice of individual bits
    pub fn fetchBits(self: Self, bits: []u1) usize {
        if (self.vtable.fetchBits) |fetchFn| {
            return fetchFn(self.context, bits);
        }

        for(0..bits.len) |i| {
            bits[i] = self.fetchBit() orelse return i;
        }

        return bits.len;
    }

    /// Reset the bit stream to its initial position
    pub fn reset(self: Self) void {
        self.vtable.reset(self.context);
    }

    /// Close the bit stream and release resources
    pub fn close(self: Self) void {
        self.vtable.close(self.context);
    }

    /// Get the total number of bits available in the stream
    pub fn len(self: Self) usize {
        return self.vtable.len(self.context);
    }

    /// Create a BitInputStream from a byte array
    pub fn fromByteInputStream(stream: InputStream) BitInputStream {
        return ByteInputStream.create(stream);
    }

    /// Create a BitInputStream from a byte array with a specified length
    pub fn fromByteInputStreamWithLength(stream: InputStream, length: usize) BitInputStream {
        return ByteInputStream.createWithLength(stream, length);
    }

    /// Create a BitInputStream from a byte array
    pub fn fromAsciiInputStream(stream: InputStream) BitInputStream {
        return AsciiInputStream.create(stream);
    }

    /// Create a BitAsciiInputStream from a byte array with a specified length
    pub fn fromAsciiInputStreamWithLength(stream: InputStream, length: usize) BitInputStream {
        return AsciiInputStream.createWithLength(stream, length);
    }

    /// Create a BitInputStream from an ASCII string
    pub fn fromAscii(data: []const u8) BitInputStream {
        return AsciiBitStream.create(data);
    }

};

// ===== Concrete ByteInputStream Implementations =====

const ByteInputStream = struct {
    stream: InputStream,
    data: [1]u8 = [1]u8{0}**1,
    bit_index: usize,
    len: usize,

    fn fetchBit(ctx: *anyopaque) ?u1 {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        if (self.bit_index >= self.len) return null;

        if (self.bit_index % 8 == 0) {
            if (self.stream.read(&self.data) != 1) return null;
        }

        const bit_in_byte: u3 = @intCast(7 - (self.bit_index % 8));
        const bit = (self.data[0] >> bit_in_byte) & 0x1;
        self.bit_index += 1;
        return @intCast(bit);
    }

    fn fetchBits(ctx: *anyopaque, bits: []u1) usize {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        var N = bits.len;
        if (self.bit_index + bits.len > self.len)
            N = self.len - self.bit_index;

        for (0..N) |i| {
            if (self.bit_index % 8 == 0) {
                if (self.stream.read(&self.data) != 1) return i;
            }

            const bit_in_byte: u3 = @intCast(7 - (self.bit_index % 8));
            bits[i] = @intCast((self.data[0] >> bit_in_byte) & 0x1);

            self.bit_index += 1;
        }

        return N;
    }

    fn lenFn(ctx: *anyopaque) usize {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        return self.len;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        self.stream.reset();
        self.bit_index = 0;
    }

    fn close(ctx: *anyopaque) void {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        self.stream.close();
        std.heap.page_allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .fetchBits = fetchBits,
        .len = lenFn,
        .reset = reset,
        .close = close,
    };

    pub fn create(stream: InputStream) BitInputStream {
        return createWithLength(stream, stream.len() * 8);
    }

    pub fn createWithLength(stream: InputStream, len: usize) BitInputStream {
        const self: *ByteInputStream = std.heap.page_allocator.create(ByteInputStream) catch unreachable;
        self.* = .{
            .stream = stream,
            .bit_index = 0,
            .len = len,
        };
        return .{
            .vtable = &vtable,
            .context = self,
        };
    }
};

// ===== Concrete AsciiInputStream Implementations =====
const Ascii_MAX_BUFFER=4096;

const AsciiInputStream = struct {
    stream: InputStream,
    data: []u8,

    byteslength: usize, // piece bytes from stream
    byte_index: usize,  // index byte in piece data

    bit_index: usize,   // index bit in total
    len: usize,         // length in bits total

    fn fetchBit(ctx: *anyopaque) ?u1 {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));

        if (self.bit_index >= self.len) return null;

        while (true) {
            if (self.byte_index >= self.byteslength) {
                self.byte_index = 0;
                self.byteslength = self.stream.read(self.data);
            }
            if(self.byteslength == 0) return null; // No more data to read
            for (self.byte_index..self.byteslength) |i| {
                const char = self.data[i];
                self.byte_index += 1;

                if (char == '0' or char == '1') {
                    self.bit_index += 1;
                    return if (char == '1') 1 else 0;
                }
            }
        }

        return null;
    }

    fn lenFn(ctx: *anyopaque) usize {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));
        return self.len;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));
        self.stream.reset();
        self.bit_index = 0;
        self.byteslength = 0;
        self.byte_index = 0;
        self.bit_index = 0;
    }

    fn close(ctx: *anyopaque) void {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));
        self.stream.close();
        std.heap.page_allocator.free(self.data);
        std.heap.page_allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .len = lenFn,
        .reset = reset,
        .close = close,
    };

    pub fn create(stream: InputStream) BitInputStream {
        return createWithLength(stream, stream.len() * 8);
    }

    pub fn createWithLength(stream: InputStream, len: usize) BitInputStream {
        const self: *AsciiInputStream = std.heap.page_allocator.create(AsciiInputStream) catch unreachable;
        self.* = .{
            .stream = stream,
            .data = std.heap.page_allocator.alloc(u8, Ascii_MAX_BUFFER) catch unreachable,
            .byteslength = 0,
            .byte_index = 0,
            .bit_index = 0,
            .len = len,
        };
        return .{
            .vtable = &vtable,
            .context = self,
        };
    }
};

const AsciiBitStream = struct {
    data: []const u8,
    index: usize = 0,
    length: usize = 0,
    used: usize = 0,

    fn fetchBit(ctx: *anyopaque) ?u1 {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        while (self.index < self.data.len) {
            const char = self.data[self.index];
            self.index += 1;

            if (char == '0' or char == '1') {
                self.used += 1;
                return if (char == '1') 1 else 0;
            }
            // Skip non-binary characters
        }
        return null;
    }

    fn len(ctx: *anyopaque) usize {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        if (self.length != 0) {
            return self.length;
        }
        var l: usize = 0;
        for (0..self.data.len) |i| {
            const char = self.data[i];
            if (char == '1' or char == '0') {
                l += 1;
            }
        }
        self.length = l;

        return self.length;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        self.index = 0;
    }

    fn close(ctx: *anyopaque) void {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        std.heap.page_allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .len = len,
        .reset = reset,
        .close = close,
    };

    pub fn create(data: []const u8) BitInputStream {
        const self = std.heap.page_allocator.create(AsciiBitStream) catch unreachable;
        self.* = .{
            .data = data,
        };
        return .{
            .vtable = &vtable,
            .context = self,
        };
    }
};

test "MemoryStream basic operations" {
    const data = "Hello, Zig!";
    var stream = createMemoryStream(data);

    // 测试读取
    var buffer: [1024]u8 = undefined;
    const n = stream.read(&buffer);
    try std.testing.expectEqualStrings(data, buffer[0..n]);

    // 测试重置后再次读取
    stream.reset();
    const n2 = stream.read(&buffer);
    try std.testing.expectEqualStrings(data, buffer[0..n2]);

    // 测试 hasNext
    try std.testing.expect(stream.hasNext() == false);
}

test "FileStream basic operations" {
    const file_path = "testfile.txt";
    const content = "FileStream test data";
    try std.fs.cwd().writeFile(.{
        .sub_path =file_path,
        .flags = .{ .truncate = true },
        .data = content,
    });

    // 打开文件流
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    var stream = createFileStream(file);

    // 测试读取
    var buffer: [1024]u8 = undefined;
    const n = stream.read(&buffer);
    try std.testing.expectEqualStrings(content, buffer[0..n]);

    // 测试重置后再次读取
    stream.reset();
    const n2 = stream.read(&buffer);
    try std.testing.expectEqualStrings(content, buffer[0..n2]);

    // 测试 hasNext
    try std.testing.expect(stream.hasNext() == false);
}

test "AsciiBitStream basic operations" {
    const ascii_data = "101001001111";
    var bit_stream = AsciiBitStream.create(ascii_data);

    // 依次读取所有位
    const expected_bits = [_]u1{ 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1 };
    for (expected_bits) |expected_bit| {
        const bit = bit_stream.fetchBit() orelse unreachable;
        try std.testing.expectEqual(expected_bit, bit);
    }

    // 流结束
    try std.testing.expect(bit_stream.fetchBit() == null);

    // 重置后再次读取
    bit_stream.reset();
    for (expected_bits) |expected_bit| {
        const bit = bit_stream.fetchBit() orelse unreachable;
        try std.testing.expectEqual(expected_bit, bit);
    }

    bit_stream.close();
}

test "ByteInputStream from memory stream" {
    const data = [4]u8{ 0b10100000, 0b11110000, 0b00001111, 0b00000000 };
    const input_stream = createMemoryStream(&data);

    // 创建位流
    var bit_stream = ByteInputStream.create(input_stream);

    // 验证按位读取
    const expected_bits = [32]u1{
        // 第一个字节
        1, 0, 1, 0, 0, 0, 0, 0,
        // 第二个字节
        1, 1, 1, 1, 0, 0, 0, 0,
        // 第三个字节
        0, 0, 0, 0, 1, 1, 1, 1,
        // 第四个字节
        0, 0, 0, 0, 0, 0, 0, 0,
    };

    for (expected_bits) |expected_bit| {
        const bit = bit_stream.fetchBit() orelse unreachable;
        try std.testing.expectEqual(expected_bit, bit);
    }

    // 流结束
    try std.testing.expect(bit_stream.fetchBit() == null);

    // 重置后再次读取
    bit_stream.reset();
    for (expected_bits) |expected_bit| {
        const bit = bit_stream.fetchBit() orelse unreachable;
        try std.testing.expectEqual(expected_bit, bit);
    }

    bit_stream.close();
}

test "BitInputStream fetchBits" {
    const data = [2]u8{ 0b10101010, 0b11110000 };
    const input_stream = createMemoryStream(&data);
    const bit_stream = ByteInputStream.create(input_stream);

    // 读取 12 位
    var bits = [_]u1{0} ** 12;
    const count = bit_stream.fetchBits(12, &bits);
    try std.testing.expectEqual(@as(usize, 12), count);

    const expected_bits = [12]u1{
        1, 0, 1, 0, 1, 0, 1, 0,
        1, 1, 1, 1,
    };
    for (0..expected_bits.len) |i| {
        try std.testing.expectEqual(expected_bits[i], bits[i]);
    }

    bit_stream.close();
}
