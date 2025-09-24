const std = @import("std");
const print = std.debug.print;

/// Types of test data that can be generated
const DataType = enum {
    random,
    alternating,
    constant_zero,
    constant_one,
    periodic,
    linear_congruential,
    mersenne_twister,
    fibonacci_lfsr,
    custom_pattern,
};

/// Configuration for data generation
const GeneratorConfig = struct {
    data_type: DataType,
    size: usize,
    seed: u64,
    period: ?usize = null, // For periodic patterns
    pattern: ?[]const u8 = null, // For custom patterns
    
    pub fn init(data_type: DataType, size: usize, seed: u64) GeneratorConfig {
        return GeneratorConfig{
            .data_type = data_type,
            .size = size,
            .seed = seed,
        };
    }
};

/// Generate test data based on configuration
pub fn generateData(allocator: std.mem.Allocator, config: GeneratorConfig) ![]u8 {
    const data = try allocator.alloc(u8, config.size);
    
    switch (config.data_type) {
        .random => try generateRandomData(data, config.seed),
        .alternating => generateAlternatingData(data),
        .constant_zero => generateConstantData(data, 0),
        .constant_one => generateConstantData(data, 1),
        .periodic => try generatePeriodicData(data, config.period orelse 16),
        .linear_congruential => try generateLCGData(data, config.seed),
        .mersenne_twister => try generateMTData(data, config.seed),
        .fibonacci_lfsr => try generateLFSRData(data, config.seed),
        .custom_pattern => try generateCustomPatternData(data, config.pattern orelse "10110100"),
    }
    
    return data;
}

/// Generate cryptographically strong random data
fn generateRandomData(data: []u8, seed: u64) !void {
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();
    
    for (data) |*byte| {
        byte.* = random.int(u8) & 1; // Generate 0 or 1
    }
}

/// Generate alternating bit pattern (01010101...)
fn generateAlternatingData(data: []u8) void {
    for (data, 0..) |*byte, i| {
        byte.* = @as(u8, @intCast(i % 2));
    }
}

/// Generate constant data (all 0s or all 1s)
fn generateConstantData(data: []u8, value: u8) void {
    for (data) |*byte| {
        byte.* = value;
    }
}

/// Generate periodic pattern
fn generatePeriodicData(data: []u8, period: usize) !void {
    if (period == 0) return error.InvalidPeriod;
    
    var prng = std.Random.DefaultPrng.init(12345);
    const random = prng.random();
    
    // Generate one period of random data
    var pattern = std.ArrayList(u8).init(std.heap.page_allocator);
    defer pattern.deinit();
    
    for (0..period) |_| {
        try pattern.append(random.int(u8) & 1);
    }
    
    // Repeat the pattern
    for (data, 0..) |*byte, i| {
        byte.* = pattern.items[i % period];
    }
}

/// Generate data using Linear Congruential Generator
fn generateLCGData(data: []u8, seed: u64) !void {
    var state = seed;
    const a: u64 = 1664525;
    const c: u64 = 1013904223;
    const m: u64 = 1 << 32;
    
    for (data) |*byte| {
        state = (a * state + c) % m;
        byte.* = @as(u8, @intCast(state & 1));
    }
}

/// Generate data using Mersenne Twister
fn generateMTData(data: []u8, seed: u64) !void {
    var mt = std.Random.Xoshiro256.init(seed);
    
    for (data) |*byte| {
        byte.* = @as(u8, @intCast(mt.next() & 1));
    }
}

/// Generate data using Linear Feedback Shift Register
fn generateLFSRData(data: []u8, seed: u64) !void {
    var lfsr = seed;
    if (lfsr == 0) lfsr = 1; // LFSR cannot be zero
    
    // Polynomial: x^16 + x^14 + x^13 + x^11 + 1
    const taps: u64 = 0x8016;
    
    for (data) |*byte| {
        const bit = lfsr & 1;
        lfsr >>= 1;
        if (bit != 0) {
            lfsr ^= taps;
        }
        byte.* = @as(u8, @intCast(bit));
    }
}

/// Generate data using custom pattern
fn generateCustomPatternData(data: []u8, pattern: []const u8) !void {
    if (pattern.len == 0) return error.EmptyPattern;
    
    for (data, 0..) |*byte, i| {
        const pattern_char = pattern[i % pattern.len];
        byte.* = if (pattern_char == '1') 1 else 0;
    }
}

/// Save data to file in specified format
pub fn saveDataToFile(allocator: std.mem.Allocator, data: []const u8, filename: []const u8, format: enum { binary, ascii, hex }) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    
    switch (format) {
        .binary => {
            // Pack bits into bytes
            var packed_data = std.ArrayList(u8).init(allocator);
            defer packed_data.deinit();
            
            var byte: u8 = 0;
            for (data, 0..) |bit, i| {
                byte = (byte << 1) | bit;
                if ((i + 1) % 8 == 0 or i == data.len - 1) {
                    try packed_data.append(byte);
                    byte = 0;
                }
            }
            
            try file.writeAll(packed_data.items);
        },
        .ascii => {
            for (data) |bit| {
                try file.writer().print("{c}", .{'0' + bit});
            }
        },
        .hex => {
            for (data, 0..) |_, i| {
                if (i % 4 == 0 and i > 0) {
                    var hex_val: u8 = 0;
                    for (0..4) |j| {
                        if (i - 4 + j < data.len) {
                            hex_val = (hex_val << 1) | data[i - 4 + j];
                        }
                    }
                    try file.writer().print("{x}", .{hex_val});
                }
            }
        },
    }
}

/// Generate comprehensive test data suite
pub fn generateTestSuite(allocator: std.mem.Allocator, output_dir: []const u8) !void {
    const test_configs = [_]struct { 
        name: []const u8, 
        config: GeneratorConfig,
    }{
        .{ .name = "random_10k", .config = GeneratorConfig.init(.random, 10000, 12345) },
        .{ .name = "random_100k", .config = GeneratorConfig.init(.random, 100000, 67890) },
        .{ .name = "alternating_10k", .config = GeneratorConfig.init(.alternating, 10000, 0) },
        .{ .name = "constant_zero_5k", .config = GeneratorConfig.init(.constant_zero, 5000, 0) },
        .{ .name = "constant_one_5k", .config = GeneratorConfig.init(.constant_one, 5000, 0) },
        .{ .name = "periodic_pattern", .config = GeneratorConfig{ .data_type = .periodic, .size = 20000, .seed = 0, .period = 16 } },
        .{ .name = "lcg_generated", .config = GeneratorConfig.init(.linear_congruential, 50000, 98765) },
        .{ .name = "mt_generated", .config = GeneratorConfig.init(.mersenne_twister, 50000, 54321) },
        .{ .name = "lfsr_generated", .config = GeneratorConfig.init(.fibonacci_lfsr, 30000, 13579) },
        .{ .name = "custom_pattern", .config = GeneratorConfig{ .data_type = .custom_pattern, .size = 15000, .seed = 0, .pattern = "110100101" } },
    };
    
    // Create output directory
    std.fs.cwd().makeDir(output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    
    for (test_configs) |test_config| {
        const data = try generateData(allocator, test_config.config);
        defer allocator.free(data);
        
        // Save in ASCII format for readability
        var filename_buffer: [256]u8 = undefined;
        const filename = try std.fmt.bufPrint(&filename_buffer, "{s}/{s}.txt", .{ output_dir, test_config.name });
        
        try saveDataToFile(allocator, data, filename, .ascii);
        print("Generated: {s} ({} bits)\n", .{ filename, data.len });
    }
    
    print("Test data suite generated successfully in '{s}' directory\n", .{output_dir});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len < 2) {
        print("Usage: {s} <command> [options]\n", .{args[0]});
        print("\nCommands:\n", .{});
        print("  suite <output_dir>     - Generate comprehensive test data suite\n", .{});
        print("  random <size> <seed>   - Generate random data\n", .{});
        print("  pattern <size> <pattern> - Generate pattern-based data\n", .{});
        print("  help                   - Show this help message\n", .{});
        return;
    }
    
    const command = args[1];
    
    if (std.mem.eql(u8, command, "suite")) {
        const output_dir = if (args.len > 2) args[2] else "test_data";
        try generateTestSuite(allocator, output_dir);
    } else if (std.mem.eql(u8, command, "random")) {
        if (args.len < 4) {
            print("Usage: random <size> <seed>\n", .{});
            return;
        }
        
        const size = try std.fmt.parseInt(usize, args[2], 10);
        const seed = try std.fmt.parseInt(u64, args[3], 10);
        
        const config = GeneratorConfig.init(.random, size, seed);
        const data = try generateData(allocator, config);
        defer allocator.free(data);
        
        try saveDataToFile(allocator, data, "random_data.txt", .ascii);
        print("Generated {} bits of random data in 'random_data.txt'\n", .{size});
        
    } else if (std.mem.eql(u8, command, "help")) {
        print("STS-Zig Test Data Generator\n", .{});
        print("============================\n", .{});
        print("Generate various types of test data for statistical analysis.\n\n", .{});
        print("Available data types:\n", .{});
        print("- random: Cryptographically strong random data\n", .{});
        print("- alternating: Alternating bit pattern (010101...)\n", .{});
        print("- constant: All zeros or all ones\n", .{});
        print("- periodic: Repeating patterns\n", .{});
        print("- lcg: Linear Congruential Generator\n", .{});
        print("- mt: Mersenne Twister\n", .{});
        print("- lfsr: Linear Feedback Shift Register\n", .{});
        print("- pattern: Custom bit patterns\n", .{});
    } else {
        print("Unknown command: {s}\n", .{command});
        print("Use 'help' for available commands.\n", .{});
    }
}

test "data generator: basic functionality" {
    const allocator = std.testing.allocator;
    
    // Test random data generation
    const config = GeneratorConfig.init(.random, 100, 12345);
    const data = try generateData(allocator, config);
    defer allocator.free(data);
    
    try std.testing.expect(data.len == 100);
    
    // Verify all values are 0 or 1
    for (data) |bit| {
        try std.testing.expect(bit == 0 or bit == 1);
    }
}

test "data generator: alternating pattern" {
    const allocator = std.testing.allocator;
    
    const config = GeneratorConfig.init(.alternating, 10, 0);
    const data = try generateData(allocator, config);
    defer allocator.free(data);
    
    // Verify alternating pattern
    for (data, 0..) |bit, i| {
        const expected = @as(u8, @intCast(i % 2));
        try std.testing.expect(bit == expected);
    }
}