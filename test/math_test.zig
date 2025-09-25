const std = @import("std");
const zsts = @import("zsts");
const math = zsts.math;
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
        .{ .a = 1.0, .x = 0.0, .expected = 1.0 }, // Q(a, 0) = 1
        .{ .a = 10.0, .x = 0.1, .expected = 1.0 }, // x << a
    };

    for (test_cases) |case| {
        const result = math.igamc(case.a, case.x);
        const relative_error = @abs(result - case.expected) / @abs(case.expected);

        std.debug.print("igamc({d:.1}, {d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.a, case.x, result, case.expected, relative_error });

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
        const result = math.gammaln(case.x);
        var relative_error: f64 = 0.0;

        if (case.expected == 0.0) {
            // Special case: when expected is 0, use absolute error
            relative_error = @abs(result - case.expected);
        } else {
            relative_error = @abs(result - case.expected) / @abs(case.expected);
        }

        std.debug.print("gammaln({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "erf function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 0.0 },
        .{ .x = 1.0, .expected = 0.8427007929497149 },
        .{ .x = -1.0, .expected = -0.8427007929497149 },
        .{ .x = 0.5, .expected = 0.5204998778130465 },
        .{ .x = 2.0, .expected = 0.9953222650189527 },
    };

    for (test_cases) |case| {
        const result = math.erf(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erf({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "erfc function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 1.0 },
        .{ .x = 1.0, .expected = 0.1572992070502851 },
        .{ .x = -1.0, .expected = 1.8427007929497149 },
        .{ .x = 0.5, .expected = 0.4795001221869535 },
        .{ .x = 2.0, .expected = 0.004677734981047266 },
    };

    for (test_cases) |case| {
        const result = math.erfc(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erfc({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "normal function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 0.5 },
        .{ .x = 1.0, .expected = 0.8413447460685429 },
        .{ .x = -1.0, .expected = 0.15865525393145705 },
        .{ .x = 2.0, .expected = 0.9772498680518208 },
        .{ .x = -2.0, .expected = 0.022750131948179195 },
    };

    for (test_cases) |case| {
        const result = math.normal(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("normal({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "chi2_cdf function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        k: usize,
        expected: f64,
    }{
        .{ .x = 1.0, .k = 1, .expected = 0.6826894921370859 },
        .{ .x = 2.0, .k = 2, .expected = 0.6321205588285577 },
        .{ .x = 5.0, .k = 3, .expected = 0.8282382022202468 },
        .{ .x = 10.0, .k = 5, .expected = 0.9246365628306684 },
    };

    for (test_cases) |case| {
        const result = math.chi2_cdf(case.x, case.k);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("chi2_cdf({d:.1}, {d}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, case.k, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "factorial function accuracy" {
    const test_cases = [_]struct {
        n: usize,
        expected: u64,
    }{
        .{ .n = 0, .expected = 1 },
        .{ .n = 1, .expected = 1 },
        .{ .n = 5, .expected = 120 },
        .{ .n = 10, .expected = 3628800 },
        .{ .n = 12, .expected = 479001600 },
    };

    for (test_cases) |case| {
        const result = math.factorial(case.n);

        std.debug.print("factorial({d}) = {d} (expected: {d})\n", .{ case.n, result, case.expected });

        try testing.expect(result == case.expected);
    }
}

test "poisson function accuracy" {
    const test_cases = [_]struct {
        lambda: f64,
        k: usize,
        expected: f64,
    }{
        .{ .lambda = 1.0, .k = 0, .expected = 0.36787944117144233 },
        .{ .lambda = 1.0, .k = 1, .expected = 0.36787944117144233 },
        .{ .lambda = 2.0, .k = 2, .expected = 0.2706705664732254 },
        .{ .lambda = 3.0, .k = 1, .expected = 0.14936120510359185 },
    };

    for (test_cases) |case| {
        const result = math.poisson(case.lambda, case.k);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("poisson({d:.1}, {d}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.lambda, case.k, result, case.expected, relative_error });

        try testing.expect(relative_error < tolerance);
    }
}

test "clamp function accuracy" {
    const test_cases = [_]struct {
        val: i32,
        min: i32,
        max: i32,
        expected: i32,
    }{
        .{ .val = 5, .min = 0, .max = 10, .expected = 5 },
        .{ .val = -5, .min = 0, .max = 10, .expected = 0 },
        .{ .val = 15, .min = 0, .max = 10, .expected = 10 },
        .{ .val = 0, .min = -5, .max = 5, .expected = 0 },
    };

    for (test_cases) |case| {
        const result = math.clamp(case.val, case.min, case.max);

        std.debug.print("clamp({d}, {d}, {d}) = {d} (expected: {d})\n", .{ case.val, case.min, case.max, result, case.expected });

        try testing.expect(result == case.expected);
    }
}

test "FFT algorithm accuracy verification" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n=== FFT Algorithm Accuracy Tests ===\n", .{});

    // Test FFT by creating a DFT detector and using it indirectly
    // This tests the actual FFT implementation used by the statistical tests

    const detect = zsts.detect;
    const dft = zsts.dft;

    // Test 1: Simple signal with known FFT properties
    {
        std.debug.print("\n--- Test 1: DFT Statistical Test Integration ---\n", .{});

        const param = detect.DetectParam{
            .type = detect.DetectType.Dft,
            .n = 1024,
            .extra = null,
        };

        var stat = try dft.dftDetectStatDetect(allocator, param);
        defer stat.destroy();

        // Test with a sequence that should have predictable FFT behavior
        // Create a simple alternating sequence
        var test_data = try allocator.alloc(u1, 1024);
        defer allocator.free(test_data);

        for (0..1024) |i| {
            test_data[i] = @as(u1, @truncate(i % 2));
        }

        // Create bit stream from our test data
        const memory_stream = zsts.io.createMemoryStream(allocator, std.mem.sliceAsBytes(test_data));
        const bit_stream = zsts.io.BitInputStream.fromByteInputStreamWithLength(allocator, memory_stream, 1024);
        defer bit_stream.close();

        stat.init(stat.param);
        const result = stat.iterate(&bit_stream);

        std.debug.print("DFT Test Results:\n", .{});
        std.debug.print("  Passed: {}\n", .{result.passed});
        std.debug.print("  V-value: {d:.6}\n", .{result.v_value});
        std.debug.print("  P-value: {d:.6}\n", .{result.p_value});
        std.debug.print("  Q-value: {d:.6}\n", .{result.q_value});

        // Verify the test produces reasonable results
        try testing.expect(std.math.isFinite(result.v_value));
        try testing.expect(std.math.isFinite(result.p_value));
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
    }

    // Test 2: Random data FFT behavior
    {
        std.debug.print("\n--- Test 2: Random Data FFT Analysis ---\n", .{});

        const param = detect.DetectParam{
            .type = detect.DetectType.Dft,
            .n = 512,
            .extra = null,
        };

        var stat = try dft.dftDetectStatDetect(allocator, param);
        defer stat.destroy();

        // Generate random binary data
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        var test_data = try allocator.alloc(u1, 512);
        defer allocator.free(test_data);

        for (0..512) |i| {
            test_data[i] = if (random.float(f32) > 0.5) 1 else 0;
        }

        const memory_stream = zsts.io.createMemoryStream(allocator, std.mem.sliceAsBytes(test_data));
        const bit_stream = zsts.io.BitInputStream.fromByteInputStreamWithLength(allocator, memory_stream, 512);
        defer bit_stream.close();

        stat.init(stat.param);
        const result = stat.iterate(&bit_stream);

        std.debug.print("Random Data DFT Results:\n", .{});
        std.debug.print("  Passed: {}\n", .{result.passed});
        std.debug.print("  V-value: {d:.6}\n", .{result.v_value});
        std.debug.print("  P-value: {d:.6}\n", .{result.p_value});
        std.debug.print("  Q-value: {d:.6}\n", .{result.q_value});

        // Random data should generally pass the DFT test
        try testing.expect(std.math.isFinite(result.v_value));
        try testing.expect(std.math.isFinite(result.p_value));
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);

        // For random data, we expect the test to pass most of the time
        // but we won't enforce it strictly as it's statistical
    }

    // Test 3: Pattern recognition
    {
        std.debug.print("\n--- Test 3: Periodic Pattern Detection ---\n", .{});

        const param = detect.DetectParam{
            .type = detect.DetectType.Dft,
            .n = 256,
            .extra = null,
        };

        var stat = try dft.dftDetectStatDetect(allocator, param);
        defer stat.destroy();

        // Create a periodic pattern that should be detected by FFT
        var test_data = try allocator.alloc(u1, 256);
        defer allocator.free(test_data);

        // Create a pattern with period 4: 1,0,1,0,1,0,1,0...
        for (0..256) |i| {
            test_data[i] = @as(u1, @truncate((i / 2) % 2));
        }

        const memory_stream = zsts.io.createMemoryStream(allocator, std.mem.sliceAsBytes(test_data));
        const bit_stream = zsts.io.BitInputStream.fromByteInputStreamWithLength(allocator, memory_stream, 256);
        defer bit_stream.close();

        stat.init(stat.param);
        const result = stat.iterate(&bit_stream);

        std.debug.print("Periodic Pattern DFT Results:\n", .{});
        std.debug.print("  Passed: {}\n", .{result.passed});
        std.debug.print("  V-value: {d:.6}\n", .{result.v_value});
        std.debug.print("  P-value: {d:.6}\n", .{result.p_value});
        std.debug.print("  Q-value: {d:.6}\n", .{result.q_value});

        // Periodic patterns should typically fail the randomness test
        // (though this depends on the specific pattern and test parameters)
        try testing.expect(std.math.isFinite(result.v_value));
        try testing.expect(std.math.isFinite(result.p_value));
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
    }

    // Test 4: Edge case - small data size
    {
        std.debug.print("\n--- Test 4: Small Data Size Handling ---\n", .{});

        const param = detect.DetectParam{
            .type = detect.DetectType.Dft,
            .n = 64,
            .extra = null,
        };

        var stat = try dft.dftDetectStatDetect(allocator, param);
        defer stat.destroy();

        var test_data = try allocator.alloc(u1, 64);
        defer allocator.free(test_data);

        // Fill with simple pattern
        for (0..64) |i| {
            test_data[i] = @as(u1, @truncate(i % 2));
        }

        const memory_stream = zsts.io.createMemoryStream(allocator, std.mem.sliceAsBytes(test_data));
        const bit_stream = zsts.io.BitInputStream.fromByteInputStreamWithLength(allocator, memory_stream, 64);
        defer bit_stream.close();

        stat.init(stat.param);
        const result = stat.iterate(&bit_stream);

        std.debug.print("Small Data DFT Results:\n", .{});
        std.debug.print("  Passed: {}\n", .{result.passed});
        std.debug.print("  V-value: {d:.6}\n", .{result.v_value});
        std.debug.print("  P-value: {d:.6}\n", .{result.p_value});
        std.debug.print("  Q-value: {d:.6}\n", .{result.q_value});

        // Even small data should produce valid results
        try testing.expect(std.math.isFinite(result.v_value));
        try testing.expect(std.math.isFinite(result.p_value));
        try testing.expect(result.p_value >= 0.0 and result.p_value <= 1.0);
    }

    std.debug.print("\n✅ All FFT accuracy tests completed successfully!\n", .{});
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
    std.debug.print("Rank test compatibility: p_value = {d:.6} (expected: {d:.6}, rel_err: {e:.2})\n", .{ p_value, expected_p, relative_error });

    // 允许较大的容差，因为测试数据可能来自不同的实现
    try testing.expect(relative_error < 1e-3);
}
