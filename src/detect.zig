const std = @import("std");
const io = @import("io.zig");

pub const DetectType = enum {
    General,

    ApproxEntropy,
    Autocorrelation,
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
    type: DetectType,
    n: usize,
    num_bitstreams: usize,

    // 可扩展更多参数
    extra: ?*anyopaque, // 支持算法特有参数
};

pub const DetectResult = struct {
    passed: bool,

    p_value: f64,
    stat_value: f64,

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
    _iterate: *const fn (self: *StatDetect, data: []const u8) DetectResult,
    _destroy: *const fn (self: *StatDetect) void,

    _reset: ?*const fn (self: *StatDetect) void,

    _summary: ?*const fn (self: *StatDetect, results: *const DetectResult) void,
    _print: ?*const fn (self: *StatDetect, results: *const DetectResult) void,
    _metrics: ?*const fn (self: *StatDetect, results: *const DetectResult) void,

    pub fn init(self: *StatDetect, param: *const DetectParam) void {
        self._init(self, param);
    }
    pub fn iterate(self: *StatDetect, data: []const u8) DetectResult {
        return self._iterate(self, data);
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

    pub fn summary(self: *StatDetect, result: *const DetectResult) void {
        if (self._summary == null) {
            return detectSummary(self, result);
        }
        self._summary.?(self, result);
    }

    pub fn print(self: *StatDetect, result: *const DetectResult) void {
        if (self._print == null) {
            return detectPrint(self, result);
        }
        self._print.?(self, result);
    }

    pub fn metrics(self: *StatDetect, result: *const DetectResult) void {
        if (self._metrics == null) {
            return detectMetrics(self, result);
        }
        self._metrics.?(self, result);
    }
};

