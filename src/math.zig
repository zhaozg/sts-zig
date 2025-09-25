const std = @import("std");
const math = std.math;

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

    return std.math.exp(-x + a * std.math.log(f64, std.math.e, x) - gammaln(a)) * h;
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

    return sum * std.math.exp(-x + a * std.math.log(f64, std.math.e, x) - gammaln(a));
}

/// 计算 ln(Γ(x)) 的高精度实现
/// 基于 Lanczos 近似算法
pub fn gammaln(x: f64) f64 {
    // Lanczos 系数 (g=7, n=9)
    const lanczos_g = 7.0;
    const lanczos_coeff = [_]f64{
        0.99999999999980993227684700473478,
        676.520368121885098567009190444019,
        -1259.13921672240287047156078755283,
        771.323428777653477146296386350052,
        -176.615029162140599065845597129337,
        12.5073432786869048144827324987843,
        -0.138571095265720116895197677512527,
        9.98436957801957085956266828503e-6,
        1.50563273514931155834849228193e-7,
    };

    if (x < 0.5) {
        // 使用反射公式：Γ(z)Γ(1-z) = π/sin(πz)
        return std.math.log(f64, std.math.e, std.math.pi) - std.math.log(f64, std.math.e, std.math.sin(std.math.pi * x)) - gammaln(1.0 - x);
    }

    const z = x - 1.0;
    var sum = lanczos_coeff[0];

    for (1..lanczos_coeff.len) |i| {
        sum += lanczos_coeff[i] / (z + @as(f64, @floatFromInt(i)));
    }

    const t = z + lanczos_g + 0.5;
    return 0.5 * std.math.log(f64, std.math.e, 2.0 * std.math.pi) + (z + 0.5) * std.math.log(f64, std.math.e, t) - t + std.math.log(f64, std.math.e, sum);
}

// 声明外部 C 函数（erf, erfc）
const rel_error = 1e-12;
const two_sqrtpi = 1.128379167095512574;
const one_sqrtpi = 0.564189583547756287;

pub const MACHEP = 1.11022302462515654042363e-16; // 2**-53
pub const MAXLOG = 7.0978271289338399673222e2; // ln(2**1024*(1-MACHEP))
pub const MAXNUM = 1.79769313486231570814527e308; // 2**1024*(1-MACHEP)

pub const PI = math.pi;
pub const SQRT2 = math.sqrt2;

const big = 4.503599627370496e15;
const biginv = 2.22044604925031308085e-16;

pub fn erf(x: f64) f64 {
    // Handle special cases
    if (std.math.isNan(x)) return std.math.nan(f64);
    if (std.math.isInf(x)) return if (x > 0) 1.0 else -1.0;
    if (x == 0.0) return 0.0;

    const abs_x = @abs(x);
    const sign: f64 = if (x >= 0.0) 1.0 else -1.0;

    // For large values, return the limit value
    if (abs_x >= 6.0) {
        return sign;
    }

    // Use improved series approximation for higher precision
    // This uses a rational approximation with better coefficients
    if (abs_x < 3.0) {
        // For small to medium values, use Taylor series with enough precision
        const two_over_sqrt_pi = 1.1283791670955125738961589031215;
        var sum = abs_x;
        var term = abs_x;
        const x_squared = abs_x * abs_x;

        // Use enough terms for high precision
        for (1..30) |n| {
            const n_f64 = @as(f64, @floatFromInt(n));
            term *= -x_squared / n_f64;
            const new_term = term / (2.0 * n_f64 + 1.0);
            sum += new_term;

            // Stop when we reach machine precision
            if (@abs(new_term / sum) < 1e-16) break;
        }

        return sign * two_over_sqrt_pi * sum;
    } else {
        // For larger values, use continued fraction via erfc
        return sign * (1.0 - erfc_simple(abs_x));
    }
}

pub fn erfc(x: f64) f64 {
    // Handle special cases
    if (std.math.isNan(x)) return std.math.nan(f64);
    if (std.math.isInf(x)) {
        return if (x > 0) 0.0 else 2.0;
    }
    if (x == 0.0) return 1.0;

    // For negative values, use the identity: erfc(-x) = 2 - erfc(x)
    if (x < 0.0) {
        return 2.0 - erfc(-x);
    }

    // For large positive values, erfc approaches 0
    if (x >= 6.0) {
        return 0.0;
    }

    return erfc_simple(x);
}

fn erfc_simple(x: f64) f64 {
    if (x < 3.0) {
        // For small values, use the identity erfc(x) = 1 - erf(x)
        return 1.0 - erf(x);
    } else {
        // For large values, use asymptotic expansion
        const x2 = x * x;
        const sqrt_pi = std.math.sqrt(std.math.pi);
        const exp_term = std.math.exp(-x2);

        // First few terms of asymptotic series: erfc(x) ~ exp(-x^2)/(x*sqrt(pi)) * (1 - 1/(2x^2) + 3/(4x^4) - ...)
        const inv_x2 = 1.0 / x2;
        const series = 1.0 - 0.5 * inv_x2 + 0.75 * inv_x2 * inv_x2;

        return (exp_term / (x * sqrt_pi)) * series;
    }
}

pub fn clamp(val: i32, min: i32, max: i32) i32 {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

fn gamma_lower(s: f64, x: f64) f64 {
    var sum = 1.0 / s;
    var value = sum;
    var n: usize = 1;
    while (n < 100) : (n += 1) {
        value *= x / (s + @as(f64, @floatFromInt(n)));
        sum += value;
        if (value < 1e-15) break;
    }
    return std.math.exp(-x + s * std.math.log(f64, std.math.e, x)) * sum;
}

fn gamma_regularized(s: f64, x: f64) f64 {
    return gamma_lower(s, x) / std.math.exp(std.math.lgamma(f64, s));
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
    const log_factorial_k = gammaln(@as(f64, @floatFromInt(k + 1))); // ln(k!) = ln(Γ(k+1))
    const log_prob = -lambda + @as(f64, @floatFromInt(k)) * log_lambda - log_factorial_k;

    return std.math.exp(log_prob);
}
