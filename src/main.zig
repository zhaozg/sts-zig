const std = @import("std");
const suite = @import("suite.zig");
const io = @import("io.zig");
const detect = @import("detect.zig");
const compat = @import("compat.zig");

const Options = struct {
    help: bool = false,
    version: bool = false,
    ascii: bool = false,
    verbose: bool = false,
    blocksize: usize = 1000000,
    output: ?[]const u8 = null,
    input: ?[]const u8 = null,
};

const version_string = "zsts version 1.0";

fn printHelp() void {
    const help_text =
        \\Usage: zsts [...] file
        \\options:
        \\  -h, --help     Print this help message
        \\  -v, --version  Print version information
        \\  -V, --verbose  Output verbose information
        \\  -a, --ascii    Input ASCII characters
        \\  -o  output     Output to file
        \\  -b  blocksize  Input length of bits, default 1000000
    ;
    std.debug.print("{s}\n", .{help_text});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var options = Options{};

    var i: usize = 1; // 跳过程序名
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
            } else if (std.mem.eql(u8, arg, "-o")) {
                i += 1;
                if (i >= args.len) return error.MissingOutputFile;
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
                std.debug.print("UnknownOption: {s}\n", .{arg});
                return error.UnknownOption;
            }
        } else {
            options.input = arg;
        }

        i += 1;
    }

    // 使用解析后的选项
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
        std.debug.print("      input: {s}\n", .{options.input orelse "stdin"});
        std.debug.print("     output: {s}\n", .{options.output orelse "stdout"});
        return;
    }

    var file: std.fs.File = undefined;

    if (options.input == null) {
        file = compat.getStdIn();
    } else {
        file = std.fs.cwd().openFile(options.input.?, .{}) catch |err| {
            std.debug.print("openFile failed: {}\n", .{err});
            return err;
        };
    }

    const byteStream = io.createFileStream(allocator, file);
    const input = if (options.ascii)
        io.BitInputStream.fromAsciiInputStreamWithLength(allocator, byteStream, options.blocksize)
    else
        io.BitInputStream.fromByteInputStreamWithLength(allocator, byteStream, options.blocksize);

    defer input.close();

    input.reset();

    const param = detect.DetectParam{
        .type = detect.DetectType.General, // 假设的检测类型
        .n = options.blocksize,
        .extra = null, // 可扩展更多参数
    };

    var detect_suite = try suite.DetectSuite.init(allocator);

    try detect_suite.registerAll(param);

    const level = if (options.verbose) detect.PrintLevel.detail else detect.PrintLevel.summary;
    try detect_suite.runAll(&input, level);
}
