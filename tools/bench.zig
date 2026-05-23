const std = @import("std");
const zbench = @import("zbench");
const zsts = @import("zsts");

/// 测试数据大小
const DataSize = enum(usize) {
    _1k = 1_000,
    _10k = 10_000,
    _100k = 100_000,
    _1m = 1_000_000,

    fn label(self: DataSize) []const u8 {
        return switch (self) {
            ._1k => "1,000",
            ._10k => "10,000",
            ._100k => "100,000",
            ._1m => "1,000,000",
        };
    }
};

/// 生成测试数据
fn generateTestData(allocator: std.mem.Allocator, size: usize, seed: u64) ![]u8 {
    var rnd = std.Random.DefaultPrng.init(seed);
    var random = rnd.random();
    var data = try allocator.alloc(u8, size);
    for (0..size) |i| {
        data[i] = if (random.boolean()) '1' else '0';
    }
    return data;
}

/// 运行检测并清理结果内存
fn runDetectAndClean(allocator: std.mem.Allocator, data: []const u8, detect_type: zsts.detect.DetectType, detect_fn: anytype, args: anytype) void {
    const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
    defer bits.close();

    const param = zsts.detect.DetectParam{ .type = detect_type, .n = data.len, .extra = null };
    var stat = @call(.auto, detect_fn, .{ allocator, param } ++ args) catch @panic("Failed");
    defer stat.destroy();

    stat.init(&param);
    const result = stat.iterate(&bits);
    // 释放 result 中 extra 字段分配的内存
    result.deinit(allocator);
}

/// 参数化基准测试 - Frequency
const FrequencyBenchmark = struct {
    data: []const u8,
    pub fn run(self: *FrequencyBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Frequency, .n = self.data.len, .extra = null };
        var stat = zsts.frequency.frequencyDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// Runs
const RunsBenchmark = struct {
    data: []const u8,
    pub fn run(self: *RunsBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Runs, .n = self.data.len, .extra = null };
        var stat = zsts.runs.runsDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// BlockFrequency
const BlockFrequencyBenchmark = struct {
    data: []const u8,
    pub fn run(self: *BlockFrequencyBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .BlockFrequency, .n = self.data.len, .extra = null };
        var stat = zsts.block_frequency.blockFrequencyDetectStatDetect(allocator, param, 128) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// Poker
const PokerBenchmark = struct {
    data: []const u8,
    pub fn run(self: *PokerBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Poker, .n = self.data.len, .extra = null };
        var stat = zsts.poker.pokerDetectStatDetect(allocator, param, 4) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// BinaryDerivative
const BinaryDerivativeBenchmark = struct {
    data: []const u8,
    pub fn run(self: *BinaryDerivativeBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .BinaryDerivative, .n = self.data.len, .extra = null };
        var stat = zsts.binaryDerivative.binaryDerivativeDetectStatDetect(allocator, param, 3) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// RunDistribution
const RunDistributionBenchmark = struct {
    data: []const u8,
    pub fn run(self: *RunDistributionBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .RunDistribution, .n = self.data.len, .extra = null };
        var stat = zsts.runDist.runDistributionDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// OverlappingSequency
const OverlappingSequencyBenchmark = struct {
    data: []const u8,
    pub fn run(self: *OverlappingSequencyBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .OverlappingSequency, .n = self.data.len, .extra = null };
        var stat = zsts.overlappingseq.overlappingSequencyDetectStatDetect(allocator, param, 4) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// CumulativeSums
const CumulativeSumsBenchmark = struct {
    data: []const u8,
    pub fn run(self: *CumulativeSumsBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .CumulativeSums, .n = self.data.len, .extra = null };
        var stat = zsts.cumulativeSums.cumulativeSumsDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// Serial
const SerialBenchmark = struct {
    data: []const u8,
    pub fn run(self: *SerialBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Serial, .n = self.data.len, .extra = null };
        var stat = zsts.serial.serialDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// ApproxEntropy
const ApproxEntropyBenchmark = struct {
    data: []const u8,
    pub fn run(self: *ApproxEntropyBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .ApproxEntropy, .n = self.data.len, .extra = null };
        var stat = zsts.approximateEntropy.approxEntropyDetectStatDetect(allocator, param, 2) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// DFT
const DftBenchmark = struct {
    data: []const u8,
    pub fn run(self: *DftBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Dft, .n = self.data.len, .extra = null };
        var stat = zsts.dft.dftDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// LongestRun
const LongestRunBenchmark = struct {
    data: []const u8,
    pub fn run(self: *LongestRunBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .LongestRun, .n = self.data.len, .extra = null };
        var stat = zsts.longestRun.longestRunDetectStatDetect(allocator, param) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

/// Autocorrelation
const AutocorrelationBenchmark = struct {
    data: []const u8,
    pub fn run(self: *AutocorrelationBenchmark, allocator: std.mem.Allocator) void {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, self.data);
        defer bits.close();
        const param = zsts.detect.DetectParam{ .type = .Autocorrelation, .n = self.data.len, .extra = null };
        var stat = zsts.autocorrelation.autocorrelationDetectStatDetect(allocator, param, 8) catch @panic("Failed");
        defer stat.destroy();
        stat.init(&param);
        const result = stat.iterate(&bits);
        result.deinit(allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const stdout: std.Io.File = .stdout();
    var w: std.Io.File.Writer = stdout.writerStreaming(io, &.{});
    const writer: *std.Io.Writer = &w.interface;

    // 获取系统信息
    const sysinfo = try zbench.getSystemInfo();

    // 打印标题
    try writer.print("\n", .{});
    try writer.print("  ╔══════════════════════════════════════════════════════════════╗\n", .{});
    try writer.print("  ║         zbench - ZSTS Statistical Tests Benchmark           ║\n", .{});
    try writer.print("  ╚══════════════════════════════════════════════════════════════╝\n", .{});
    try writer.print("\n", .{});

    // 打印系统信息
    try writer.print("  System Info:\n", .{});
    try writer.print("    OS:   {s}\n", .{sysinfo.platform});
    try writer.print("    CPU:  {s}\n", .{sysinfo.cpu});
    try writer.print("    Cores: {d}\n", .{sysinfo.cpu_cores});
    try writer.print("    Memory: {Bi:.3}\n", .{sysinfo.memory_total});
    try writer.print("\n", .{});

    // 测试数据大小
    const data_sizes = [_]DataSize{ ._1k, ._10k, ._100k, ._1m };

    // 对每个数据大小运行基准测试
    for (data_sizes) |data_size| {
        const size = @intFromEnum(data_size);
        try writer.print("  -─ Data Size: {s} bits ", .{data_size.label()});
        try writer.print("────────────────────────────────-\n", .{});

        // 生成测试数据
        const test_data = try generateTestData(allocator, size, 42);
        defer allocator.free(test_data);

        // 为每个检测类型创建基准测试
        var bench = zbench.Benchmark.init(allocator, .{});
        defer bench.deinit();

        // 添加各个基准测试
        {
            const b = FrequencyBenchmark{ .data = test_data };
            try bench.addParam("Frequency", &b, .{});
        }
        {
            const b = RunsBenchmark{ .data = test_data };
            try bench.addParam("Runs", &b, .{});
        }
        {
            const b = BlockFrequencyBenchmark{ .data = test_data };
            try bench.addParam("BlockFrequency", &b, .{});
        }
        {
            const b = PokerBenchmark{ .data = test_data };
            try bench.addParam("Poker", &b, .{});
        }
        {
            const b = BinaryDerivativeBenchmark{ .data = test_data };
            try bench.addParam("BinaryDerivative", &b, .{});
        }
        {
            const b = RunDistributionBenchmark{ .data = test_data };
            try bench.addParam("RunDistribution", &b, .{});
        }
        {
            const b = OverlappingSequencyBenchmark{ .data = test_data };
            try bench.addParam("OverlappingSequency", &b, .{});
        }
        {
            const b = CumulativeSumsBenchmark{ .data = test_data };
            try bench.addParam("CumulativeSums", &b, .{});
        }
        {
            const b = SerialBenchmark{ .data = test_data };
            try bench.addParam("Serial", &b, .{});
        }
        {
            const b = ApproxEntropyBenchmark{ .data = test_data };
            try bench.addParam("ApproxEntropy", &b, .{});
        }
        {
            const b = DftBenchmark{ .data = test_data };
            try bench.addParam("DFT", &b, .{});
        }
        {
            const b = LongestRunBenchmark{ .data = test_data };
            try bench.addParam("LongestRun", &b, .{});
        }
        {
            const b = AutocorrelationBenchmark{ .data = test_data };
            try bench.addParam("Autocorrelation", &b, .{});
        }

        // 运行基准测试
        try bench.run(io, stdout);
        try writer.print("\n", .{});
    }

    try writer.print("\n", .{});
    try writer.print("  ✅ Benchmark completed!\n", .{});
    try writer.print("\n", .{});
}
