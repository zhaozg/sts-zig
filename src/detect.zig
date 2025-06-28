const std = @import("std");

pub const DetectParam = struct {
    n: usize,
    num_bitstreams: usize,
    // 可扩展更多参数
};

pub const DetectResult = struct {
    passed: bool,
    p_value: f64,
    // 可扩展更多字段
};

pub const StatDetect = struct {
    init: *const fn(self: *StatDetect, param: *const DetectParam) void,
    iterate: *const fn(self: *StatDetect, data: []const u8) DetectResult,
    print: *const fn(self: *StatDetect, results: []const DetectResult) void,
    metrics: *const fn(self: *StatDetect, results: []const DetectResult) void,
    destroy: *const fn(self: *StatDetect) void,
};
