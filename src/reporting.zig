const std = @import("std");
const detect = @import("detect.zig");
const print = std.debug.print;

/// Report formatting options
pub const ReportFormat = enum {
    console,
    csv,
    xml,
    markdown,
    html,
};

/// Statistical summary for a set of test results
pub const TestSummary = struct {
    total_tests: usize,
    passed_tests: usize,
    failed_tests: usize,
    pass_rate: f64,
    min_p_value: f64,
    max_p_value: f64,
    avg_p_value: f64,
    execution_time_ms: f64,

    pub fn init() TestSummary {
        return TestSummary{
            .total_tests = 0,
            .passed_tests = 0,
            .failed_tests = 0,
            .pass_rate = 0.0,
            .min_p_value = 1.0,
            .max_p_value = 0.0,
            .avg_p_value = 0.0,
            .execution_time_ms = 0.0,
        };
    }

    pub fn addResult(self: *TestSummary, result: *const detect.DetectResult, execution_time: f64) void {
        self.total_tests += 1;
        if (result.passed) {
            self.passed_tests += 1;
        } else {
            self.failed_tests += 1;
        }

        self.pass_rate = @as(f64, @floatFromInt(self.passed_tests)) / @as(f64, @floatFromInt(self.total_tests));

        if (result.p_value < self.min_p_value) {
            self.min_p_value = result.p_value;
        }
        if (result.p_value > self.max_p_value) {
            self.max_p_value = result.p_value;
        }

        self.avg_p_value = (self.avg_p_value * @as(f64, @floatFromInt(self.total_tests - 1)) + result.p_value) / @as(f64, @floatFromInt(self.total_tests));
        self.execution_time_ms += execution_time;
    }
};

/// Generate detailed console report
pub fn generateConsoleReport(allocator: std.mem.Allocator, test_name: []const u8, result: *const detect.DetectResult, execution_time: f64, data_size: usize) !void {
    _ = allocator;

    print("\n═══════════════════════════════════════════════\n", .{});
    print("📊 Statistical Test Report\n", .{});
    print("═══════════════════════════════════════════════\n", .{});
    print("🔬 Test Name: {s}\n", .{test_name});
    print("📏 Data Size: {} bits\n", .{data_size});
    print("⏱️  Execution Time: {d:.3} ms\n", .{execution_time});
    print("───────────────────────────────────────────────\n", .{});

    const status_icon = if (result.passed) "✅" else "❌";
    const status_text = if (result.passed) "PASS" else "FAIL";

    print("{s} Status: {s}\n", .{ status_icon, status_text });
    print("📈 Test Statistic (V): {d:.6}\n", .{result.v_value});
    print("🎯 P-Value: {d:.6}\n", .{result.p_value});
    print("🎲 Q-Value: {d:.6}\n", .{result.q_value});

    if (result.p_value >= 0.01) {
        print("📋 Interpretation: The sequence appears random (p ≥ 0.01)\n", .{});
    } else {
        print("⚠️  Interpretation: The sequence may not be random (p < 0.01)\n", .{});
    }

    if (result.errno) |err| {
        print("🚫 Error: {}\n", .{err});
    }

    print("═══════════════════════════════════════════════\n\n", .{});
}

/// Generate CSV report header
pub fn generateCsvHeader(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "Test Name,Data Size,Execution Time (ms),Status,Passed,Test Statistic,P-Value,Q-Value,Interpretation,Timestamp\n", .{});
}

/// Generate CSV report line
pub fn generateCsvReport(io: std.Io, allocator: std.mem.Allocator, test_name: []const u8, result: *const detect.DetectResult, execution_time: f64, data_size: usize) ![]u8 {
    const status = if (result.passed) "PASS" else "FAIL";
    const interpretation = if (result.p_value >= 0.01) "Random" else "Non-random";
    const clock = std.Io.Clock.awake;
    const timestamp = std.Io.Clock.now(clock, io);

    return std.fmt.allocPrint(allocator, "{s},{},{d:.3},{s},{},{d:.6},{d:.6},{d:.6},{s},{d}\n", .{ test_name, data_size, execution_time, status, result.passed, result.v_value, result.p_value, result.q_value, interpretation, timestamp });
}

/// Generate XML report
pub fn generateXmlReport(io: std.Io, allocator: std.mem.Allocator, test_name: []const u8, result: *const detect.DetectResult, execution_time: f64, data_size: usize) ![]u8 {
    const status = if (result.passed) "PASS" else "FAIL";
    const interpretation = if (result.p_value >= 0.01) "Random" else "Non-random";
    const clock = std.Io.Clock.awake;
    const timestamp = std.Io.Clock.now(clock, io);

    const xml_template =
        \\<test_result>
        \\  <test_name>{s}</test_name>
        \\  <data_size>{}</data_size>
        \\  <execution_time_ms>{d:.3}</execution_time_ms>
        \\  <status>{s}</status>
        \\  <passed>{}</passed>
        \\  <statistics>
        \\    <test_statistic>{d:.6}</test_statistic>
        \\    <p_value>{d:.6}</p_value>
        \\    <q_value>{d:.6}</q_value>
        \\  </statistics>
        \\  <interpretation>{s}</interpretation>
        \\  <timestamp>{d}</timestamp>
        \\</test_result>
    ;

    return std.fmt.allocPrint(allocator, xml_template, .{ test_name, data_size, execution_time, status, result.passed, result.v_value, result.p_value, result.q_value, interpretation, timestamp });
}

/// Generate summary report for multiple tests
pub fn generateSummaryReport(allocator: std.mem.Allocator, summary: *const TestSummary, format: ReportFormat) ![]u8 {
    switch (format) {
        .console => {
            print("\n🎯 Test Suite Summary\n", .{});
            print("══════════════════════════════════════\n", .{});
            print("📊 Total Tests: {}\n", .{summary.total_tests});
            print("✅ Passed: {} ({d:.1}%)\n", .{ summary.passed_tests, summary.pass_rate * 100 });
            print("❌ Failed: {}\n", .{summary.failed_tests});
            print("📈 P-Value Range: {d:.6} - {d:.6}\n", .{ summary.min_p_value, summary.max_p_value });
            print("📊 Average P-Value: {d:.6}\n", .{summary.avg_p_value});
            print("⏱️  Total Execution Time: {d:.3} ms\n", .{summary.execution_time_ms});
            print("══════════════════════════════════════\n\n", .{});
            return try allocator.dupe(u8, "Console output generated");
        },
        .json => {
            return std.fmt.allocPrint(allocator,
                \\{{
                \\  "summary": {{
                \\    "total_tests": {},
                \\    "passed_tests": {},
                \\    "failed_tests": {},
                \\    "pass_rate": {d:.4},
                \\    "p_value_range": {{ "min": {d:.6}, "max": {d:.6} }},
                \\    "avg_p_value": {d:.6},
                \\    "total_execution_time_ms": {d:.3}
                \\  }}
                \\}}
            , .{
                summary.total_tests,
                summary.passed_tests,
                summary.failed_tests,
                summary.pass_rate,
                summary.min_p_value,
                summary.max_p_value,
                summary.avg_p_value,
                summary.execution_time_ms,
            });
        },
        else => {
            return try allocator.dupe(u8, "Format not implemented");
        },
    }
}

/// Generate detailed markdown report
pub fn generateMarkdownReport(allocator: std.mem.Allocator, test_name: []const u8, result: *const detect.DetectResult, execution_time: f64, data_size: usize) ![]u8 {
    const status_icon = if (result.passed) "✅" else "❌";
    const status_text = if (result.passed) "**PASS**" else "**FAIL**";
    const interpretation = if (result.p_value >= 0.01) "The sequence appears random" else "⚠️ The sequence may not be random";

    return std.fmt.allocPrint(allocator,
        \\## {s} Test Report
        \\
        \\| Metric | Value |
        \\|--------|-------|
        \\| Status | {s} {s} |
        \\| Data Size | {} bits |
        \\| Execution Time | {d:.3} ms |
        \\| Test Statistic (V) | {d:.6} |
        \\| P-Value | {d:.6} |
        \\| Q-Value | {d:.6} |
        \\| Interpretation | {s} |
        \\
        \\### Statistical Assessment
        \\
        \\{s}
        \\
    , .{ test_name, status_icon, status_text, data_size, execution_time, result.v_value, result.p_value, result.q_value, interpretation, if (result.p_value >= 0.01)
        "The p-value ≥ 0.01 indicates that the null hypothesis (randomness) is not rejected. The sequence passes the statistical randomness test."
    else
        "The p-value < 0.01 suggests that the null hypothesis (randomness) should be rejected. The sequence may exhibit non-random patterns." });
}

test "reporting: summary calculation" {
    var summary = TestSummary.init();

    var result1 = detect.DetectResult{
        .passed = true,
        .v_value = 1.23,
        .p_value = 0.045,
        .q_value = 0.022,
        .extra = null,
        .errno = null,
    };

    var result2 = detect.DetectResult{
        .passed = false,
        .v_value = 2.34,
        .p_value = 0.005,
        .q_value = 0.002,
        .extra = null,
        .errno = null,
    };

    summary.addResult(&result1, 10.5);
    summary.addResult(&result2, 8.3);

    try std.testing.expect(summary.total_tests == 2);
    try std.testing.expect(summary.passed_tests == 1);
    try std.testing.expect(summary.failed_tests == 1);
    try std.testing.expectApproxEqAbs(summary.pass_rate, 0.5, 0.001);
}
