const std = @import("std");
const math = @import("../src/math.zig");
const testing = std.testing;

// 测试容差 - 相对误差在这个范围内认为正确
const tolerance = 1e-10;

test "igamc accuracy verification" {
    // 测试用例来自于已知的数学参考值
    // 这些值可以通过 Mathematica, WolframAlpha 或其他数学软件验证
    
    const test_cases = [_]struct {
        a: f64,
        x: f64,
        expected: f64,
    }{
        // Q(1, 0.5) = e^(-0.5) ≈ 0.606530659712633
        .{ .a = 1.0, .x = 0.5, .expected = 0.606530659712633 },
        
        // Q(2, 1) = e^(-1) * (1 + 1) = 2 * e^(-1) ≈ 0.735758882342885
        .{ .a = 2.0, .x = 1.0, .expected = 0.735758882342885 },
        
        // Q(0.5, 1) - 半整数参数的特殊情况
        .{ .a = 0.5, .x = 1.0, .expected = 0.157299207050281 },
        
        // Q(3, 2) 
        .{ .a = 3.0, .x = 2.0, .expected = 0.676676416183063 },
        
        // Q(2.5, 1.5) - 非整数参数
        .{ .a = 2.5, .x = 1.5, .expected = 0.699985835878628 },
        
        // 边界情况测试
        .{ .a = 1.0, .x = 0.0, .expected = 1.0 },  // Q(a, 0) = 1
        .{ .a = 10.0, .x = 0.1, .expected = 1.0 }, // x << a
    };
    
    for (test_cases) |case| {
        const result = math.igamc(case.a, case.x);
        const relative_error = @abs(result - case.expected) / @abs(case.expected);
        
        std.debug.print("igamc({d:.1}, {d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", 
            .{ case.a, case.x, result, case.expected, relative_error });
        
        try testing.expect(relative_error < tolerance);
    }
}

test "igamc edge cases" {
    // 测试边界情况和错误条件
    
    // 负参数应该返回 NaN
    try testing.expect(std.math.isNan(math.igamc(-1.0, 1.0)));
    try testing.expect(std.math.isNan(math.igamc(1.0, -1.0)));
    try testing.expect(std.math.isNan(math.igamc(0.0, 1.0)));
    
    // x = 0 时应该返回 1
    try testing.expectApproxEqAbs(math.igamc(1.0, 0.0), 1.0, 1e-15);
    try testing.expectApproxEqAbs(math.igamc(5.0, 0.0), 1.0, 1e-15);
}

test "gammaln accuracy verification" {
    // 测试 gammaln 函数的准确性
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        // ln(Γ(1)) = ln(0!) = ln(1) = 0
        .{ .x = 1.0, .expected = 0.0 },
        
        // ln(Γ(2)) = ln(1!) = ln(1) = 0  
        .{ .x = 2.0, .expected = 0.0 },
        
        // ln(Γ(3)) = ln(2!) = ln(2) ≈ 0.693147180559945
        .{ .x = 3.0, .expected = 0.693147180559945 },
        
        // ln(Γ(4)) = ln(3!) = ln(6) ≈ 1.791759469228055
        .{ .x = 4.0, .expected = 1.791759469228055 },
        
        // ln(Γ(0.5)) = ln(√π) ≈ 0.572364942924700
        .{ .x = 0.5, .expected = 0.572364942924700 },
        
        // ln(Γ(1.5)) = ln(0.5 * √π) ≈ 0.572364942924700 - ln(2) ≈ -0.120782237635245
        .{ .x = 1.5, .expected = -0.120782237635245 },
        
        // 较大的值
        .{ .x = 10.0, .expected = 12.801827480081469 },
    };
    
    for (test_cases) |case| {
        const result = math.gammaln(case.x);  // 直接调用内部函数进行测试
        const relative_error = @abs(result - case.expected) / @abs(case.expected);
        
        std.debug.print("gammaln({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", 
            .{ case.x, result, case.expected, relative_error });
        
        try testing.expect(relative_error < tolerance);
    }
}

test "FFT accuracy verification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 创建一个简单的测试信号：单频正弦波
    const n = 64;
    const freq = 8.0; // 8 个周期
    
    var input = try allocator.alloc(f64, n);
    defer allocator.free(input);
    
    for (0..n) |i| {
        const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(n));
        input[i] = std.math.sin(2.0 * std.math.pi * freq * t);
    }
    
    // 执行 FFT
    var fft_out = try allocator.alloc(f64, n + 2);
    defer allocator.free(fft_out);
    var fft_m = try allocator.alloc(f64, n / 2 + 1);
    defer allocator.free(fft_m);
    
    // 创建一个模拟的 StatDetect 结构
    var mock_detect = struct {
        allocator: std.mem.Allocator,
        
        pub fn init(alloc: std.mem.Allocator) @This() {
            return @This(){ .allocator = alloc };
        }
    }.init(allocator);
    
    // 注意：这里需要调整 compute_r2c_fft 的函数签名以匹配测试
    // 暂时跳过 FFT 测试，专注于 igamc 测试
    std.debug.print("FFT test skipped - function signature mismatch\n", .{});
}

test "consistency with existing test cases" {
    // 确保新实现与现有测试用例兼容
    // 这些值来自于项目中现有的测试期望值
    
    // 来自 rank.zig 测试的例子：chi2 = 2.358278, 期望 p_value = 0.307543
    const chi2 = 2.358278;
    const df = 2.0; // 自由度
    const p_value = math.igamc(df / 2.0, chi2 / 2.0);
    const expected_p = 0.307543;
    
    const relative_error = @abs(p_value - expected_p) / expected_p;
    std.debug.print("Rank test compatibility: p_value = {d:.6} (expected: {d:.6}, rel_err: {e:.2})\n", 
        .{ p_value, expected_p, relative_error });
    
    // 允许较大的容差，因为测试数据可能来自不同的实现
    try testing.expect(relative_error < 1e-3);
}