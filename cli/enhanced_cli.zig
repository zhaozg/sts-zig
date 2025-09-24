const std = @import("std");
const zsts = @import("zsts");
const print = std.debug.print;

/// Enhanced CLI Tool for STS-Zig Statistical Testing Suite
/// STS-Zig 统计测试套件增强版命令行工具

const OutputFormat = enum {
    console,
    json,
    csv,
    xml,
};

const TestConfig = struct {
    input_files: [][]const u8,
    output_format: OutputFormat,
    output_file: ?[]const u8,
    batch_mode: bool,
    verbose: bool,
    tests_to_run: []TestType,
    data_limit: ?usize,
};

const TestType = enum {
    all,
    frequency,
    block_frequency,
    runs,
    longest_runs,
    rank,
    dft,
    poker,
    autocorrelation,
    cumulative_sums,
    approximate_entropy,
    random_excursions,
    random_excursions_variant,
    serial,
    linear_complexity,
    overlapping_template,
    non_overlapping_template,
    universal,

    pub fn toString(self: TestType) []const u8 {
        return switch (self) {
            .all => "all",
            .frequency => "frequency",
            .block_frequency => "block_frequency",
            .runs => "runs",
            .longest_runs => "longest_runs",
            .rank => "rank",
            .dft => "dft",
            .poker => "poker",
            .autocorrelation => "autocorrelation",
            .cumulative_sums => "cumulative_sums",
            .approximate_entropy => "approximate_entropy",
            .random_excursions => "random_excursions",
            .random_excursions_variant => "random_excursions_variant",
            .serial => "serial",
            .linear_complexity => "linear_complexity",
            .overlapping_template => "overlapping_template",
            .non_overlapping_template => "non_overlapping_template",
            .universal => "universal",
        };
    }
};

const TestResult = struct {
    test_name: []const u8,
    file_name: []const u8,
    passed: bool,
    p_value: f64,
    v_value: f64,
    q_value: f64,
    execution_time_ms: f64,
    data_size: usize,
};

const BatchResults = struct {
    total_files: usize,
    total_tests: usize,
    passed_tests: usize,
    failed_tests: usize,
    average_execution_time: f64,
    results: []TestResult,
};

fn printUsage(program_name: []const u8) void {
    print("STS-Zig Enhanced CLI - Statistical Test Suite\n", .{});
    print("===========================================\n\n", .{});
    print("USAGE:\n", .{});
    print("    {s} [OPTIONS] <input_files...>\n\n", .{program_name});
    print("OPTIONS:\n", .{});
    print("    -h, --help              Show this help message\n", .{});
    print("    -v, --verbose           Enable verbose output\n", .{});
    print("    -b, --batch             Enable batch processing mode\n", .{});
    print("    -f, --format FORMAT     Output format: console, json, csv, xml (default: console)\n", .{});
    print("    -o, --output FILE       Output file (default: stdout)\n", .{});
    print("    -t, --tests TESTS       Comma-separated list of tests to run (default: all)\n", .{});
    print("    -l, --limit SIZE        Limit data size (in bits)\n\n", .{});
    print("AVAILABLE TESTS:\n", .{});
    print("    all, frequency, block_frequency, runs, longest_runs, rank, dft,\n", .{});
    print("    poker, autocorrelation, cumulative_sums, approximate_entropy,\n", .{});
    print("    random_excursions, random_excursions_variant, serial,\n", .{});
    print("    linear_complexity, overlapping_template, non_overlapping_template, universal\n\n", .{});
    print("EXAMPLES:\n", .{});
    print("    {s} data.txt                                   # Run all tests on data.txt\n", .{program_name});
    print("    {s} -t frequency,runs data.txt                 # Run specific tests\n", .{program_name});
    print("    {s} -b -f json -o results.json *.txt          # Batch mode with JSON output\n", .{program_name});
    print("    {s} -v -f csv data1.txt data2.txt             # Verbose mode with CSV output\n", .{program_name});
}

fn parseOutputFormat(format_str: []const u8) !OutputFormat {
    if (std.mem.eql(u8, format_str, "console")) return .console;
    if (std.mem.eql(u8, format_str, "json")) return .json;
    if (std.mem.eql(u8, format_str, "csv")) return .csv;
    if (std.mem.eql(u8, format_str, "xml")) return .xml;
    return error.InvalidFormat;
}

fn parseTestTypes(allocator: std.mem.Allocator, tests_str: []const u8) ![]TestType {
    var result = std.ArrayList(TestType).init(allocator);
    var iter = std.mem.split(u8, tests_str, ",");
    
    while (iter.next()) |test_name| {
        const trimmed = std.mem.trim(u8, test_name, " \t\n\r");
        
        if (std.mem.eql(u8, trimmed, "all")) {
            try result.append(.all);
        } else if (std.mem.eql(u8, trimmed, "frequency")) {
            try result.append(.frequency);
        } else if (std.mem.eql(u8, trimmed, "block_frequency")) {
            try result.append(.block_frequency);
        } else if (std.mem.eql(u8, trimmed, "runs")) {
            try result.append(.runs);
        } else if (std.mem.eql(u8, trimmed, "rank")) {
            try result.append(.rank);
        } else if (std.mem.eql(u8, trimmed, "dft")) {
            try result.append(.dft);
        } else if (std.mem.eql(u8, trimmed, "poker")) {
            try result.append(.poker);
        } else {
            print("Warning: Unknown test type '{s}' ignored\n", .{trimmed});
        }
    }
    
    if (result.items.len == 0) {
        try result.append(.all);
    }
    
    return result.toOwnedSlice();
}

fn runTest(allocator: std.mem.Allocator, test_type: TestType, data: []const u8, file_name: []const u8) !TestResult {
    const start_time = std.time.milliTimestamp();
    var test_result = TestResult{
        .test_name = test_type.toString(),
        .file_name = file_name,
        .passed = false,
        .p_value = 0.0,
        .v_value = 0.0,
        .q_value = 0.0,
        .execution_time_ms = 0.0,
        .data_size = data.len,
    };

    const bits = zsts.io.BitInputStream.fromAscii(allocator, data);
    defer bits.close();

    switch (test_type) {
        .frequency => {
            const param = zsts.detect.DetectParam{
                .type = zsts.detect.DetectType.Frequency,
                .n = data.len,
                .extra = null,
            };
            const stat = try zsts.frequency.frequencyDetectStatDetect(allocator, param);
            defer stat.destroy();
            
            stat.init(&param);
            const result = stat.iterate(&bits);
            
            test_result.passed = result.passed;
            test_result.p_value = result.p_value;
            test_result.v_value = result.v_value;
            test_result.q_value = result.q_value;
        },
        .runs => {
            const param = zsts.detect.DetectParam{
                .type = zsts.detect.DetectType.Runs,
                .n = data.len,
                .extra = null,
            };
            const stat = try zsts.runs.runsDetectStatDetect(allocator, param);
            defer stat.destroy();
            
            stat.init(&param);
            const result = stat.iterate(&bits);
            
            test_result.passed = result.passed;
            test_result.p_value = result.p_value;
            test_result.v_value = result.v_value;
            test_result.q_value = result.q_value;
        },
        .rank => {
            const param = zsts.detect.DetectParam{
                .type = zsts.detect.DetectType.Rank,
                .n = data.len,
                .extra = null,
            };
            const stat = try zsts.rank.rankDetectStatDetect(allocator, param);
            defer stat.destroy();
            
            stat.init(&param);
            const result = stat.iterate(&bits);
            
            test_result.passed = result.passed;
            test_result.p_value = result.p_value;
            test_result.v_value = result.v_value;
            test_result.q_value = result.q_value;
        },
        .dft => {
            const param = zsts.detect.DetectParam{
                .type = zsts.detect.DetectType.Dft,
                .n = data.len,
                .extra = null,
            };
            const stat = try zsts.dft.dftDetectStatDetect(allocator, param);
            defer stat.destroy();
            
            stat.init(&param);
            const result = stat.iterate(&bits);
            
            test_result.passed = result.passed;
            test_result.p_value = result.p_value;
            test_result.v_value = result.v_value;
            test_result.q_value = result.q_value;
        },
        else => {
            print("Test type '{s}' not yet implemented in CLI\n", .{test_type.toString()});
            return test_result;
        },
    }

    const end_time = std.time.milliTimestamp();
    test_result.execution_time_ms = @as(f64, @floatFromInt(end_time - start_time));
    
    return test_result;
}

fn outputConsole(results: []TestResult, config: TestConfig) void {
    print("\n📊 STS-Zig Statistical Test Results\n", .{});
    print("===================================\n\n", .{});
    
    if (config.batch_mode) {
        print("Batch Mode: {d} files processed\n", .{config.input_files.len});
        print("Tests per file: {d}\n", .{config.tests_to_run.len});
        print("\n", .{});
    }

    var passed: usize = 0;
    var failed: usize = 0;

    print("┌──────────────────┬─────────────────┬────────┬───────────┬───────────┬───────────┬──────────┐\n", .{});
    print("│ File             │ Test            │ Status │  P-Value  │  V-Value  │  Q-Value  │ Time(ms) │\n", .{});
    print("├──────────────────┼─────────────────┼────────┼───────────┼───────────┼───────────┼──────────┤\n", .{});

    for (results) |result| {
        const status = if (result.passed) "✅ PASS" else "❌ FAIL";
        if (result.passed) passed += 1 else failed += 1;

        const truncated_file = if (result.file_name.len > 16) 
            result.file_name[0..13] ++ "..." 
        else 
            result.file_name;

        const truncated_test = if (result.test_name.len > 15) 
            result.test_name[0..12] ++ "..." 
        else 
            result.test_name;

        print("│ {s:<16} │ {s:<15} │ {s:<6} │ {d:>9.6f} │ {d:>9.3f} │ {d:>9.6f} │ {d:>8.2f} │\n", 
            .{ truncated_file, truncated_test, status, result.p_value, result.v_value, result.q_value, result.execution_time_ms });
    }

    print("└──────────────────┴─────────────────┴────────┴───────────┴───────────┴───────────┴──────────┘\n", .{});
    print("\n📈 Summary: {d} passed, {d} failed, {d} total\n", .{ passed, failed, results.len });
    
    var total_time: f64 = 0;
    for (results) |result| {
        total_time += result.execution_time_ms;
    }
    print("⏱️  Total execution time: {d:.2f}ms\n", .{total_time});
}

fn outputJson(results: []TestResult, config: TestConfig, allocator: std.mem.Allocator) !void {
    _ = config;
    _ = allocator;
    print("{{\n", .{});
    print("  \"metadata\": {{\n", .{});
    print("    \"tool\": \"STS-Zig Enhanced CLI\",\n", .{});
    print("    \"version\": \"1.0.0\",\n");
    print("    \"timestamp\": \"{d}\",\n", .{std.time.timestamp()});
    print("    \"batch_mode\": {},\n", .{config.batch_mode});
    print("    \"total_files\": {d},\n", .{config.input_files.len});
    print("    \"total_tests\": {d}\n", .{results.len});
    print("  }},\n", .{});
    print("  \"results\": [\n");

    for (results, 0..) |result, i| {
        print("    {{\n", .{});
        print("      \"file_name\": \"{s}\",\n", .{result.file_name});
        print("      \"test_name\": \"{s}\",\n", .{result.test_name});
        print("      \"passed\": {},\n", .{result.passed});
        print("      \"p_value\": {d},\n", .{result.p_value});
        print("      \"v_value\": {d},\n", .{result.v_value});
        print("      \"q_value\": {d},\n", .{result.q_value});
        print("      \"execution_time_ms\": {d},\n", .{result.execution_time_ms});
        print("      \"data_size\": {d}\n", .{result.data_size});
        if (i < results.len - 1) {
            print("    }},\n", .{});
        } else {
            print("    }}\n", .{});
        }
    }

    print("  ]\n", .{});
    print("}}\n", .{});
}

fn outputCsv(results: []TestResult, config: TestConfig) void {
    _ = config;
    print("File,Test,Status,P_Value,V_Value,Q_Value,Execution_Time_MS,Data_Size\n", .{});
    
    for (results) |result| {
        const status = if (result.passed) "PASS" else "FAIL";
        print("{s},{s},{s},{d},{d},{d},{d},{d}\n", 
            .{ result.file_name, result.test_name, status, result.p_value, 
               result.v_value, result.q_value, result.execution_time_ms, result.data_size });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        printUsage(args[0]);
        return;
    }

    // Parse command line arguments
    var config = TestConfig{
        .input_files = &[_][]const u8{},
        .output_format = .console,
        .output_file = null,
        .batch_mode = false,
        .verbose = false,
        .tests_to_run = &[_]TestType{.all},
        .data_limit = null,
    };

    var input_files = std.ArrayList([]const u8).init(allocator);
    defer input_files.deinit();

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage(args[0]);
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--batch")) {
            config.batch_mode = true;
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--format")) {
            if (i + 1 >= args.len) {
                print("Error: --format requires a value\n", .{});
                return;
            }
            i += 1;
            config.output_format = parseOutputFormat(args[i]) catch {
                print("Error: Invalid format '{s}'\n", .{args[i]});
                return;
            };
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--tests")) {
            if (i + 1 >= args.len) {
                print("Error: --tests requires a value\n", .{});
                return;
            }
            i += 1;
            config.tests_to_run = try parseTestTypes(allocator, args[i]);
        } else {
            try input_files.append(arg);
        }
    }

    if (input_files.items.len == 0) {
        print("Error: No input files specified\n", .{});
        printUsage(args[0]);
        return;
    }

    config.input_files = input_files.items;

    if (config.verbose) {
        print("🔧 Configuration:\n", .{});
        print("- Input files: {d}\n", .{config.input_files.len});
        print("- Output format: {s}\n", .{@tagName(config.output_format)});
        print("- Batch mode: {}\n", .{config.batch_mode});
        print("- Tests to run: {d}\n", .{config.tests_to_run.len});
        print("\n", .{});
    }

    // Process files and run tests
    var all_results = std.ArrayList(TestResult).init(allocator);
    defer all_results.deinit();

    for (config.input_files) |file_path| {
        if (config.verbose) {
            print("📁 Processing file: {s}\n", .{file_path});
        }

        // Read file content
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            print("Error: Cannot open file '{s}': {}\n", .{ file_path, err });
            continue;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const content = try allocator.alloc(u8, file_size);
        defer allocator.free(content);
        _ = try file.readAll(content);

        // Limit data size if specified
        const actual_content = if (config.data_limit) |limit|
            if (content.len > limit) content[0..limit] else content
        else 
            content;

        // Run tests
        for (config.tests_to_run) |test_type| {
            if (test_type == .all) {
                // Run all available tests
                const available_tests = [_]TestType{ .frequency, .runs, .rank, .dft };
                for (available_tests) |available_test| {
                    const result = try runTest(allocator, available_test, actual_content, file_path);
                    try all_results.append(result);
                    
                    if (config.verbose) {
                        const status = if (result.passed) "✅" else "❌";
                        print("  {s} {s}: P={d:.6f}, Time={d:.2f}ms\n", 
                            .{ status, result.test_name, result.p_value, result.execution_time_ms });
                    }
                }
            } else {
                const result = try runTest(allocator, test_type, actual_content, file_path);
                try all_results.append(result);
                
                if (config.verbose) {
                    const status = if (result.passed) "✅" else "❌";
                    print("  {s} {s}: P={d:.6f}, Time={d:.2f}ms\n", 
                        .{ status, result.test_name, result.p_value, result.execution_time_ms });
                }
            }
        }
    }

    // Output results
    switch (config.output_format) {
        .console => outputConsole(all_results.items, config),
        .json => try outputJson(all_results.items, config, allocator),
        .csv => outputCsv(all_results.items, config),
        .xml => {
            print("XML output format not yet implemented\n", .{});
            outputConsole(all_results.items, config);
        },
    }
}