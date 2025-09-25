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
    pub fn fromFile(allocator: std.mem.Allocator, file: std.fs.File) InputStream {
        return createFileStream(allocator, file);
    }

    /// Create an InputStream from memory
    pub fn fromMemory(allocator: std.mem.Allocator, data: []const u8) InputStream {
        return createMemoryStream(allocator, data);
    }

    /// Create an InputStream from a fixed-size array
    pub fn fromArray(allocator: std.mem.Allocator, comptime T: type, data: []const T, length: usize) InputStream {
        return createMemoryStream(allocator, std.mem.sliceAsBytes(data[0..length]));
    }

    /// Create an InputStream from a null-terminated string
    pub fn fromCString(allocator: std.mem.Allocator, str: [*:0]const u8) InputStream {
        const length = std.mem.len(str);
        return createMemoryStream(allocator, str[0..length]);
    }
};

// ===== Concrete InputStream Implementations =====

const FileStream = struct {
    allocator: std.mem.Allocator,
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
        self.allocator.destroy(self);
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
pub fn createFileStream(allocator: std.mem.Allocator, file: std.fs.File) InputStream {
    const stream = allocator.create(FileStream) catch unreachable;
    stream.* = .{ .allocator = allocator, .file = file };
    return InputStream{
        .vtable = &FileStream.vtable,
        .context = stream,
    };
}

const MemoryStream = struct {
    allocator: std.mem.Allocator,
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
        self.allocator.destroy(self);
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
pub fn createMemoryStream(allocator: std.mem.Allocator, data: []const u8) InputStream {
    const stream = allocator.create(MemoryStream) catch unreachable;
    stream.* = .{ .data = data, .allocator = allocator };
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
        bits: *const fn (ctx: *anyopaque) []u1,
        len: *const fn (ctx: *anyopaque) usize,
        reset: *const fn (ctx: *anyopaque) void,
        close: *const fn (ctx: *anyopaque) void,
    };

    /// Fetch a single bit
    pub fn fetchBit(self: Self) ?u1 {
        return self.vtable.fetchBit(self.context);
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

    /// Get bits as a slice
    pub fn bits(self: Self) []u1 {
        return self.vtable.bits(self.context);
    }

    /// Create a BitInputStream from a byte array
    pub fn fromByteInputStream(allocator: std.mem.Allocator, stream: InputStream) BitInputStream {
        return ByteInputStream.create(allocator, stream);
    }

    /// Create a BitInputStream from a byte array with a specified length
    pub fn fromByteInputStreamWithLength(allocator: std.mem.Allocator, stream: InputStream, length: usize) BitInputStream {
        return ByteInputStream.createWithLength(allocator, stream, length);
    }

    /// Create a BitInputStream from a byte array
    pub fn fromAsciiInputStream(allocator: std.mem.Allocator, stream: InputStream) BitInputStream {
        return AsciiInputStream.create(allocator, stream);
    }

    /// Create a BitAsciiInputStream from a byte array with a specified length
    pub fn fromAsciiInputStreamWithLength(allocator: std.mem.Allocator, stream: InputStream, length: usize) BitInputStream {
        return AsciiInputStream.createWithLength(allocator, stream, length);
    }

    /// Create a BitInputStream from an ASCII string
    pub fn fromAscii(allocator: std.mem.Allocator, data: []const u8) BitInputStream {
        return AsciiBitStream.create(allocator, data);
    }
};

// ===== Concrete ByteInputStream Implementations =====

const ByteInputStream = struct {
    allocator: std.mem.Allocator,
    stream: InputStream,
    data: [1]u8 = [1]u8{0} ** 1,
    bit_index: usize,
    len: usize,
    array: []u1 = &[0]u1{},

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

    fn lenFn(ctx: *anyopaque) usize {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        return self.len;
    }

    fn bitsFn(ctx: *anyopaque) []u1 {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));

        if (self.array.len == 0) {
            self.array = self.allocator.alloc(u1, self.len) catch unreachable;

            self.stream.reset();
            for (0..self.len) |i| {
                if (i % 8 == 0) {
                    if (self.stream.read(&self.data) != 1) return self.array[0..i];
                }

                const bit_in_byte: u3 = @intCast(7 - (i % 8));
                self.array[i] = @intCast((self.data[0] >> bit_in_byte) & 0x1);
            }
            self.stream.reset();
        }

        return self.array;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        self.stream.reset();
        self.bit_index = 0;
    }

    fn close(ctx: *anyopaque) void {
        const self: *ByteInputStream = @ptrCast(@alignCast(ctx));
        if (self.array.len > 0) {
            self.allocator.free(self.array);
        }
        self.stream.close();
        self.allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .len = lenFn,
        .bits = bitsFn,
        .reset = reset,
        .close = close,
    };

    pub fn create(allocator: std.mem.Allocator, stream: InputStream) BitInputStream {
        return createWithLength(allocator, stream, stream.len() * 8);
    }

    pub fn createWithLength(allocator: std.mem.Allocator, stream: InputStream, len: usize) BitInputStream {
        const self: *ByteInputStream = allocator.create(ByteInputStream) catch unreachable;
        self.* = .{
            .stream = stream,
            .allocator = allocator,
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
const Ascii_MAX_BUFFER = 4096;

const AsciiInputStream = struct {
    allocator: std.mem.Allocator,
    stream: InputStream,
    data: []u8,
    array: []u1 = &[0]u1{},

    byteslength: usize, // piece bytes from stream
    byte_index: usize, // index byte in piece data

    bit_index: usize, // index bit in total
    len: usize, // length in bits total

    fn fetchBit(ctx: *anyopaque) ?u1 {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));

        if (self.bit_index >= self.len) return null;

        while (true) {
            if (self.byte_index >= self.byteslength) {
                self.byte_index = 0;
                self.byteslength = self.stream.read(self.data);
            }
            if (self.byteslength == 0) return null; // No more data to read
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

    fn bitsFn(ctx: *anyopaque) []u1 {
        const self: *AsciiInputStream = @ptrCast(@alignCast(ctx));
        if (self.array.len == 0) {
            self.array = self.allocator.alloc(u1, self.len) catch unreachable;

            for (0..self.array.len) |i| {
                self.array[i] = fetchBit(ctx) orelse return self.array[0..i];
            }
        }
        return self.array;
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
        if (self.array.len > 0) {
            self.allocator.free(self.array);
        }
        self.stream.close();
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .len = lenFn,
        .bits = bitsFn,
        .reset = reset,
        .close = close,
    };

    pub fn create(allocator: std.mem.Allocator, stream: InputStream) BitInputStream {
        return createWithLength(allocator, stream, stream.len() * 8);
    }

    pub fn createWithLength(allocator: std.mem.Allocator, stream: InputStream, len: usize) BitInputStream {
        const self: *AsciiInputStream = allocator.create(AsciiInputStream) catch unreachable;
        self.* = .{
            .allocator = allocator,
            .stream = stream,
            .data = allocator.alloc(u8, Ascii_MAX_BUFFER) catch unreachable,
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
    allocator: std.mem.Allocator,
    data: []const u8,
    index: usize = 0,
    length: usize = 0,
    used: usize = 0,
    array: []u1 = &[0]u1{},

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

    fn bitsFn(ctx: *anyopaque) []u1 {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        if (self.array.len == 0) {
            const sz = len(ctx);
            self.array = self.allocator.alloc(u1, sz) catch unreachable;

            for (0..self.array.len) |i| {
                self.array[i] = fetchBit(ctx) orelse return self.array[0..i];
            }
        }
        return self.array;
    }

    fn reset(ctx: *anyopaque) void {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        self.index = 0;
    }

    fn close(ctx: *anyopaque) void {
        const self: *AsciiBitStream = @ptrCast(@alignCast(ctx));
        if (self.array.len > 0) {
            self.allocator.free(self.array);
        }
        self.allocator.destroy(self);
    }

    const vtable = BitInputStream.VTable{
        .fetchBit = fetchBit,
        .len = len,
        .bits = bitsFn,
        .reset = reset,
        .close = close,
    };

    pub fn create(allocator: std.mem.Allocator, data: []const u8) BitInputStream {
        const self = allocator.create(AsciiBitStream) catch unreachable;
        self.* = .{
            .allocator = allocator,
            .data = data,
        };
        return .{
            .vtable = &vtable,
            .context = self,
        };
    }
};

test "MemoryStream basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const data = "Hello, Zig!";
    var stream = createMemoryStream(allocator, data);

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file_path = "testfile.txt";
    const content = "FileStream test data";
    try std.fs.cwd().writeFile(.{
        .sub_path = file_path,
        .flags = .{ .truncate = true },
        .data = content,
    });
    defer std.fs.cwd().deleteFile(file_path) catch {};

    // 打开文件流
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();
    var stream = createFileStream(allocator, file);

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const ascii_data = "101001001111";
    var bit_stream = AsciiBitStream.create(allocator, ascii_data);

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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const data = [4]u8{ 0b10100000, 0b11110000, 0b00001111, 0b00000000 };
    const input_stream = createMemoryStream(allocator, &data);

    // 创建位流
    var bit_stream = ByteInputStream.create(allocator, input_stream);

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

test "BitInputStream bits" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const data = [2]u8{ 0b10101010, 0b11110000 };
    const input_stream = createMemoryStream(allocator, &data);
    const bit_stream = ByteInputStream.create(allocator, input_stream);

    // 读取 12 位
    const bits = bit_stream.bits();

    const expected_bits = [12]u1{
        1, 0, 1, 0, 1, 0, 1, 0,
        1, 1, 1, 1,
    };
    for (0..expected_bits.len) |i| {
        try std.testing.expectEqual(expected_bits[i], bits[i]);
    }

    bit_stream.close();
}

test "InputStream readAt, avail, len, readAll, fromArray, fromCString" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const data = "abcdef";
    var stream = createMemoryStream(allocator, data);

    // readAt
    var buf: [3]u8 = undefined;
    const n = stream.readAt(2, &buf);
    try std.testing.expectEqualStrings("cde", buf[0..n]);

    // avail/len
    try std.testing.expectEqual(@as(usize, 6), stream.len());
    try std.testing.expectEqual(@as(usize, 6), stream.avail());

    // readAll
    stream.reset();
    const all = try stream.readAll(allocator);
    defer allocator.free(all);
    try std.testing.expectEqualStrings(data, all);

    // fromArray
    const arr = [_]u8{ 1, 2, 3, 4, 5 };
    var arr_stream = InputStream.fromArray(allocator, u8, &arr, 5);
    var arr_buf: [5]u8 = undefined;
    const arr_n = arr_stream.read(&arr_buf);
    try std.testing.expectEqual(@as(usize, 5), arr_n);
    try std.testing.expectEqualSlices(u8, arr[0..5], arr_buf[0..arr_n]);

    // fromCString
    const cstr: [*:0]const u8 = "xyz";
    var cstr_stream = InputStream.fromCString(allocator, cstr);
    var cstr_buf: [3]u8 = undefined;
    const cstr_n = cstr_stream.read(&cstr_buf);
    try std.testing.expectEqualStrings("xyz", cstr_buf[0..cstr_n]);
}

test "InputStream edge cases: empty, partial, reset/close" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Empty stream
    var stream = createMemoryStream(allocator, "");
    var buf: [10]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 0), stream.read(&buf));
    try std.testing.expect(stream.hasNext() == false);

    // Partial read
    const data = "12345";
    var stream2 = createMemoryStream(allocator, data);
    var buf2: [2]u8 = undefined;
    const n = stream2.read(&buf2);
    try std.testing.expectEqualStrings("12", buf2[0..n]);
    try std.testing.expect(stream2.hasNext());

    // Multiple reset/close
    stream2.reset();
    stream2.reset();
    stream2.close();
}

test "BitInputStream API: fromByteInputStream, fromByteInputStreamWithLength, fromAsciiInputStream, fromAsciiInputStreamWithLength, fromAscii, bits, len, reset, close" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const data = [2]u8{ 0b11001100, 0b10101010 };
    const byte_stream = createMemoryStream(allocator, &data);

    // fromByteInputStream
    var bis = BitInputStream.fromByteInputStream(allocator, byte_stream);
    try std.testing.expectEqual(@as(usize, 16), bis.len());
    const bits = bis.bits();
    try std.testing.expectEqual(@as(u1, 1), bits[0]);
    try std.testing.expectEqual(@as(u1, 0), bits[7]);
    bis.reset();
    bis.close();

    // fromByteInputStreamWithLength
    var bis2 = BitInputStream.fromByteInputStreamWithLength(allocator, byte_stream, 10);
    try std.testing.expectEqual(@as(usize, 10), bis2.len());
    bis2.close();

    // fromAsciiInputStream
    const ascii_data = "10101";
    const ascii_stream = createMemoryStream(allocator, ascii_data);
    var abis = BitInputStream.fromAsciiInputStream(allocator, ascii_stream);
    try std.testing.expectEqual(@as(usize, 40), abis.len()); // 5 chars * 8 bits
    abis.close();

    // fromAsciiInputStreamWithLength
    const ascii_stream2 = createMemoryStream(allocator, ascii_data);
    var abis2 = BitInputStream.fromAsciiInputStreamWithLength(allocator, ascii_stream2, 5);
    try std.testing.expectEqual(@as(usize, 5), abis2.len());
    abis2.close();

    // fromAscii
    const ascii_bis = BitInputStream.fromAscii(allocator, ascii_data);
    try std.testing.expectEqual(@as(usize, 5), ascii_bis.len());
    ascii_bis.reset();
    ascii_bis.close();
}

test "BitInputStream edge cases: fetchBit null, bits partial, reset/close multiple" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Empty ascii
    var ascii_bis = BitInputStream.fromAscii(allocator, "");
    try std.testing.expect(ascii_bis.fetchBit() == null);
    ascii_bis.reset();
    ascii_bis.close();

    // Partial bits
    const ascii_data = "1a0b1";
    var ascii_bis2 = BitInputStream.fromAscii(allocator, ascii_data);
    const bits = ascii_bis2.bits();
    try std.testing.expectEqual(@as(usize, 3), bits.len);
    ascii_bis2.close();

    // Multiple reset/close
    var ascii_bis3 = BitInputStream.fromAscii(allocator, "101");
    ascii_bis3.reset();
    ascii_bis3.reset();
    ascii_bis3.close();
}
