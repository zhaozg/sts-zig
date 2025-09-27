# API Documentation / API 文档

This document provides comprehensive API documentation for the STS-Zig library.

本文档提供 STS-Zig 库的完整 API 文档。

## Core Types / 核心类型

### DetectType

Enumeration of all supported statistical tests.

所有支持的统计测试的枚举。

```zig
pub const DetectType = enum {
    Frequency,                // 频率检测
    BlockFrequency,           // 块内频数检测
    Poker,                    // 扑克检测
    Runs,                     // 游程检测
    LongestRun,               // 最长游程检测
    Rank,                     // 矩阵秩检测
    Dft,                      // 离散傅里叶变换检测
    OverlappingTemplate,      // 重叠模板匹配检测
    NonOverlappingTemplate,   // 非重叠模板匹配检测
    MaurerUniversal,          // 通用统计检测
    LinearComplexity,         // 线性复杂度检测
    Serial,                   // 序列检测
    ApproxEntropy,            // 近似熵检测
    CumulativeSums,           // 累积和检测
    RandomExcursions,         // 随机偏移检测
    RandomExcursionsVariant,  // 随机偏移变体检测
    // GMT specific tests
    OverlappingSequency,      // 重叠子序列检测
    RunDistribution,          // 游程分布检测
    BinaryDerivative,         // 二元推导检测
    Autocorrelation,          // 自相关检测
};
```

### DetectParam

Parameters for configuring statistical tests.

配置统计测试的参数。

```zig
pub const DetectParam = struct {
    type: DetectType,         // 检测类型
    n: usize,                 // 数据长度
    extra: ?*const anyopaque, // 额外参数指针
};
```

### DetectResult

Result structure returned by all statistical tests.

所有统计测试返回的结果结构。

```zig
pub const DetectResult = struct {
    passed: bool,             // 是否通过测试
    v_value: f64,             // 检验统计量值
    p_value: f64,             // P值（显著性水平）
    q_value: f64,             // Q值（通常等于P值或为补充值）
    extra: ?*const anyopaque, // 额外结果数据
    errno: ?anyerror,         // 错误信息（如果有）
};
```

### StatDetect

Core detection object interface.

核心检测对象接口。

```zig
pub const StatDetect = struct {
    name: []const u8,     // 测试名称
    param: *const DetectParam, // 参数指针
    allocator: std.mem.Allocator, // 内存分配器
    state: ?*anyopaque,   // 内部状态

    // Function pointers / 函数指针
    _init: *const fn(*StatDetect, *const DetectParam) void,
    _iterate: *const fn(*StatDetect, *const BitInputStream) DetectResult,
    _destroy: *const fn(*StatDetect) void,
    _reset: *const fn(*StatDetect) void,
    _print: ?*const fn(*StatDetect, *const DetectResult, PrintLevel) void,

    // Methods / 方法
    pub fn init(self: *StatDetect, param: *const DetectParam) void
    pub fn iterate(self: *StatDetect, bits: *const BitInputStream) DetectResult
    pub fn destroy(self: *StatDetect) void
    pub fn reset(self: *StatDetect) void
    pub fn print(self: *StatDetect, result: *const DetectResult, level: PrintLevel) void
};
```

## Input/Output API / 输入输出 API

### BitInputStream

Handles binary data input for statistical tests.

处理统计测试的二进制数据输入。

```zig
pub const BitInputStream = struct {
    // Static constructors / 静态构造函数
    pub fn fromFile(allocator: std.mem.Allocator, file: std.fs.File) BitInputStream
    pub fn fromBytes(allocator: std.mem.Allocator, data: []const u8) BitInputStream
    pub fn fromAsciiInputStreamWithLength(allocator: std.mem.Allocator,
                                         input: InputStream,
                                         length: usize) BitInputStream

    // Methods / 方法
    pub fn fetchBit(self: *BitInputStream) ?u1           // 获取下一个比特
    pub fn len(self: *const BitInputStream) usize        // 获取总长度
    pub fn bits(self: *const BitInputStream) []const u8  // 获取所有比特
    pub fn close(self: *BitInputStream) void             // 关闭并清理资源
};
```

## Mathematical Functions API / 数学函数 API

### Core Mathematical Functions

High-precision mathematical functions used by statistical tests.

统计测试使用的高精度数学函数。

```zig
// Incomplete Gamma Function (upper) / 上不完全伽马函数
pub fn igamc(a: f64, x: f64) f64

// Gamma Logarithm / 伽马函数对数
pub fn gammaln(x: f64) f64

// Complementary Error Function / 互补误差函数
pub fn erfc(x: f64) f64

// Poisson Probability Mass Function / 泊松概率质量函数
pub fn poisson(lambda: f64, k: usize) f64
```

### FFT Functions

Fast Fourier Transform implementation.

快速傅里叶变换实现。

```zig
// Real-to-Complex FFT / 实数到复数 FFT
pub fn compute_r2c_fft(
    self: *StatDetect,
    x: []const f64,      // 输入实数数据
    fft_out: []f64,      // 输出复数数组
    fft_m: []f64,        // 输出幅值谱
) !void
```

## Statistical Test APIs / 统计测试 API

### Frequency Test / 频率检测

Tests the proportion of ones and zeros in the sequence.

测试序列中 0 和 1 的比例。

```zig
pub fn frequencyDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

**Expected Results / 预期结果:**
- Random data: P-value ≈ 0.5
- All zeros/ones: P-value ≈ 0.0

### Block Frequency Test / 块内频数检测

Tests frequency within fixed-length blocks.

测试固定长度块内的频率。

```zig
pub const BlockFrequencyParam = struct {
    m: usize,  // Block size / 块大小
};

pub fn blockFrequencyDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Runs Test / 游程检测

Tests the number of runs (consecutive identical bits).

测试游程数量（连续相同比特的数量）。

```zig
pub fn runsDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Longest Run Test / 最长游程检测

Tests the longest run of ones in the sequence.

测试序列中最长的 1 的游程。

```zig
pub fn longestRunDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Matrix Rank Test / 矩阵秩检测

Tests the rank of binary matrices formed from the sequence.

测试由序列形成的二进制矩阵的秩。

```zig
pub fn rankDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### DFT Test / 离散傅里叶变换检测

Tests the spectral properties using FFT.

使用 FFT 测试频谱特性。

```zig
pub fn dftDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Poker Test / 扑克检测

Tests the frequency of m-bit patterns.

测试 m 位模式的频率。

```zig
pub const PokerParam = struct {
    m: u4,  // Pattern length (2, 4, or 8) / 模式长度（2、4 或 8）
};

pub fn pokerDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Template Matching Tests / 模板匹配检测

#### Non-overlapping Template / 非重叠模板匹配

```zig
pub fn nonOverlappingTemplateDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

#### Overlapping Template / 重叠模板匹配

```zig
pub fn overlappingTemplateDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Universal Statistical Test / 通用统计检测

Maurer's universal statistical test.

Maurer 通用统计检测。

```zig
pub fn maurerUniversalDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Linear Complexity Test / 线性复杂度检测

Tests the linear complexity of the sequence.

测试序列的线性复杂度。

```zig
pub fn linearComplexityDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Serial Test / 序列检测

Tests the frequency of overlapping m-bit patterns.

测试重叠 m 位模式的频率。

```zig
pub fn serialDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Approximate Entropy Test / 近似熵检测

Tests the randomness based on pattern entropy.

基于模式熵测试随机性。

```zig
pub const ApproxEntropyParam = struct {
    m: usize,  // Pattern length / 模式长度
};

pub fn approximateEntropyDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Cumulative Sums Test / 累积和检测

Tests the cumulative sum of the sequence.

测试序列的累积和。

```zig
pub fn cumulativeSumsDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Random Excursions Test / 随机偏移检测

Tests the excursions from zero in cumulative sums.

测试累积和中从零点的偏移。

```zig
pub fn randomExcursionsDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Random Excursions Variant Test / 随机偏移变体检测

Variant of the random excursions test.

随机偏移检测的变体。

```zig
pub fn randomExcursionsVariantDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

## GMT-Specific Tests / GMT 专用测试

### Binary Derivative Test / 二元推导检测

Tests k-th order binary derivatives.

测试 k 阶二元导数。

```zig
pub const BinaryDerivativeParam = struct {
    k: usize,  // Derivative order / 导数阶数
};

pub fn binaryDerivativeDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Autocorrelation Test / 自相关检测

Tests autocorrelation at lag d.

测试滞后 d 的自相关。

```zig
pub fn autocorrelationDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam,
    d: usize  // Lag parameter / 滞后参数
) !*StatDetect
```

### Run Distribution Test / 游程分布检测

Tests the distribution of run lengths.

测试游程长度的分布。

```zig
pub fn runDistributionDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

### Overlapping Subsequence Test / 重叠子序列检测

Tests overlapping subsequences.

测试重叠子序列。

```zig
pub fn overlappingSequencyDetectStatDetect(
    allocator: std.mem.Allocator,
    param: DetectParam
) !*StatDetect
```

## Error Handling / 错误处理

### Common Errors / 常见错误

```zig
pub const DetectError = error{
    InvalidArgument,        // 无效参数
    OutOfMemory,           // 内存不足
    BufferTooSmall,        // 缓冲区太小
    InsufficientData,      // 数据不足
    InvalidDataFormat,     // 无效数据格式
};
```

### Error Handling Pattern / 错误处理模式

```zig
// Example error handling / 错误处理示例
const stat = zsts.frequency.frequencyDetectStatDetect(allocator, param) catch |err| switch (err) {
    error.OutOfMemory => {
        std.log.err("Insufficient memory for test", .{});
        return;
    },
    error.InvalidArgument => {
        std.log.err("Invalid test parameters", .{});
        return;
    },
    else => return err,
};
defer stat.destroy();

const result = stat.iterate(&bits);
if (result.errno) |err| {
    std.log.err("Test execution failed: {}", .{err});
    return;
}
```

## Usage Examples / 使用示例

### Basic Test Execution / 基本测试执行

```zig
const std = @import("std");
const zsts = @import("zsts");

pub fn runFrequencyTest() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Prepare test data / 准备测试数据
    const test_data = [_]u8{ 1, 0, 1, 1, 0, 0, 1, 0, 1, 1 };
    const bits = zsts.io.BitInputStream.fromBytes(allocator, &test_data);
    defer bits.close();

    // Configure test parameters / 配置测试参数
    const param = zsts.detect.DetectParam{
        .type = zsts.detect.DetectType.Frequency,
        .n = test_data.len,
        .extra = null,
    };

    // Create and run test / 创建并运行测试
    const stat = try zsts.frequency.frequencyDetectStatDetect(allocator, param);
    defer stat.destroy();

    stat.init(&param);
    const result = stat.iterate(&bits);
    stat.print(&result, .detail);

    // Interpret results / 解释结果
    if (result.passed) {
        std.debug.print("Test PASSED: P-value = {:.6}\n", .{result.p_value});
    } else {
        std.debug.print("Test FAILED: P-value = {:.6}\n", .{result.p_value});
    }
}
```

### Batch Testing / 批量测试

```zig
pub fn runAllTests(data: []const u8, allocator: std.mem.Allocator) !void {
    const bits = zsts.io.BitInputStream.fromBytes(allocator, data);
    defer bits.close();

    // List of tests to run / 要运行的测试列表
    const test_functions = .{
        zsts.frequency.frequencyDetectStatDetect,
        zsts.runs.runsDetectStatDetect,
        zsts.rank.rankDetectStatDetect,
        zsts.dft.dftDetectStatDetect,
    };

    inline for (test_functions) |test_func| {
        const param = zsts.detect.DetectParam{
            .type = @field(zsts.detect.DetectType, @typeName(@TypeOf(test_func))),
            .n = data.len,
            .extra = null,
        };

        const stat = try test_func(allocator, param);
        defer stat.destroy();

        stat.init(&param);
        const result = stat.iterate(&bits);
        stat.print(&result, .summary);
    }
}
```

## Performance Considerations / 性能考虑

### Memory Usage / 内存使用

- Most tests use O(n) memory where n is the input length
- Matrix rank test allocates temporary matrices

### Computational Complexity / 计算复杂度

- **Frequency tests**: O(n)
- **Template matching**: O(n×m) where m is template length
- **Matrix operations**: O(min(M,Q)³) for M×Q matrices

### Optimization Tips / 优化建议

1. **Reuse StatDetect objects** when testing multiple datasets
2. **Use appropriate data sizes** - too small may give unreliable results
3. **Consider memory limits** for very large datasets
4. **Profile specific tests** if performance is critical

---

## Version History / 版本历史
- v0.1.1: Documentation and tools
- **v0.0.1**: Initial release with tests

For more examples and advanced usage, see the `test/` directory in the repository.
