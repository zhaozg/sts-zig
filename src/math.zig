const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

const rel_error = 1e-12;

const two_sqrtpi = 1.128379167095512574;
const one_sqrtpi = 0.564189583547756287;

pub const MACHEP = 1.11022302462515654042363e-16; // 2**-53
pub const MAXLOG = 7.0978271289338399673222e2;    // ln(2**1024*(1-MACHEP))
pub const MAXNUM = 1.79769313486231570814527e308; // 2**1024*(1-MACHEP)

pub const PI = math.pi;
pub const SQRT2 = math.sqrt2;

const big = 4.503599627370496e15;
const biginv = 2.22044604925031308085e-16;

pub fn erf(x: f64) f64 {
    if (x==0.0) return 0.0;
    if (math.isInf(x)) {
        return if (x > 0) 1.0 else -1.0;
    }

    if (@abs(x) > 2.2) {
        return 1.0 - erfc(x);
    }
    var sum = x;
    var term = x;
    const xsqr = x * x;
    var j: f64 = 1.0;

    while (true) {
        term *= xsqr / j;
        sum -= term / (2.0 * j + 1.0);
        j += 1.0;
        term *= xsqr / j;
        sum += term / (2.0 * j + 1.0);
        j += 1.0;
        if (@abs(term) / @abs(sum) <= rel_error) break;
    }
    return two_sqrtpi * sum;
}

pub fn erfc(x: f64) f64 {
    if (math.isInf(x)) {
        return if (x > 0) 0.0 else 2.0;
    }

    if (@abs(x) < 2.2) {
        return 1.0 - erf(x);
    }
    if (x < 0.0) {
        return 2.0 - erfc(-x);
    }
    var a: f64 = 1.0;
    var b: f64 = x;
    var c: f64 = x;
    var d: f64 = x * x + 0.5;
    var q1: f64 = 0.0;
    var q2: f64 = b / d;
    var n: f64 = 1.0;
    var t: f64 = 0.0;

    while (true) {
        t = a * n + b * x;
        a = b;
        b = t;
        t = c * n + d * x;
        c = d;
        d = t;
        n += 0.5;
        q1 = q2;
        q2 = b / d;
        if (@abs(q1 - q2) / @abs(q2) <= rel_error) break;
    }
    return one_sqrtpi * std.math.exp(-x * x) * q2;
}

/// 计算上不完全伽马函数的正则化形式 Q(a,x) = Γ(a,x)/Γ(a)
/// 这是 GSL gsl_sf_gamma_inc_Q 的纯 Zig 实现
/// 使用连分数展开和级数展开的组合算法，确保数值稳定性和精度
pub fn igamc(a: f64, x: f64) f64 {
    if (x < 0.0 or a <= 0.0) {
        return std.math.nan(f64);
    }

    if (x == 0.0) {
        return 1.0;
    }

    // 对于 x >> a 的情况，使用连分数展开
    if (x > a + 1.0) {
        return igamc_cf(a, x);
    }

    // 对于 x <= a + 1 的情况，使用级数展开计算 P(a,x) = γ(a,x)/Γ(a)
    // 然后返回 Q(a,x) = 1 - P(a,x)
    return 1.0 - igam_series(a, x);
}

/// 使用连分数展开计算上不完全伽马函数
fn igamc_cf(a: f64, x: f64) f64 {
    const max_iterations = 1000;
    const epsilon = std.math.floatEps(f64);

    var b = x + 1.0 - a;
    var c = 1.0 / std.math.floatMin(f64);
    var d = 1.0 / b;
    var h = d;

    var i: usize = 1;
    while (i <= max_iterations) : (i += 1) {
        const an = -(@as(f64, @floatFromInt(i))) * (@as(f64, @floatFromInt(i)) - a);
        b += 2.0;
        d = an * d + b;
        if (@abs(d) < std.math.floatMin(f64)) {
            d = std.math.floatMin(f64);
        }
        c = b + an / c;
        if (@abs(c) < std.math.floatMin(f64)) {
            c = std.math.floatMin(f64);
        }
        d = 1.0 / d;
        const del = d * c;
        h *= del;
        if (@abs(del - 1.0) <= epsilon) {
            break;
        }
    }

    // 替换 gammaln 为 std.math.lgamma
    return std.math.exp(-x + a * std.math.log(f64, std.math.e, x) - std.math.lgamma(f64, a)) * h;
}

/// 使用级数展开计算下不完全伽马函数的正则化形式 P(a,x)
fn igam_series(a: f64, x: f64) f64 {
    const max_iterations = 1000;
    const epsilon = std.math.floatEps(f64);

    if (x == 0.0) {
        return 0.0;
    }

    var sum = 1.0 / a;
    var del = sum;
    var ap = a;

    var n: usize = 1;
    while (n <= max_iterations) : (n += 1) {
        ap += 1.0;
        del *= x / ap;
        sum += del;
        if (@abs(del) < @abs(sum) * epsilon) {
            break;
        }
    }

    // 替换 gammaln 为 std.math.lgamma
    return sum * std.math.exp(-x + a * std.math.log(f64, std.math.e, x) - std.math.lgamma(f64, a));
}

pub fn clamp(val: i32, min: i32, max: i32) i32 {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

/// 优化的卡方分布累积分布函数
pub fn chi2_cdf(x: f64, k: usize) f64 {
    if (x <= 0.0) return 0.0;
    if (k == 0) return 1.0;

    const k2 = @as(f64, @floatFromInt(k)) / 2.0;
    const x2 = x / 2.0;

    // 使用igamc来计算，因为CDF(x; k) = P(k/2, x/2) = γ(k/2, x/2)/Γ(k/2) = 1 - Γ(k/2, x/2)/Γ(k/2)
    return 1.0 - igamc(k2, x2);
}

// --- cephes_lgam 相关常量和辅助函数 ---
const A = [_]f64{ 0.07380429510868722534, -0.008928618946611337, 0.07380429510868722534, -0.013007825212709276, 0.08449074074074074 };
const B = [_]f64{ -109.47878603242664, -455.3391535341431, -563.553360323574, -704.937469663959, -754.973505034529, -682.187043448273 };
const C = [_]f64{ -62.295147253049, -208.556784690339, -545.029709549274, -704.937469663959, -755.973505034529, -734.973505034529 };
const MAXLGM = 2.556348e305;

fn polevl(x: f64, coef: []const f64) f64 {
    var ans = coef[0];
    for (coef[1..]) |v| {
        ans = ans * x + v;
    }
    return ans;
}

fn p1evl(x: f64, coef: []const f64) f64 {
    var ans = x + coef[0];
    for (coef[1..]) |v| {
        ans = ans * x + v;
    }
    return ans;
}

pub fn lgam(x: f64) f64 {
    var sgngam: i32 = 1;
    if (x < -34.0) {
        const q = -x;
        const w = lgam(q);
        const p = math.floor(q);
        if (p == q) return @as(f64, @floatFromInt(sgngam)) * MAXNUM;
        const i = @as(i32, @intFromFloat(p));
        sgngam = if ((i & 1) == 0) -1 else 1;
        var z = q - p;
        if (z > 0.5) {
            z = p + 1.0 - q;
        }
        z = q * math.sin(PI * z);
        if (z == 0.0) return @as(f64, @floatFromInt(sgngam)) * MAXNUM;
        return @log(PI) - @log(z) - w;
    }
    if (x < 13.0) {
        var z: f64 = 1.0;
        var p: f64 = 0.0;
        var u = x;
        while (u >= 3.0) {
            p -= 1.0;
            u = x + p;
            z *= u;
        }
        while (u < 2.0) {
            if (u == 0.0) return @as(f64, @floatFromInt(sgngam)) * MAXNUM;
            z /= u;
            p += 1.0;
            u = x + p;
        }
        if (z < 0.0) {
            sgngam = -1;
            z = -z;
        } else {
            sgngam = 1;
        }
        if (u == 2.0) return @log(z);
        p -= 2.0;
        const xx = x + p;
        p = xx * polevl(xx, B[0..5]) / p1evl(xx, C[0..6]);
        return @log(z) + p;
    }
    if (x > MAXLGM) return @as(f64, @floatFromInt(sgngam)) * MAXNUM;
    var q = (x - 0.5) * @log(x) - x + @log(math.sqrt(2 * PI));
    if (x > 1.0e8) return q;
    const p = 1.0 / (x * x);
    if (x >= 1000.0) {
        q += ((7.9365079365079365079365e-4 * p - 2.7777777777777777777778e-3) * p + 0.0833333333333333333333) / x;
    } else {
        q += polevl(p, A[0..4]) / x;
    }
    return q;
}

/// 优化的正态分布累积分布函数，提高数值稳定性
pub fn normal(x: f64) f64 {
    // 使用更稳定的实现
    if (x == 0.0) return 0.5;

    const abs_x = @abs(x);
    if (abs_x > 6.0) {
        // 对于极值，直接返回边界值避免数值问题
        return if (x > 0) 1.0 else 0.0;
    }

    const t = abs_x / SQRT2;
    const result = 0.5 * (1.0 + erf(t));

    return if (x >= 0.0) result else 1.0 - result;
}

/// 高性能阶乘计算，使用查找表优化小数值
pub fn factorial(n: usize) u64 {
    // 预计算的阶乘查找表 (0! 到 20!)
    const factorial_table = [_]u64{ 1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600, 6227020800, 87178291200, 1307674368000, 20922789888000, 355687428096000, 6402373705728000, 121645100408832000, 2432902008176640000 };

    if (n < factorial_table.len) {
        return factorial_table[n];
    }

    // 对于大数值，从表中最大值开始计算
    var result = factorial_table[factorial_table.len - 1];
    for (factorial_table.len..n + 1) |i| {
        result *= i;
    }
    return result;
}

/// 优化的泊松分布概率计算，避免大阶乘的计算
pub fn poisson(lambda: f64, k: usize) f64 {
    if (lambda <= 0.0) return 0.0;
    if (k == 0) return std.math.exp(-lambda);

    // 使用对数计算避免溢出：log(P(X=k)) = -λ + k*log(λ) - log(k!)
    const log_lambda = std.math.log(f64, std.math.e, lambda);
    // 替换 gammaln 为 std.math.lgamma
    const log_factorial_k = std.math.lgamma(f64, @as(f64, @floatFromInt(k + 1))); // ln(k!) = ln(Γ(k+1))
    const log_prob = -lambda + @as(f64, @floatFromInt(k)) * log_lambda - log_factorial_k;

    return std.math.exp(log_prob);
}

// 测试容差 - 相对误差在这个范围内认为正确
test "erf function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 0.0 },
        .{ .x = 0.1, .expected = 0.1124629160182849 },
        .{ .x = 0.5, .expected = 0.5204998778130465 },
        .{ .x = 1.0, .expected = 0.8427007929497149 },
        .{ .x = 1.5, .expected = 0.9661051464753107 },
        .{ .x = 2.0, .expected = 0.9953222650189527 },
        .{ .x = 2.5, .expected = 0.9995930479825550 },
        .{ .x = 3.0, .expected = 0.9999779095030014 },
        .{ .x = -0.1, .expected = -0.1124629160182849 },
        .{ .x = -0.5, .expected = -0.5204998778130465 },
        .{ .x = -1.0, .expected = -0.8427007929497149 },
        .{ .x = -1.5, .expected = -0.9661051464753107 },
        .{ .x = -2.0, .expected = -0.9953222650189527 },
    };

    for (test_cases) |case| {
        const result = erf(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erf({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
    }
}

test "erfc function accuracy" {
    const test_cases = [_]struct {
        x: f64,
        expected: f64,
    }{
        .{ .x = 0.0, .expected = 1.0 },
        .{ .x = 0.1, .expected = 0.8875370839817151 },
        .{ .x = 0.5, .expected = 0.4795001221869535 },
        .{ .x = 1.0, .expected = 0.1572992070502851 },
        .{ .x = 1.5, .expected = 0.0338948535246893 },
        .{ .x = 2.0, .expected = 0.004677734981047266 },
        .{ .x = 2.5, .expected = 0.0004069520174450 },
        .{ .x = 3.0, .expected = 0.00002209049699858544 },
        .{ .x = -0.1, .expected = 1.1124629160182849 },
        .{ .x = -0.5, .expected = 1.5204998778130465 },
        .{ .x = -1.0, .expected = 1.8427007929497149 },
        .{ .x = -1.5, .expected = 1.9661051464753107 },
        .{ .x = -2.0, .expected = 1.9953222650189527 },
    };

    for (test_cases) |case| {
        const result = erfc(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("erfc({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
    }
}

test "erf and erfc performance test" {
    // Performance test to ensure erf and erfc functions execute efficiently
    // This test verifies that the functions don't hang or take excessive time

    const test_values = [_]f64{ 0.0, 0.5, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0, 4.0, -4.0 };

    std.debug.print("\n=== erf and erfc Performance Test ===\n", .{});

    for (test_values) |x| {
        // Test erf performance
        const start_time_erf = std.time.nanoTimestamp();
        const erf_result = erf(x);
        const erf_time = std.time.nanoTimestamp() - start_time_erf;

        // Test erfc performance
        const start_time_erfc = std.time.nanoTimestamp();
        const erfc_result = erfc(x);
        const erfc_time = std.time.nanoTimestamp() - start_time_erfc;

        std.debug.print("x = {d:.1}: erf({d:.1}) = {d:.10} (time: {}ns), erfc({d:.1}) = {d:.10} (time: {}ns)\n", .{ x, x, erf_result, erf_time, x, erfc_result, erfc_time });

        // Verify mathematical identity: erf(x) + erfc(x) = 1
        const identity_error = @abs(erf_result + erfc_result - 1.0);
        std.debug.print("  Identity check: erf + erfc = {d:.15} (error: {e:.2})\n", .{ erf_result + erfc_result, identity_error });

        // Performance requirements: functions should complete within reasonable time
        const max_time_ns = 1_000_000; // 1 millisecond threshold
        try expect(erf_time < max_time_ns);
        try expect(erfc_time < max_time_ns);

        // Mathematical identity should hold with high precision
        try expect(identity_error < 1e-14);
    }

    std.debug.print("✅ All performance tests passed\n", .{});
}

test "erf and erfc functions" {
    const epsilon = 1e-12;

    // 测试一些已知值
    try expectApproxEqAbs(erf(0.0), 0.0, epsilon);
    try expectApproxEqAbs(erfc(0.0), 1.0, epsilon);

    try expectApproxEqAbs(erf(1.0), 0.8427007929497149, epsilon);
    try expectApproxEqAbs(erfc(1.0), 0.1572992070502851, epsilon);

    try expectApproxEqAbs(erf(2.0), 0.9953222650189527, epsilon);
    try expectApproxEqAbs(erfc(2.0), 0.004677734981047265, epsilon);

    // 测试对称性
    try expectApproxEqAbs(erf(-1.0), -erf(1.0), epsilon);
    try expectApproxEqAbs(erfc(-1.0), 2.0 - erfc(1.0), epsilon);

    // 测试边界条件
    try expect(erf(math.inf(f64)) == 1.0);
    try expect(erf(-math.inf(f64)) == -1.0);
    try expect(erfc(math.inf(f64)) == 0.0);
    try expect(erfc(-math.inf(f64)) == 2.0);
}

test "erf erfc consistency" {
    // 测试 erf 和 erfc 的一致性
    const test_values = [_]f64{ -3.0, -2.0, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0, 3.0 };

    for (test_values) |x| {
        const epsilon = 1e-12;
        try expectApproxEqAbs(erf(x) + erfc(x), 1.0, epsilon);
    }
}
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
        const result = igamc(case.a, case.x);
        const relative_error = @abs(result - case.expected) / @abs(case.expected);

        std.debug.print("igamc({d:.1}, {d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.a, case.x, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
    }
}

test "igamc edge cases" {
    // 测试边界情况和错误条件

    // 负参数应该返回 NaN
    try expect(std.math.isNan(igamc(-1.0, 1.0)));
    try expect(std.math.isNan(igamc(1.0, -1.0)));
    try expect(std.math.isNan(igamc(0.0, 1.0)));

    // x = 0 时应该返回 1
    try expectApproxEqAbs(igamc(1.0, 0.0), 1.0, 1e-15);
    try expectApproxEqAbs(igamc(5.0, 0.0), 1.0, 1e-15);
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
        // 使用标准库 lgamma 替代自定义 gammaln
        const result = std.math.lgamma(f64, case.x);
        var relative_error: f64 = 0.0;

        if (case.expected == 0.0) {
            // Special case: when expected is 0, use absolute error
            relative_error = @abs(result - case.expected);
        } else {
            relative_error = @abs(result - case.expected) / @abs(case.expected);
        }

        std.debug.print("lgamma({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
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
        const result = factorial(case.n);

        std.debug.print("factorial({d}) = {d} (expected: {d})\n", .{ case.n, result, case.expected });

        try expect(result == case.expected);
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
        const result = poisson(case.lambda, case.k);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("poisson({d:.1}, {d}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.lambda, case.k, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
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

        try expect(result == case.expected);
    }
}

test "consistency with existing test cases" {
    // 确保新实现与现有测试用例兼容
    // 这些值来自于项目中现有的测试期望值

    // 来自 rank.zig 测试的例子：chi2 = 2.358278, 期望 p_value = 0.307543
    const chi2 = 2.358278;
    const df = 2.0; // 自由度
    const p_value = igamc(df / 2.0, chi2 / 2.0);
    const expected_p = 0.307543;

    const relative_error = @abs(p_value - expected_p) / expected_p;
    std.debug.print("Rank test compatibility: p_value = {d:.6} (expected: {d:.6}, rel_err: {e:.2})\n", .{ p_value, expected_p, relative_error });

    // 允许较大的容差，因为测试数据可能来自不同的实现
    try expect(relative_error < 1e-3);
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
        const result = normal(case.x);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("normal({d:.1}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
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
        .{ .x = 5.0, .k = 3, .expected = 0.828202855703267 },
        .{ .x = 10.0, .k = 5, .expected = 0.924764753853488 },
    };

    for (test_cases) |case| {
        const result = chi2_cdf(case.x, case.k);
        const relative_error = @abs(result - case.expected) / (@abs(case.expected) + 1e-15);

        std.debug.print("chi2_cdf({d:.1}, {d}) = {d:.15} (expected: {d:.15}, rel_err: {e:.2})\n", .{ case.x, case.k, result, case.expected, relative_error });

        try expect(relative_error < rel_error);
    }
}

