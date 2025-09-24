const std = @import("std");
const zsts = @import("zsts");
const reporting = zsts.reporting;
const detect = zsts.detect;

test "reporting: summary calculation" {
    var summary = reporting.TestSummary.init();
    
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
    
    var result3 = detect.DetectResult{
        .passed = true,
        .v_value = 0.87,
        .p_value = 0.123,
        .q_value = 0.061,
        .extra = null,
        .errno = null,
    };
    
    summary.addResult(&result1, 10.5);
    summary.addResult(&result2, 8.3);
    summary.addResult(&result3, 12.1);
    
    try std.testing.expect(summary.total_tests == 3);
    try std.testing.expect(summary.passed_tests == 2);
    try std.testing.expect(summary.failed_tests == 1);
    try std.testing.expectApproxEqAbs(summary.pass_rate, 2.0/3.0, 0.001);
    
    // Check p-value statistics
    try std.testing.expectApproxEqAbs(summary.min_p_value, 0.005, 0.001);
    try std.testing.expectApproxEqAbs(summary.max_p_value, 0.123, 0.001);
    try std.testing.expectApproxEqAbs(summary.avg_p_value, (0.045 + 0.005 + 0.123) / 3.0, 0.001);
    try std.testing.expectApproxEqAbs(summary.execution_time_ms, 30.9, 0.1);
}

test "reporting: JSON report generation" {
    const allocator = std.testing.allocator;
    
    var result = detect.DetectResult{
        .passed = true,
        .v_value = 1.23456,
        .p_value = 0.045678,
        .q_value = 0.022839,
        .extra = null,
        .errno = null,
    };
    
    const json_report = try reporting.generateJsonReport(allocator, "Frequency", &result, 15.5, 10000);
    defer allocator.free(json_report);
    
    // Basic validation that JSON contains expected fields
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"test_name\": \"Frequency\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"data_size\": 10000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"execution_time_ms\": 15.500") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"status\": \"PASS\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"passed\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_report, "\"p_value\": 0.045678") != null);
}

test "reporting: CSV report generation" {
    const allocator = std.testing.allocator;
    
    // Test CSV header
    const header = try reporting.generateCsvHeader(allocator);
    defer allocator.free(header);
    
    try std.testing.expect(std.mem.indexOf(u8, header, "Test Name") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "P-Value") != null);
    try std.testing.expect(std.mem.indexOf(u8, header, "Status") != null);
    
    // Test CSV data row
    var result = detect.DetectResult{
        .passed = false,
        .v_value = 2.34567,
        .p_value = 0.008901,
        .q_value = 0.004450,
        .extra = null,
        .errno = null,
    };
    
    const csv_row = try reporting.generateCsvReport(allocator, "Runs", &result, 8.7, 5000);
    defer allocator.free(csv_row);
    
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "Runs") != null);
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "5000") != null);
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "8.700") != null);
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "FAIL") != null);
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "false") != null);
    try std.testing.expect(std.mem.indexOf(u8, csv_row, "Non-random") != null);
}

test "reporting: XML report generation" {
    const allocator = std.testing.allocator;
    
    var result = detect.DetectResult{
        .passed = true,
        .v_value = 0.98765,
        .p_value = 0.234567,
        .q_value = 0.117284,
        .extra = null,
        .errno = null,
    };
    
    const xml_report = try reporting.generateXmlReport(allocator, "DFT", &result, 25.3, 20000);
    defer allocator.free(xml_report);
    
    // Verify XML structure
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<test_result>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "</test_result>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<test_name>DFT</test_name>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<data_size>20000</data_size>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<status>PASS</status>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<p_value>0.234567</p_value>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml_report, "<interpretation>Random</interpretation>") != null);
}

test "reporting: markdown report generation" {
    const allocator = std.testing.allocator;
    
    var result = detect.DetectResult{
        .passed = true,
        .v_value = 1.5678,
        .p_value = 0.067890,
        .q_value = 0.033945,
        .extra = null,
        .errno = null,
    };
    
    const md_report = try reporting.generateMarkdownReport(allocator, "Rank", &result, 45.2, 32768);
    defer allocator.free(md_report);
    
    // Verify Markdown structure
    try std.testing.expect(std.mem.indexOf(u8, md_report, "## Rank Test Report") != null);
    try std.testing.expect(std.mem.indexOf(u8, md_report, "| Status | ✅ **PASS** |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md_report, "| Data Size | 32768 bits |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md_report, "| P-Value | 0.067890 |") != null);
    try std.testing.expect(std.mem.indexOf(u8, md_report, "### Statistical Assessment") != null);
}

test "reporting: summary JSON generation" {
    const allocator = std.testing.allocator;
    
    var summary = reporting.TestSummary.init();
    
    // Add some test results
    var result1 = detect.DetectResult{ .passed = true, .v_value = 1.0, .p_value = 0.05, .q_value = 0.025, .extra = null, .errno = null };
    var result2 = detect.DetectResult{ .passed = false, .v_value = 2.0, .p_value = 0.008, .q_value = 0.004, .extra = null, .errno = null };
    var result3 = detect.DetectResult{ .passed = true, .v_value = 0.5, .p_value = 0.15, .q_value = 0.075, .extra = null, .errno = null };
    
    summary.addResult(&result1, 10.0);
    summary.addResult(&result2, 15.0);
    summary.addResult(&result3, 8.0);
    
    const json_summary = try reporting.generateSummaryReport(allocator, &summary, .json);
    defer allocator.free(json_summary);
    
    // Verify JSON summary contains expected data
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"total_tests\": 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"passed_tests\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"failed_tests\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"pass_rate\": 0.6667") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"min\": 0.008000") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_summary, "\"max\": 0.150000") != null);
}