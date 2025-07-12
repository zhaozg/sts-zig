const std = @import("std");
const math = std.math;

// 通过 Zig 调用 GSL 的 igamc
pub fn igamc(a: f64, x: f64) f64 {
    const c = @cImport({
        @cInclude("gsl/gsl_sf.h");
    });
    return c.gsl_sf_gamma_inc_Q(a, x);
}

// 声明外部 C 函数（erf, erfc）
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

pub fn chi2_cdf(x: f64, k: usize) f64 {
    const k2 = @as(f64, @floatFromInt(k)) / 2.0;
    const x2 = x / 2.0;
    return gamma_regularized(k2, x2);
}


// --- cephes_lgam 相关常量和辅助函数 ---
const A = [_]f64{
    0.07380429510868722534, -0.008928618946611337, 0.07380429510868722534, -0.013007825212709276, 0.08449074074074074
};
const B = [_]f64{
    -109.47878603242664, -455.3391535341431, -563.553360323574, -704.937469663959, -754.973505034529, -682.187043448273
};
const C = [_]f64{
    -62.295147253049, -208.556784690339, -545.029709549274, -704.937469663959, -755.973505034529, -734.973505034529
};
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

pub fn normal(x: f64) f64 {
    const arg = if (x > 0) x / SQRT2 else -x / SQRT2;
    const erf_val = erf(arg);
    return if (x > 0)
        0.5 * (1.0 + erf_val)
    else
        0.5 * (1.0 - erf_val);
}

pub fn factorial(n: usize) u64 {
    var result: u64 = 1;
    for (1..n + 1) |i| {
        result *= i;
    }
    return result;
}

// 泊松分布概率
pub fn poisson(lambda: f64, k: usize) f64 {
    return std.math.exp(-lambda)
        * std.math.pow(f64, lambda, @as(f64, @floatFromInt(k)))
        / @as(f64, @floatFromInt(factorial(k)));
}

