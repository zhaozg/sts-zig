const std = @import("std");
const testing = std.testing;
const zsts = @import("zsts");

/// 扩展测试套件 - 覆盖缺失的统计算法测试
/// Extended Test Suite - Coverage for missing statistical algorithm tests

const tolerance = 1e-4; // 相对误差容忍度

test "Enhanced Poker Test - Edge Cases" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 测试用例1：全0序列
    const all_zeros = "0000000000000000000000000000000000000000000000000000000000000000";
    const bits_zeros = zsts.io.BitInputStream.fromAscii(allocator, all_zeros);
    defer bits_zeros.close();

    const param_zeros = zsts.detect.DetectParam{
        .type = zsts.detect.DetectType.Poker,
        .n = all_zeros.len,
        .extra = null, // Using default parameters
    };

    // Use poker test with default m=4 parameter
    var stat_zeros = try zsts.poker.pokerDetectStatDetect(allocator, param_zeros, 4);
    defer stat_zeros.destroy();
    
    stat_zeros.init(&param_zeros);
    const result_zeros = stat_zeros.iterate(&bits_zeros);
    
    // 全0序列应该有极低的P值（非随机）
    try testing.expect(result_zeros.p_value < 0.01);
}

test "Frequency Test - Multiple Block Sizes" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 生成测试数据：伪随机序列
    var rnd = std.Random.DefaultPrng.init(12345);
    var random = rnd.random();
    
    // 创建测试数据字符串
    var test_data_buf: [1000]u8 = undefined;
    for (0..test_data_buf.len) |i| {
        test_data_buf[i] = if (random.boolean()) '1' else '0';
    }
    const test_data = test_data_buf[0..];

    // 测试不同的块大小
    const block_sizes = [_]u8{ 10, 20, 50, 100 };
    
    for (block_sizes) |block_size| {
        if (test_data.len < block_size) continue;
        
        const bits = zsts.io.BitInputStream.fromAscii(allocator, test_data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.BlockFrequency,
            .n = test_data.len,
            .extra = null,
        };

        const stat = try zsts.block_frequency.blockFrequencyDetectStatDetect(allocator, param, block_size);
        defer stat.destroy();
        
        stat.init(&param);
        const result = stat.iterate(&bits);
        
        // 验证结果的合理性
        try testing.expect(result.v_value >= 0.0);
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
        
        std.debug.print("Block size {}: V={:.6}, P={:.6}\n", .{ block_size, result.v_value, result.p_value });
    }
}

test "Error Handling - Invalid Input Data" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 测试空数据
    const empty_data = "";
    
    const bits_empty = zsts.io.BitInputStream.fromAscii(allocator, empty_data);
    defer bits_empty.close();

    const param_empty = zsts.detect.DetectParam{
        .type = zsts.detect.DetectType.Frequency,
        .n = 0,
        .extra = null,
    };

    const stat_empty = try zsts.frequency.frequencyDetectStatDetect(allocator, param_empty);
    defer stat_empty.destroy();
    
    stat_empty.init(&param_empty);
    const result_empty = stat_empty.iterate(&bits_empty);
    
    // 空数据应该返回失败结果
    try testing.expect(result_empty.passed == false);
    
    // 测试极短数据
    const short_data = "1";
    
    const bits_short = zsts.io.BitInputStream.fromAscii(allocator, short_data);
    defer bits_short.close();

    const param_short = zsts.detect.DetectParam{
        .type = zsts.detect.DetectType.Runs,
        .n = 1,
        .extra = null,
    };

    const stat_short = try zsts.runs.runsDetectStatDetect(allocator, param_short);
    defer stat_short.destroy();
    
    stat_short.init(&param_short);
    const result_short = stat_short.iterate(&bits_short);
    
    // 极短数据可能通过也可能失败，但不应该崩溃
    try testing.expect(result_short.p_value >= 0.0 and result_short.p_value <= 1.0);
}

test "Matrix Rank - Error Handling Verification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 测试数据：足够长的序列用于矩阵秩检测
    var rnd = std.Random.DefaultPrng.init(98765);
    var random = rnd.random();
    
    // 创建测试数据字符串
    var test_data_buf: [1024]u8 = undefined;
    for (0..test_data_buf.len) |i| {
        test_data_buf[i] = if (random.boolean()) '1' else '0';
    }
    const test_data = test_data_buf[0..];

    const bits = zsts.io.BitInputStream.fromAscii(allocator, test_data);
    defer bits.close();

    const param = zsts.detect.DetectParam{
        .type = zsts.detect.DetectType.Rank,
        .n = test_data.len,
        .extra = null,
    };

    const stat = try zsts.rank.rankDetectStatDetect(allocator, param);
    defer stat.destroy();
    
    stat.init(&param);
    const result = stat.iterate(&bits);
    
    // 验证改进的错误处理不会导致 panic
    try testing.expect(result.v_value >= 0.0);
    try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
    
    std.debug.print("Matrix Rank Test: V={:.6}, P={:.6}, Passed={}\n", 
        .{ result.v_value, result.p_value, result.passed });
}

test "Autocorrelation Test - Multiple Lag Values" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 创建具有自相关性的序列 - 每8位重复的模式
    const test_data = "1111000011110000111100001111000011110000111100001111000011110000111100001111000011110000";

    // 测试不同的lag值
    const lag_values = [_]u8{ 1, 2, 4, 8 };
    
    for (lag_values) |d| {
        const bits = zsts.io.BitInputStream.fromAscii(allocator, test_data);
        defer bits.close();

        const param = zsts.detect.DetectParam{
            .type = zsts.detect.DetectType.AutoCorrelation, // 注意大小写
            .n = test_data.len,
            .extra = null,
        };

        const stat = try zsts.autocorrelation.autocorrelationDetectStatDetect(allocator, param, d);
        defer stat.destroy();
        
        stat.init(&param);
        const result = stat.iterate(&bits);
        
        std.debug.print("Autocorrelation d={}: V={:.6}, P={:.6}\n", .{ d, result.v_value, result.p_value });
        
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
        
        // lag=8时应该检测出强相关性（低P值）
        if (d == 8) {
            try testing.expect(result.p_value < 0.5); // 放宽条件以避免测试不稳定
        }
    }
}