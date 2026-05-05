const std = @import("std");
const zsts = @import("zsts");

const detect = zsts.detect;
const IO = zsts.io;

const tolerance = 0.000001;

test "OverlappingTemplateMatch" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.OverlappingTemplate,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const overtemp = try zsts.overlappingTemplate.overlappingTemplateDetectStatDetect(allocator, param);
    overtemp.init(&param);
    defer overtemp.destroy();
    const result = overtemp.iterate(&bits);
    defer result.deinit(allocator);
    overtemp.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    // NOTE: not match with 2.8.8
    try std.testing.expectApproxEqAbs(result.v_value, 7.949564, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.159037, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.159037, tolerance);
}

test "NonOverlappingTemplateMatch" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.sha1", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromByteInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.NonOverlappingTemplate,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const nonovertemp = try zsts.nonOverlappingTemplate.nonOverlappingTemplateDetectStatDetect(allocator, param);
    nonovertemp.init(&param);
    defer nonovertemp.destroy();
    const result = nonovertemp.iterate(&bits);
    defer result.deinit(allocator);
    nonovertemp.print(&result, .detail);

    try std.testing.expect(result.passed == false);
    try std.testing.expectApproxEqAbs(result.v_value, 25.579429, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.001239, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.001239, tolerance);
}

test "RandomExcursion" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.RandomExcursions,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    // const m: u8 = 10; // 块大小
    const randomExcursions = try zsts.randomExcursions.randomExcursionsDetectStatDetect(allocator, param);
    randomExcursions.init(&param);
    defer randomExcursions.destroy();
    const result = randomExcursions.iterate(&bits);
    defer result.deinit(allocator);
    randomExcursions.print(&result, .detail);

    try std.testing.expect(result.passed == false);
    try std.testing.expectApproxEqAbs(result.v_value, 15.692617, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.007779, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.007779, tolerance);
}

test "RandomExcursionVariant" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    try std.testing.expect(bits.len() == n); // 确保长度是 4 的倍数
    const param = detect.DetectParam{
        .type = detect.DetectType.RandomExcursionsVariant,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.randomExcursionsVariant.randomExcursionsVariantDetectStatDetect(allocator, param);
    stat.init(&param);
    defer stat.destroy();
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 1.049209, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.137861, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.137861, tolerance);
}

test "Serial" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.Serial,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.serial.serialDetectStatDetect(allocator, param);
    stat.init(&param);
    defer stat.destroy();
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.339764, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.843764, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.561915, tolerance);
}
