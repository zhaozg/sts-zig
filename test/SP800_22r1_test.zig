const std = @import("std");
const zsts = @import("zsts");

const detect = zsts.detect;
const io = zsts.io;

const epsilon =
    "1100110000010101011011000100110011100000000000100100110101010001" ++
    "0001001111010110100000001101011111001100111001101101100010110010";

const epsilon100 = "11001001000011111101101010100010001000010110100011" ++
                   "00001000110100110001001100011001100010100010111000";

const epsilon20 = "10100100101110010110";

const tolerance = 0.000001;

test "OverlappingTemplateMatch" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data/data.e", .{});
    defer file.close();

    const n = 1000000; // 100000 比特
    const inputStream = io.InputStream.fromFile(file);
    const bits = io.BitInputStream.fromAsciiInputStreamWithLength(inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.OverlappingTemplate,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const overtemp = try zsts.overlappingTemplate.overlappingTemplateDetectStatDetect(allocator, param);
    overtemp.init(&param);
    const result = overtemp.iterate(&bits);

    std.debug.print("overlappingTemplate: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    // NOTE: not match with 2.8.8
    try std.testing.expectApproxEqAbs(result.v_value, 7.949564, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.159037, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.159037, tolerance);
}


test "NonOverlappingTemplateMatch" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data/data.sha1", .{});
    defer file.close();

    const n = 1000000; // 100000 比特
    const inputStream = io.InputStream.fromFile(file);
    const bits = io.BitInputStream.fromByteInputStreamWithLength(inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.NonOverlappingTemplate,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const nonovertemp = try zsts.nonOverlappingTemplate.nonOverlappingTemplateDetectStatDetect(allocator, param);
    nonovertemp.init(&param);
    const result = nonovertemp.iterate(&bits);

    std.debug.print("NonOverlappingTemplate: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    const results = @as(*zsts.nonOverlappingTemplate.NonOverlappingTemplateResult,
      @alignCast(@ptrCast(result.extra.?)));

    for (0..results.n) |i| {
        std.debug.print("\tState {d:3}: {}{}{}{}{}{}{}{}{} passed={s}, V = {d:10.6} P = {d:.6}\n",
            .{
                i,
                results.template[i][0], results.template[i][1], results.template[i][2],
                results.template[i][3], results.template[i][4], results.template[i][5],
                results.template[i][6], results.template[i][7], results.template[i][8],
                if (results.passed[i]) "Yes" else "No ",
                results.v_value[i],
                results.p_value[i],
            });
    }

    try std.testing.expect(result.passed == false);
    try std.testing.expectApproxEqAbs(result.v_value, 25.579429, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.001239, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.001239, tolerance);
}

test "RandomExcursion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data/data.e", .{});
    defer file.close();

    const n = 1000000; // 100000 比特
    const inputStream = io.InputStream.fromFile(file);
    const bits = io.BitInputStream.fromAsciiInputStreamWithLength(inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.RandomExcursions,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    // const m: u8 = 10; // 块大小
    const randomExcursions = try zsts.randomExcursions.randomExcursionsDetectStatDetect(allocator, param);
    randomExcursions.init(&param);
    const result = randomExcursions.iterate(&bits);

    std.debug.print("randomExcursions: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    const randomExcursionsResult: *zsts.randomExcursions.RandomExcursionsResult =
       @alignCast(@ptrCast(result.extra.?));

    for (0..randomExcursionsResult.passed.len) |i| {
        std.debug.print("\tState {d:>3}: passed={s}, V = {d:10.6} P = {d:.6}\n",
            .{
                i,
                if (randomExcursionsResult.passed[i]) "Yes" else "No ",
                randomExcursionsResult.v_value[i],
                randomExcursionsResult.p_value[i],
            });
    }

    try std.testing.expect(result.passed == false);
    try std.testing.expectApproxEqAbs(result.v_value, 15.692617, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.007779, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.007779, tolerance);
}

test "RandomExcursionVariant" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data/data.e", .{});
    defer file.close();

    const n = 1000000; // 100000 比特
    const inputStream = io.InputStream.fromFile(file);
    const bits = io.BitInputStream.fromAsciiInputStreamWithLength(inputStream, n);
    defer bits.close();

    try std.testing.expect(bits.len() == n); // 确保长度是 4 的倍数
    const param = detect.DetectParam{
        .type = detect.DetectType.RandomExcursionsVariant,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.randomExcursionsVariant.randomExcursionsVariantDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(&bits);

    std.debug.print("randomExcursionsVariant: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    const randomExcursionsVarResult: *zsts.randomExcursionsVariant.RandomExcursionsVariantResult =
       @alignCast(@ptrCast(result.extra.?));
    for (0..randomExcursionsVarResult.passed.len) |i| {
        std.debug.print("\tState {d:>3}: passed={s}, V = {d:10.6} P = {d:.6}\n",
            .{
                i,
                if (randomExcursionsVarResult.passed[i]) "Yes" else "No ",
                randomExcursionsVarResult.v_value[i],
                randomExcursionsVarResult.p_value[i],
            });
    }

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 1.049209, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.137861, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.137861, tolerance);
}

test "Serial" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data/data.e", .{});
    defer file.close();

    const n = 1000000; // 100000 比特
    const inputStream = io.InputStream.fromFile(file);
    const bits = io.BitInputStream.fromAsciiInputStreamWithLength(inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.Serial,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.serial.serialDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(&bits);

    try std.testing.expect(result.passed == true);
    std.debug.print("Serial: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.339764, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.843764, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.561915, tolerance);
}
