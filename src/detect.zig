const std = @import("std");
const io = @import("io.zig");

pub const DetectType = enum {
    General,

    ApproxEntropy,
    AutoCorrelation,
    BinaryDerivative,
    BlockFrequency,
    CumulativeSums,
    Dft,
    Frequency,
    LinearComplexity,
    LongestRun,
    MaurerUniversal,
    NonOverlappingTemplate,
    OverlappingSequency,
    OverlappingTemplate,
    Poker,
    RandomExcursions,
    RandomExcursionsVariant,
    Rank,
    RunDistribution,
    Runs,
    Serial,
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

pub fn detectPrint(self: *StatDetect, result: *const DetectResult) void {
    if (result.passed) {
        std.debug.print("Test {s>10}: passed={}, p_value={:10.6}\n",
            .{ self.name,  result.passed, result.p_value });
    } else {
        std.debug.print("Test {s>10}: passed={}\n",
            .{ self.name,  result.passed});
    }
}

pub fn detectMetrics(self: *StatDetect, result: *const DetectResult) void {
    _ = self;
    _ = result;
}

pub fn detectSummary(self: *StatDetect, result: *const DetectResult) void {
    _ = self;
    _ = result;
}

pub fn detectReset(self: *StatDetect) void {
    _ = self;
}

pub const StatDetect = struct {
    name: []const u8,
    param: *DetectParam,

    _init: *const fn (self: *StatDetect, param: *const DetectParam) void,
    _iterate: *const fn (self: *StatDetect, bitStream: *const io.BitInputStream) DetectResult,
    _destroy: *const fn (self: *StatDetect) void,

    _reset: ?*const fn (self: *StatDetect) void,

    pub fn init(self: *StatDetect, param: *const DetectParam) void {
        self._init(self, param);
    }
    pub fn iterate(self: *StatDetect, bitStream: *const io.BitInputStream) DetectResult {
        return self._iterate(self, bitStream);
    }
    pub fn destroy(self: *StatDetect) void {
        self._destroy(self);
    }

    pub fn reset(self: *StatDetect) void {
        if (self._reset == null) {
            return detectReset(self);
        }
        self._reset.?(self);
    }
};

