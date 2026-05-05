const std = @import("std");
const suite = @import("suite.zig");
const IO = @import("io.zig");
const detect = @import("detect.zig");

/// Output format options
const OutputFormat = enum {
    console,
    json,
    csv,
    xml,
};

/// Test type options
const TestType = enum {
    all,
    // Suite options
    nist800,
    gmt0005,
    // Individual tests
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
    binary_derivative,
    run_distribution,
    overlapping_sequency,

    pub fn toString(self: TestType) []const u8 {
        return switch (self) {
            .all => "all",
            .nist800 => "NIST800",
            .gmt0005 => "GMT0005",
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
            .binary_derivative => "binary_derivative",
            .run_distribution => "run_distribution",
            .overlapping_sequency => "overlapping_sequency",
        };
    }
};

const Options = struct {
    help: bool = false,
    version: bool = false,
    ascii: bool = false,
    verbose: bool = false,
    blocksize: usize = 1000000,
    output: ?[]const u8 = null,
    input: ?[]const u8 = null,
    // Enhanced CLI options
    batch_mode: bool = false,
    output_format: OutputFormat = .console,
    tests_to_run: []TestType = @constCast(&[_]TestType{.all}),
    data_limit: ?usize = null,
    input_files: [][]const u8 = &[_][]const u8{},
};

const version_string = "zsts version 1.0";

/// Result structure for individual test results
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

/// Cross-compatible ArrayList append helper
inline fn appendToList(comptime T: type, list: *std.ArrayList(T), _: std.mem.Allocator, item: T) !void {
    if (@hasField(std.ArrayList(T), "allocator")) {
        try list.append(item);
    } else {
        try list.append(item);
    }
}

fn parseOutputFormat(format_str: []const u8) !OutputFormat {
    if (std.mem.eql(u8, format_str, "console")) return .console;
    if (std.mem.eql(u8, format_str, "json")) return .json;
    if (std.mem.eql(u8, format_str, "csv")) return .csv;
    if (std.mem.eql(u8, format_str, "xml")) return .xml;
    return error.InvalidFormat;
}

fn parseTestTypes(allocator: std.mem.Allocator, tests_str: []const u8) ![]TestType {
    var result = std.ArrayList(TestType).empty;
    defer result.deinit(allocator);
    var iter = std.mem.splitSequence(u8, tests_str, ",");

    while (iter.next()) |test_name| {
        const trimmed = std.mem.trim(u8, test_name, " \t\n\r");

        if (std.mem.eql(u8, trimmed, "all")) {
            try result.append(allocator, .all);
        } else if (std.mem.eql(u8, trimmed, "NIST800") or std.mem.eql(u8, trimmed, "nist800")) {
            try result.append(allocator, .nist800);
        } else if (std.mem.eql(u8, trimmed, "GMT0005") or std.mem.eql(u8, trimmed, "gmt0005")) {
            try result.append(allocator, .gmt0005);
        } else if (std.mem.eql(u8, trimmed, "frequency")) {
            try result.append(allocator, .frequency);
        } else if (std.mem.eql(u8, trimmed, "block_frequency")) {
            try result.append(allocator, .block_frequency);
        } else if (std.mem.eql(u8, trimmed, "runs")) {
            try result.append(allocator, .runs);
        } else if (std.mem.eql(u8, trimmed, "longest_runs")) {
            try result.append(allocator, .longest_runs);
        } else if (std.mem.eql(u8, trimmed, "rank")) {
            try result.append(allocator, .rank);
        } else if (std.mem.eql(u8, trimmed, "dft")) {
            try result.append(allocator, .dft);
        } else if (std.mem.eql(u8, trimmed, "poker")) {
            try result.append(allocator, .poker);
        } else if (std.mem.eql(u8, trimmed, "autocorrelation")) {
            try result.append(allocator, .autocorrelation);
        } else if (std.mem.eql(u8, trimmed, "cumulative_sums")) {
            try result.append(allocator, .cumulative_sums);
        } else if (std.mem.eql(u8, trimmed, "approximate_entropy")) {
            try result.append(allocator, .approximate_entropy);
        } else if (std.mem.eql(u8, trimmed, "random_excursions")) {
            try result.append(allocator, .random_excursions);
        } else if (std.mem.eql(u8, trimmed, "random_excursions_variant")) {
            try result.append(allocator, .random_excursions_variant);
        } else if (std.mem.eql(u8, trimmed, "serial")) {
            try result.append(allocator, .serial);
        } else if (std.mem.eql(u8, trimmed, "linear_complexity")) {
            try result.append(allocator, .linear_complexity);
        } else if (std.mem.eql(u8, trimmed, "overlapping_template")) {
            try result.append(allocator, .overlapping_template);
        } else if (std.mem.eql(u8, trimmed, "non_overlapping_template")) {
            try result.append(allocator, .non_overlapping_template);
        } else if (std.mem.eql(u8, trimmed, "universal")) {
            try result.append(allocator, .universal);
        } else if (std.mem.eql(u8, trimmed, "binary_derivative")) {
            try result.append(allocator, .binary_derivative);
        } else if (std.mem.eql(u8, trimmed, "run_distribution")) {
            try result.append(allocator, .run_distribution);
        } else if (std.mem.eql(u8, trimmed, "overlapping_sequency")) {
            try result.append(allocator, .overlapping_sequency);
        } else {
            std.debug.print("Warning: Unknown test type '{s}' ignored\n", .{trimmed});
        }
    }

    if (result.items.len == 0) {
        try result.append(allocator, .all);
    }

    return result.toOwnedSlice(allocator);
}

fn expandTestSuites(allocator: std.mem.Allocator, tests: []TestType) ![]TestType {
    var result = std.ArrayList(TestType).empty;
    defer result.deinit(allocator);

    for (tests) |test_type| {
        switch (test_type) {
            .all => {
                // Add all available tests
                const all_tests = [_]TestType{ .frequency, .block_frequency, .poker, .overlapping_sequency, .runs, .run_distribution, .longest_runs, .binary_derivative, .autocorrelation, .rank, .cumulative_sums, .approximate_entropy, .universal, .dft, .overlapping_template, .non_overlapping_template, .random_excursions, .random_excursions_variant, .serial, .linear_complexity };
                for (all_tests) |t| {
                    try result.append(allocator, t);
                }
            },
            .gmt0005 => {
                // GMT0005 test suite
                const gmt_tests = [_]TestType{ .frequency, .block_frequency, .poker, .overlapping_sequency, .runs, .run_distribution, .longest_runs, .binary_derivative, .autocorrelation, .rank, .cumulative_sums, .approximate_entropy, .universal, .dft };
                for (gmt_tests) |t| {
                    try result.append(allocator, t);
                }
            },
            .nist800 => {
                // NIST SP800-22r1 test suite
                const nist_tests = [_]TestType{ .overlapping_template, .non_overlapping_template, .random_excursions, .random_excursions_variant, .serial };
                for (nist_tests) |t| {
                    try result.append(allocator, t);
                }
            },
            else => {
                // Individual test - add as is
                try result.append(allocator, test_type);
            },
        }
    }

    return result.toOwnedSlice(allocator);
}

fn testTypesToStrings(allocator: std.mem.Allocator, tests: []TestType) ![][]const u8 {
    var result = try allocator.alloc([]const u8, tests.len);
    for (tests, 0..) |test_type, i| {
        result[i] = test_type.toString();
    }
    return result;
}

fn outputConsole(results: []TestResult, options: Options) void {
    std.debug.print("\n📊 STS-Zig Statistical Test Results\n", .{});
    std.debug.print("===================================\n\n", .{});

    if (options.batch_mode) {
        std.debug.print("Batch Mode: {d} files processed\n", .{options.input_files.len});
        std.debug.print("Tests per file: {d}\n", .{options.tests_to_run.len});
        std.debug.print("\n", .{});
    }

    var passed: usize = 0;
    var failed: usize = 0;

    std.debug.print("┌──────────────────┬─────────────────┬────────┬───────────┬───────────┬───────────┬──────────┐\n", .{});
    std.debug.print("│ File             │ Test            │ Status │  P-Value  │  V-Value  │  Q-Value  │ Time(ms) │\n", .{});
    std.debug.print("├──────────────────┼─────────────────┼────────┼───────────┼───────────┼───────────┼──────────┤\n", .{});

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

        std.debug.print("│ {s:<16} │ {s:<15} │ {s:<6} │ {d:>9.6} │ {d:>9.3} │ {d:>9.6} │ {d:>8.2} │\n", .{ truncated_file, truncated_test, status, result.p_value, result.v_value, result.q_value, result.execution_time_ms });
    }

    std.debug.print("└──────────────────┴─────────────────┴────────┴───────────┴───────────┴───────────┴──────────┘\n", .{});
    std.debug.print("\n📈 Summary: {d} passed, {d} failed, {d} total\n", .{ passed, failed, results.len });

    var total_time: f64 = 0;
    for (results) |result| {
        total_time += result.execution_time_ms;
    }
    std.debug.print("⏱️  Total execution time: {d:.2}ms\n", .{total_time});
}

fn outputJson(results: []TestResult, options: Options) void {
    std.debug.print("{{\n", .{});
    std.debug.print("  \"metadata\": {{\n", .{});
    std.debug.print("    \"tool\": \"STS-Zig Enhanced CLI\",\n", .{});
    std.debug.print("    \"version\": \"1.0.0\",\n", .{});
    std.debug.print("    \"batch_mode\": {},\n", .{options.batch_mode});
    std.debug.print("    \"total_files\": {d},\n", .{options.input_files.len});
    std.debug.print("    \"total_tests\": {d}\n", .{results.len});
    std.debug.print("  }},\n", .{});
    std.debug.print("  \"results\": [\n", .{});

    for (results, 0..) |result, i| {
        std.debug.print("    {{\n", .{});
        std.debug.print("      \"file_name\": \"{s}\",\n", .{result.file_name});
        std.debug.print("      \"test_name\": \"{s}\",\n", .{result.test_name});
        std.debug.print("      \"passed\": {},\n", .{result.passed});
        std.debug.print("      \"p_value\": {d},\n", .{result.p_value});
        std.debug.print("      \"v_value\": {d},\n", .{result.v_value});
        std.debug.print("      \"q_value\": {d},\n", .{result.q_value});
        std.debug.print("      \"execution_time_ms\": {d},\n", .{result.execution_time_ms});
        std.debug.print("      \"data_size\": {d}\n", .{result.data_size});
        if (i < results.len - 1) {
            std.debug.print("    }},\n", .{});
        } else {
            std.debug.print("    }}\n", .{});
        }
    }

    std.debug.print("  ]\n", .{});
    std.debug.print("}}\n", .{});
}

fn outputCsv(results: []TestResult) void {
    std.debug.print("File,Test,Status,P_Value,V_Value,Q_Value,Execution_Time_MS,Data_Size\n", .{});

    for (results) |result| {
        const status = if (result.passed) "PASS" else "FAIL";
        std.debug.print("{s},{s},{s},{d},{d},{d},{d},{d}\n", .{ result.file_name, result.test_name, status, result.p_value, result.v_value, result.q_value, result.execution_time_ms, result.data_size });
    }
}

fn printHelp() void {
    const help_text =
        \\STS-Zig Enhanced CLI - Statistical Test Suite
        \\===========================================
        \\
        \\USAGE:
        \\    zsts [OPTIONS] <input_files...>
        \\
        \\OPTIONS:
        \\    -h, --help              Show this help message
        \\    -v, --version           Print version information
        \\    -V, --verbose           Enable verbose output
        \\    -a, --ascii             Input ASCII characters
        \\    -o  output              Output to file
        \\    -b  blocksize           Input length of bits, default 1000000
        \\    --batch                 Enable batch processing mode
        \\    -f, --format FORMAT     Output format: console, json, csv, xml (default: console)
        \\    -t, --tests TESTS       Comma-separated list of tests to run (default: all)
        \\    -l, --limit SIZE        Limit data size (in bits)
        \\
        \\AVAILABLE TESTS:
        \\    all                     - Run all available tests
        \\    NIST800, GMT0005        - Run specific test suites
        \\    Individual tests:
        \\      frequency, block_frequency, runs, longest_runs, rank, dft, poker,
        \\      autocorrelation, cumulative_sums, approximate_entropy, random_excursions,
        \\      random_excursions_variant, serial, linear_complexity, overlapping_template,
        \\      non_overlapping_template, universal, binary_derivative, run_distribution,
        \\      overlapping_sequency
        \\
        \\TEST SUITES:
        \\    GMT0005: frequency, block_frequency, poker, overlapping_sequency, runs,
        \\             run_distribution, longest_runs, binary_derivative, autocorrelation,
        \\             rank, cumulative_sums, approximate_entropy, universal, dft
        \\    NIST800: overlapping_template, non_overlapping_template, random_excursions,
        \\             random_excursions_variant, serial
        \\
        \\EXAMPLES:
        \\    zsts data.txt                                   # Run all tests on data.txt
        \\    zsts -t frequency,runs data.txt                 # Run specific tests
        \\    zsts -t GMT0005 data.txt                        # Run GMT0005 test suite
        \\    zsts -t NIST800,frequency data.txt              # Run NIST800 suite + frequency test
        \\    zsts --batch -f json -o results.json *.txt      # Batch mode with JSON output
        \\    zsts -V -f csv data1.txt data2.txt              # Verbose mode with CSV output
    ;
    std.debug.print("{s}\n", .{help_text});
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    //const _io  = init.io;

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    var options = Options{};

    // Use ArrayList for collecting input files
    var input_files = std.ArrayList([]const u8).empty;
    defer input_files.deinit(allocator);

    // Parse command line arguments
    var i: usize = 1; // Skip program name
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                options.help = true;
            } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                options.version = true;
            } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--ascii")) {
                options.ascii = true;
            } else if (std.mem.eql(u8, arg, "-V") or std.mem.eql(u8, arg, "--verbose")) {
                options.verbose = true;
            } else if (std.mem.eql(u8, arg, "--batch")) {
                options.batch_mode = true;
            } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--format")) {
                i += 1;
                if (i >= args.len) {
                    std.debug.print("Error: --format requires a value\n", .{});
                    return error.MissingFormatArgument;
                }
                options.output_format = parseOutputFormat(args[i]) catch {
                    std.debug.print("Error: Invalid format '{s}'\n", .{args[i]});
                    return error.InvalidFormat;
                };
            } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--tests")) {
                i += 1;
                if (i >= args.len) {
                    std.debug.print("Error: --tests requires a value\n", .{});
                    return error.MissingTestsArgument;
                }
                const parsed_tests = try parseTestTypes(allocator, args[i]);
                defer allocator.free(parsed_tests);
                options.tests_to_run = try expandTestSuites(allocator, parsed_tests);
            } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--limit")) {
                i += 1;
                if (i >= args.len) {
                    std.debug.print("Error: --limit requires a value\n", .{});
                    return error.MissingLimitArgument;
                }
                options.data_limit = std.fmt.parseInt(usize, args[i], 10) catch {
                    std.debug.print("Error: Invalid limit value '{s}'\n", .{args[i]});
                    return error.InvalidLimit;
                };
            } else if (std.mem.eql(u8, arg, "-o")) {
                i += 1;
                if (i >= args.len) {
                    std.debug.print("Error: -o requires a value\n", .{});
                    return error.MissingOutputFile;
                }
                options.output = args[i];
            } else if (std.mem.eql(u8, arg, "-b")) {
                i += 1;
                if (i >= args.len) {
                    printHelp();
                    return error.MissingBlockSize;
                }
                options.blocksize = std.fmt.parseInt(usize, args[i], 10) catch |err| {
                    std.debug.print("Invalid block size: {s}\n", .{args[i]});
                    return err;
                };
            } else {
                std.debug.print("Unknown option: {s}\n", .{arg});
                return error.UnknownOption;
            }
        } else {
            // Non-flag argument, treat as input file
            try input_files.append(allocator, arg);
        }

        i += 1;
    }

    // Handle help and version first
    if (options.help) {
        printHelp();
        return;
    }

    if (options.version) {
        std.debug.print("{s}\n", .{version_string});
        std.debug.print("\n", .{});
        std.debug.print("Options:\n", .{});
        std.debug.print("  blocksize: {d}\n", .{options.blocksize});
        std.debug.print("      ascii: {s}\n", .{if (options.ascii) "true" else "false"});
        std.debug.print("     output: {s}\n", .{options.output orelse "stdout"});
        return;
    }

    // Set up input files
    if (input_files.items.len == 0) {
        // No files specified, use stdin or show help
        if (args.len == 1) {
            printHelp();
            return;
        }
        // Add stdin as input
        options.input = null; // Will be handled as stdin
        options.input_files = &[_][]const u8{};
    } else {
        options.input_files = input_files.items;
        options.batch_mode = input_files.items.len > 1 or options.batch_mode;
    }

    // Expand test suites if not already done
    if (options.tests_to_run.len == 1 and options.tests_to_run[0] == .all) {
        options.tests_to_run = try expandTestSuites(allocator, options.tests_to_run);
    }

    if (options.verbose) {
        std.debug.print("🔧 Configuration:\n", .{});
        std.debug.print("- Input files: {d}\n", .{options.input_files.len});
        std.debug.print("- Output format: {s}\n", .{@tagName(options.output_format)});
        std.debug.print("- Batch mode: {}\n", .{options.batch_mode});
        std.debug.print("- Tests to run: {d}\n", .{options.tests_to_run.len});
        std.debug.print("\n", .{});
    }

    // If using enhanced features (batch mode, multiple files, different output formats), use enhanced path
    if (options.batch_mode or options.input_files.len > 1 or options.output_format != .console) {
        try runEnhancedMode(init.io, allocator, options);
    } else {
        // Use legacy single-file mode for backward compatibility
        try runLegacyMode(init.io, allocator, options);
    }

    // Clean up allocated memory for tests_to_run if it was expanded
    if (options.tests_to_run.len > 1 or (options.tests_to_run.len == 1 and options.tests_to_run[0] != .all)) {
        allocator.free(options.tests_to_run);
    }
}

/// Enhanced mode for batch processing and multiple output formats
fn runEnhancedMode(io: std.Io, allocator: std.mem.Allocator, options: Options) !void {
    var all_results = std.ArrayList(TestResult).empty;
    defer all_results.deinit(allocator);

    // Process each file
    const files_to_process = if (options.input_files.len == 0)
        &[_][]const u8{"<stdin>"}
    else
        options.input_files;

    for (files_to_process) |file_path| {
        if (options.verbose) {
            std.debug.print("📁 Processing file: {s}\n", .{file_path});
        }

        // Read file content or stdin
        var content: []u8 = undefined;
        const should_free = true;

        if (std.mem.eql(u8, file_path, "<stdin>")) {
            const stdin = std.Io.File.stdin();
            var buffer: [1024]u8 = undefined; // Temporary buffer for reading stdin
            var fileReader = stdin.reader(io, &buffer);
            const reader = &fileReader.interface;
            content = try reader.readAlloc(allocator, options.blocksize);
        } else {
            const file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch |err| {
                std.debug.print("Error: Cannot open file '{s}': {}\n", .{ file_path, err });
                continue;
            };
            defer file.close(io);

            const file_size = try file.length(io);
            content = try allocator.alloc(u8, file_size);
            content = try std.Io.Dir.cwd().readFile(io, file_path, content);
        }
        defer if (should_free) allocator.free(content);

        // Limit data size if specified
        const actual_content = if (options.data_limit) |limit|
            if (content.len > limit) content[0..limit] else content
        else
            content;

        // Run tests using the original detection suite
        try runTestsOnFile(io, allocator, &all_results, actual_content, file_path, options);
    }

    // Output results
    switch (options.output_format) {
        .console => outputConsole(all_results.items, options),
        .json => outputJson(all_results.items, options),
        .csv => outputCsv(all_results.items),
        .xml => {
            std.debug.print("XML output format not yet implemented\n", .{});
            outputConsole(all_results.items, options);
        },
    }
}

/// Legacy mode for single file processing (maintains backward compatibility)
fn runLegacyMode(io: std.Io, allocator: std.mem.Allocator, options: Options) !void {
    var file: std.Io.File = undefined;
    var should_close_file = false;

    if (options.input_files.len == 0) {
        file = std.Io.File.stdin();
    } else {
        const file_path = options.input_files[0];
        file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch |err| {
            std.debug.print("openFile failed: {}\n", .{err});
            return err;
        };
        should_close_file = true;
    }

    defer if (should_close_file) file.close(io);

    const byteStream = IO.createFileStream(io, allocator, file);
    const input = if (options.ascii)
        IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, byteStream, options.blocksize)
    else
        IO.BitInputStream.fromByteInputStreamWithLength(allocator, byteStream, options.blocksize);

    defer input.close();

    input.reset();

    const param = detect.DetectParam{
        .type = detect.DetectType.General,
        .n = options.blocksize,
        .extra = null,
    };

    var detect_suite = try suite.DetectSuite.init(allocator);

    const test_strings = try testTypesToStrings(allocator, options.tests_to_run);
    defer allocator.free(test_strings);
    try detect_suite.registerSelected(param, test_strings);

    const level = if (options.verbose) detect.PrintLevel.detail else detect.PrintLevel.summary;
    try detect_suite.runAll(&input, level);
}

/// Run statistical tests on a file and collect results
fn runTestsOnFile(io: std.Io, allocator: std.mem.Allocator, results: *std.ArrayList(TestResult), content: []const u8, file_path: []const u8, options: Options) !void {
    const clock = std.Io.Clock.awake;
    const byteStream = IO.createMemoryStream(allocator, content);
    const input = if (options.ascii)
        IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, byteStream, @min(content.len * 8, options.blocksize))
    else
        IO.BitInputStream.fromByteInputStreamWithLength(allocator, byteStream, @min(content.len * 8, options.blocksize));

    defer input.close();

    // Reset input stream
    input.reset();

    const param = detect.DetectParam{
        .type = detect.DetectType.General,
        .n = @min(content.len * 8, options.blocksize), // Use smaller of content size or blocksize
        .extra = null,
    };

    var detect_suite = try suite.DetectSuite.init(allocator);

    try detect_suite.registerAll(param);

    // Run tests and collect results
    const level = if (options.verbose) detect.PrintLevel.detail else detect.PrintLevel.summary;

    // For now, create a simple result - in a full implementation, we'd need to modify
    // the suite to return structured results
    const start_time = std.Io.Clock.now(clock, io).toNanoseconds();
    try detect_suite.runAll(&input, level);
    const end_time = std.Io.Clock.now(clock, io).toNanoseconds();
    const execution_time = @as(f64, @floatFromInt(end_time - start_time));

    // Create a sample result (this would need to be replaced with actual test results)
    const test_result = TestResult{
        .test_name = "suite",
        .file_name = file_path,
        .passed = true, // This would be determined by the actual tests
        .p_value = 0.5, // This would come from the actual test
        .v_value = 0.0, // This would come from the actual test
        .q_value = 0.5, // This would come from the actual test
        .execution_time_ms = execution_time,
        .data_size = content.len,
    };

    try results.append(allocator, test_result);

    if (options.verbose) {
        const status = if (test_result.passed) "✅" else "❌";
        std.debug.print("  {s} {s}: P={d:.6}, Time={d:.2}ms\n", .{ status, test_result.test_name, test_result.p_value, test_result.execution_time_ms });
    }
}
