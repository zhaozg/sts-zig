const std = @import("std");
const zsts = @import("zsts");

const detect = zsts.detect;
const IO = zsts.io;

const frequency = zsts.frequency;
const block_frequency = zsts.block_frequency;
const poker = zsts.poker;

const epsilon =
    "1100110000010101011011000100110011100000000000100100110101010001" ++
    "0001001111010110100000001101011111001100111001101101100010110010";

const epsilon100 = "11001001000011111101101010100010001000010110100011" ++
    "00001000110100110001001100011001100010100010111000";
const tolerance = 0.000001;

test "frequency" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.Frequency,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const freq = try frequency.frequencyDetectStatDetect(allocator, param);
    defer freq.destroy();
    freq.init(&param);
    const result = freq.iterate(&bits);
    defer result.deinit(allocator);
    freq.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, -1.237437, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.215925, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.892038, tolerance);
}

test "block frequency" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon100);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.BlockFrequency,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 10; // 块大小
    const freq = try block_frequency.blockFrequencyDetectStatDetect(allocator, param, m);
    defer freq.destroy();
    freq.init(&param);
    const result = freq.iterate(&bits);
    defer result.deinit(allocator);
    freq.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 7.2, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.706438, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.706438, tolerance);
}

test "poker" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    try std.testing.expect(bits.len() == 128); // 确保长度是 4 的倍数
    const param = detect.DetectParam{
        .type = detect.DetectType.Poker,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 4; // 块大小
    const stat = try poker.pokerDetectStatDetect(allocator, param, m);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 19.000000, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.213734, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.213734, tolerance);
}

test "Overlapping Subsequence" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.OverlappingSequency,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 2; // 块大小
    const stat = try zsts.overlappingseq.overlappingSequencyDetectStatDetect(allocator, param, m);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 1.656250, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.436868, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.723674, tolerance);
}

test "Runs" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.Runs,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runs.runsDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.494817, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.620729, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.310364, tolerance);
}

test "Run Distribution" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.RunDistribution,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runDist.runDistributionDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.060606, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.970152, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.970152, tolerance);
}

test "Longest Run" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.LongestRun,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.longestRun.longestRunDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    var result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 4.882605, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.180598, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.180598, tolerance);

    const results: *zsts.longestRun.LongestRunResult = @ptrCast(@alignCast(result.extra.?));

    try std.testing.expect(results.passed[0] == true);
    try std.testing.expectApproxEqAbs(results.v_value[0], 0.842410, tolerance);
    try std.testing.expectApproxEqAbs(results.p_value[0], 0.839299, tolerance);
    try std.testing.expectApproxEqAbs(results.q_value[0], 0.839299, tolerance);

    try std.testing.expect(results.passed[1] == true);
    try std.testing.expectApproxEqAbs(results.v_value[1], 4.882605, tolerance);
    try std.testing.expectApproxEqAbs(results.p_value[1], 0.180598, tolerance);
    try std.testing.expectApproxEqAbs(results.q_value[1], 0.180598, tolerance);
}

test "Binary Derivative" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.BinaryDerivative,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.binaryDerivative.binaryDerivativeDetectStatDetect(allocator, param, 3);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, -2.057183, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.039669, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.980166, tolerance);
}

test "autocorrelation" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.AutoCorrelation,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.autocorrelation.autocorrelationDetectStatDetect(allocator, param, 1);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.266207, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.790080, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.395040, tolerance);
}

test "Rank" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(std.testing.io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.Rank,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.rank.rankDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 2.358278, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.307543, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.307543, tolerance);
}

test "cumulative_sums" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon100);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.CumulativeSums,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.cumulativeSums.cumulativeSumsDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    var result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    const statResult: *zsts.cumulativeSums.CumulativeSumsResult = @ptrCast(@alignCast(result.extra.?));

    try std.testing.expect(statResult.passed[0] == true);
    try std.testing.expectApproxEqAbs(statResult.v_value[0], 0.0, tolerance);
    try std.testing.expectApproxEqAbs(statResult.p_value[0], 0.219194, tolerance);
    try std.testing.expectApproxEqAbs(statResult.q_value[0], 0.219194, tolerance);

    try std.testing.expect(statResult.passed[1] == true);
    try std.testing.expectApproxEqAbs(statResult.v_value[1], 0.0, tolerance);
    try std.testing.expectApproxEqAbs(statResult.p_value[1], 0.114866, tolerance);
    try std.testing.expectApproxEqAbs(statResult.q_value[1], 0.114866, tolerance);
}

test "ApproxEntropy" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon100);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.ApproxEntropy,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.approximateEntropy.approxEntropyDetectStatDetect(allocator, param, 2);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 5.550792, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.235301, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.235301, tolerance);
}

test "Maurer Universal" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    const file = try std.Io.Dir.cwd().openFile(io, "data/data.e", .{});
    defer file.close(io);

    const n = 1000000; // 100000 比特
    const inputStream = IO.InputStream.fromFile(io, allocator, file);
    const bits = IO.BitInputStream.fromAsciiInputStreamWithLength(allocator, inputStream, n);
    defer bits.close();

    const param = detect.DetectParam{
        .type = detect.DetectType.MaurerUniversal,
        .n = n, // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.maurerUniversal.maurerUniversalDetectStatDetect(allocator, param, 7, 1280);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 1.074569, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.282568, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.141284, tolerance);
}

test "DFT" {
    const allocator = std.testing.allocator;

    const bits = IO.BitInputStream.fromAscii(allocator, epsilon100);
    defer bits.close();

    try std.testing.expect(bits.len() == 100);

    const param = detect.DetectParam{
        .type = detect.DetectType.Dft,
        .n = bits.len(), // 测试数据长度
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.dft.dftDetectStatDetect(allocator, param);
    defer stat.destroy();
    stat.init(&param);
    const result = stat.iterate(&bits);
    defer result.deinit(allocator);
    stat.print(&result, .detail);

    try std.testing.expect(result.passed == true);
    try std.testing.expectApproxEqAbs(result.v_value, 0.447214, tolerance);
    try std.testing.expectApproxEqAbs(result.p_value, 0.654721, tolerance);
    try std.testing.expectApproxEqAbs(result.q_value, 0.327360, tolerance);
}
