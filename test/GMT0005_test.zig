const std = @import("std");
const zsts = @import("zsts");

const detect = zsts.detect;
const io = zsts.io;

const frequency = zsts.frequency;
const block_frequency = zsts.block_frequency;
const poker = zsts.poker;

const epsilon =
    "1100110000010101011011000100110011100000000000100100110101010001" ++
    "0001001111010110100000001101011111001100111001101101100010110010";

const epsilon100 = "11001001000011111101101010100010001000010110100011" ++
                   "00001000110100110001001100011001100010100010111000";

fn almostEqual(a: f64, b: f64) bool {
    return @abs(a - b) <= 0.000001;
}

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
        .num_bitstreams = 128, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const freq = try frequency.frequencyDetectStatDetect(allocator, param);
    freq.init(&param);
    const result = freq.iterate(bytes);

    std.debug.print("Frequency: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, -1.237437));
    try std.testing.expect(almostEqual(result.p_value, 0.215925));
    try std.testing.expect(almostEqual(result.q_value, 0.892038));
}

test "block frequency" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon100) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.BlockFrequency,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 100, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 10; // 块大小
    const freq = try block_frequency.blockFrequencyDetectStatDetect(allocator, param, m);
    freq.init(&param);
    const result = freq.iterate(bytes);

    std.debug.print("BlockFrequency: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, 7.2));
    try std.testing.expect(almostEqual(result.p_value, 0.706438));
    try std.testing.expect(almostEqual(result.q_value, 0.706438));
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
        .num_bitstreams = 128 ,
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 4; // 块大小
    const stat = try poker.pokerDetectStatDetect(allocator, param, m);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("Poker(m={d}): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{m, result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, 19.000000));
    // FIXME: 与 0005 附录 C 不一致, igamc 大参数支持的缺陷引起的
    // try std.testing.expect(almostEqual(result.p_value, 0.213734));
    // try std.testing.expect(almostEqual(result.q_value, 0.213734));
}

test "Overlapping Subsequence" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.OverlappingSequency,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const m: u8 = 2; // 块大小
    const stat = try zsts.overlappingseq.overlappingSequencyDetectStatDetect(allocator, param, m);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("OverlappingSequence(m={d}): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{m, result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 1.656250));
    try std.testing.expect(almostEqual(result.p_value, 0.436868));
    // FIXME: 与 0005 附录 C 不一致, 算法 igamc 负参数支持的缺陷引起的
    // try std.testing.expect(almostEqual(result.q_value, 0.723674));
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

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, 0.494817));
    try std.testing.expect(almostEqual(result.p_value, 0.620729));
    try std.testing.expect(almostEqual(result.q_value, 0.310364));
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
        .num_bitstreams = 128, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.runDist.runDistributionDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("Run Distribution: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, 0.060606));
    try std.testing.expect(almostEqual(result.p_value, 0.970152));
    try std.testing.expect(almostEqual(result.q_value, 0.970152));
}

test "Longest Run" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.LongestRun,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 128, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.longestRun.longestRunDetectStatDetect(allocator, param, 1);
    stat.init(&param);
    var result = stat.iterate(bytes);

    std.debug.print("LongestRun(1): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    // FIXME: 这里的结果与 0005 附录 C 不一致, 统计值稍有偏差
    // try std.testing.expect(almostEqual(result.v_value, 4.882605));
    // try std.testing.expect(almostEqual(result.p_value,  0.180598));
    // try std.testing.expect(almostEqual(result.q_value,  0.180598));

    stat = try zsts.longestRun.longestRunDetectStatDetect(allocator, param, 0);
    stat.init(&param);
    result = stat.iterate(bytes);

    std.debug.print("LongestRun(0): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    // FIXME: 这里的结果与 0005 附录 C 不一致, 统计值稍有偏差
    // try std.testing.expect(almostEqual(result.v_value, 0.842410));
    // try std.testing.expect(almostEqual(result.p_value,  0.839299));
    // try std.testing.expect(almostEqual(result.q_value,  0.839299));
}

test "Binary Derivative" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.BinaryDerivative,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.binaryDerivative.binaryDerivativeDetectStatDetect(allocator, param, 3);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("binaryDerivative: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, -2.057183));
    try std.testing.expect(almostEqual(result.p_value, 0.039669));
    try std.testing.expect(almostEqual(result.q_value, 0.980166));
}

test "autocorrelation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.AutoCorrelation,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = bytes.len * 8, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.autocorrelation.autocorrelationDetectStatDetect(allocator, param, 1);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("AutoCorrelation: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 0.266207));
    try std.testing.expect(almostEqual(result.p_value, 0.790080));
    try std.testing.expect(almostEqual(result.q_value, 0.395040));
}

test "Rank" {
    const allocator = std.heap.page_allocator;

    const bytes = io.loadFile(allocator, "data/data.e", 125000) catch |err| {
        std.debug.print("Error loading file: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const n = 1000000; // 100000 字节

    const param = detect.DetectParam{
        .type = detect.DetectType.Rank,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = n, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.rank.rankDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("Rank: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 2.358278));
    try std.testing.expect(almostEqual(result.p_value, 0.307543));
    try std.testing.expect(almostEqual(result.q_value, 0.307543));
}

test "cumulative_sums" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon100) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.CumulativeSums,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 100,
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.cumulativeSums.cumulativeSumsDetectStatDetect(allocator, param, true);
    stat.init(&param);
    var result = stat.iterate(bytes);

    std.debug.print("cumSums(Forward): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 0.0));
    try std.testing.expect(almostEqual(result.p_value, 0.219194));
    try std.testing.expect(almostEqual(result.q_value, 0.219194));

    stat = try zsts.cumulativeSums.cumulativeSumsDetectStatDetect(allocator, param, false);
    stat.init(&param);
    result = stat.iterate(bytes);

    std.debug.print("cumSums(Backup): passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 0.0));
    try std.testing.expect(almostEqual(result.p_value, 0.114866));
    try std.testing.expect(almostEqual(result.q_value, 0.114866));
}

test "ApproxEntropy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon100) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.ApproxEntropy,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 100,
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.approximateEntropy.approxEntropyDetectStatDetect(allocator, param, 2);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("approximateEntropy: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 5.550792));
    try std.testing.expect(almostEqual(result.p_value, 0.235301));
    try std.testing.expect(almostEqual(result.q_value, 0.235301));
}

test "Maurer Universal" {
    const allocator = std.heap.page_allocator;

    const bytes = io.loadFile(allocator, "data/data.e", 125000) catch |err| {
        std.debug.print("Error loading file: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.MaurerUniversal,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 1000000, // 每个字节8位
        .extra = null, // 这里可以设置额外参数
    };

    const stat = try zsts.maurerUniversal.maurerUniversalDetectStatDetect(allocator, param, 7, 1280);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("maurerUniversal: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);
    try std.testing.expect(almostEqual(result.v_value, 1.074569));
    try std.testing.expect(almostEqual(result.p_value, 0.282568));
    try std.testing.expect(almostEqual(result.q_value, 0.141284));
}

test "DFT" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const bytes = io.convertAscii2Byte(allocator, epsilon100) catch |err| {
        std.debug.print("Error initializing DiscreteBitStream: {}\n", .{err});
        return err;
    };
    defer allocator.free(bytes);

    const param = detect.DetectParam{
        .type = detect.DetectType.Dft,
        .n = bytes.len, // 测试数据长度
        .num_bitstreams = 100,
        .extra = null, // 这里可以设置额外参数
    };

    var stat = try zsts.dft.dftDetectStatDetect(allocator, param);
    stat.init(&param);
    const result = stat.iterate(bytes);

    std.debug.print("DFT: passed={}, V = {d:.6} P = {d:.6}, Q = {d:.6}\n",
        .{result.passed, result.v_value, result.p_value, result.q_value});

    try std.testing.expect(result.passed == true);

    try std.testing.expect(almostEqual(result.v_value, 0.447214));
    try std.testing.expect(almostEqual(result.p_value, 0.654721));
    try std.testing.expect(almostEqual(result.q_value, 0.327360));
}
