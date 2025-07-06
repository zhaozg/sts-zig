const std = @import("std");
const zsts = @import("zsts");

const detect = zsts.detect;
const io = zsts.io;

const frequency = zsts.frequency;
const block_frequency = zsts.block_frequency;
const poker = zsts.poker;

const epsilon =
    "1100110000010101011011000100110011100000000100100110101010001000" ++
    "1001111010110100000000110101111110011001110011011011000101100100";

test "frequency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();


    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.Frequency,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const freq = try frequency.frequencyDetectStatDetect(allocator, param);
    freq.init(&param);
    const result = freq.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("Frequency: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= -1.237437);
    try std.testing.expect(result.p_value >= 0.215925);
    try std.testing.expect(result.q_value <= 0.892038);
}

test "block frequency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();


    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.BlockFrequency,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 10; // 块大小
    const freq = try block_frequency.blockFrequencyDetectStatDetect(allocator, param, m);
    freq.init(&param);
    const result = freq.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("BlockFrequency: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= 7.6);
    try std.testing.expect(result.p_value >= 0.184443);
    try std.testing.expect(result.q_value <= 0.184444);
}

test "poker" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.Poker,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 4; // 块大小
    const stat = try poker.pokerDetectStatDetect(allocator, param, m);
    stat.init(&param);
    const result = stat.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("Poker(m={d}): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{m, result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= 11.000000);
    try std.testing.expect(result.p_value >= 0.203903);
    try std.testing.expect(result.q_value <= 0.203904);
}

test "Overlapping Subsequence" {
}

test "Runs" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.Runs,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runs.runsDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("Runs: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= 0.457006);
    try std.testing.expect(result.p_value >= 0.647665);
    try std.testing.expect(result.q_value <= 0.323834);
}

test "Run Distribution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.RunDistribution,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runDist.runDistributionDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("Run Distribution: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= 0.303030);
    try std.testing.expect(result.p_value >= 0.859404);
    try std.testing.expect(result.q_value <= 0.859406);
}

test "Run Distribution" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.RunDistribution,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runDist.runDistributionDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    try std.testing.expect(result.passed == true);
    std.debug.print("Run Distribution: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.v_value >= 0.303030);
    try std.testing.expect(result.p_value >= 0.859404);
    try std.testing.expect(result.q_value <= 0.859406);
}
