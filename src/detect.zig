const std = @import("std");
const io = @import("io.zig");

pub const DetectType = enum {
    General,

    Frequency,
    BlockFrequency,
    Poker,
    OverlappingSequency,
    Runs,
    RunDistribution,
    LongestRun,
    BinaryDerivative,
    AutoCorrelation,
    Autocorrelation,  // Alias for AutoCorrelation 
    Rank,
    CumulativeSums,
    ApproxEntropy,
    LinearComplexity,
    MaurerUniversal,
    Universal,  // Alias for MaurerUniversal
    Dft,

    NonOverlappingTemplate,
    OverlappingTemplate,
    Serial,
    RandomExcursions,
    RandomExcursionsVariant,
};

pub const DetectParam = struct {
    type: DetectType,  // 检测类型
    n: usize,   // 比特数目

    // 可扩展更多参数
    extra: ?*anyopaque, // 支持算法特有参数
};

pub const DetectResult = struct {
    passed: bool,

    v_value: f64,
    p_value: f64,
    q_value: f64,

    errno: ?anyerror,

    extra: ?*anyopaque, // 支持扩展字段
};

pub fn detectReset(self: *StatDetect) void {
    _ = self;
}

pub const PrintLevel = enum {
    summary,
    detail,
};

pub fn detectPrint(self: *StatDetect, result: *const DetectResult, level: PrintLevel) void {
    _ = level;
    std.debug.print("Test {s:>24}: passed={s}, V={d:>14.6} P={d:<10.6} Q={d:<10.6}\n",
    .{
        self.name,
        if(result.passed) "Yes" else "No ",
        result.v_value,
        result.p_value,
        result.q_value,
    });
}

pub const StatDetect = struct {
    name: []const u8,
    param: *DetectParam,
    allocator: std.mem.Allocator,

    state: ?*anyopaque = null, // 可选内部状态

    _init: *const fn (self: *StatDetect, param: *const DetectParam) void,
    _iterate: *const fn (self: *StatDetect, bitStream: *const io.BitInputStream) DetectResult,
    _destroy: *const fn (self: *StatDetect) void,

    _reset: ?*const fn (self: *StatDetect) void = detectReset,
    _print: ?*const fn (self: *StatDetect, result: *const DetectResult, level: PrintLevel) void = detectPrint,

    pub fn init(self: *StatDetect, param: *const DetectParam) void {
        self._init(self, param);
    }
    pub fn iterate(self: *StatDetect, bitStream: *const io.BitInputStream) DetectResult {
        return self._iterate(self, bitStream);
    }
    pub fn destroy(self: *StatDetect) void {
        self._destroy(self);
    }

    pub fn print(self: *StatDetect, result: *const DetectResult, level: PrintLevel) void {
        self._print.?(self, result, level);
    }

    pub fn reset(self: *StatDetect) void {
        self._reset.?(self);
    }
};

