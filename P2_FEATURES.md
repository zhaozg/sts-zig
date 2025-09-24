# P2 Features Documentation
# P2 功能文档

This document describes the P2 (medium priority) features implemented for sts-zig: Performance Benchmarking and Enhanced CLI capabilities.

## 🔥 Performance Benchmarking Suite

### Overview / 概述
The performance benchmark suite provides comprehensive performance analysis of all statistical test algorithms, enabling optimization identification and performance monitoring.

性能基准测试套件提供所有统计测试算法的全面性能分析，能够识别优化机会并监控性能。

### Features / 功能特点
- **Multi-size Testing**: Tests with 1K, 10K, 100K, and 1M bit datasets
- **Statistical Analysis**: Min, max, average execution times 
- **Throughput Calculation**: Megabits per second processing rates
- **Complexity Analysis**: Algorithm complexity documentation
- **Optimization Recommendations**: Performance improvement suggestions

### Usage / 使用方法

```bash
# Run performance benchmarks
zig build benchmark

# Or run the benchmark executable directly
./zig-out/bin/sts-benchmark
```

### Sample Output / 示例输出

```
🔥 STS-Zig Performance Benchmark Suite
=====================================

Configuration:
- Iterations per test: 100
- Test data sizes: 1000 10000 100000 1000000 bits
- Compiler optimizations: ReleaseFast equivalent

┌──────────────┬──────────┬───────────┬───────────┬───────────┬──────────────┐
│ Test Name    │ Data Size│  Avg Time │  Min Time │  Max Time │  Throughput  │
├──────────────┼──────────┼───────────┼───────────┼───────────┼──────────────┤
│ Frequency    │     1000 │    0.12ms │    0.08ms │    0.25ms │   120.45 MB/s│
│ Runs         │     1000 │    0.09ms │    0.05ms │    0.18ms │   156.82 MB/s│
│ DFT          │     1000 │    2.45ms │    2.12ms │    3.01ms │    5.23 MB/s│
│ Rank         │     1000 │    1.85ms │    1.42ms │    2.33ms │    6.91 MB/s│
└──────────────┴──────────┴───────────┴───────────┴───────────┴──────────────┘

📊 Performance Analysis:
- Frequency Test: O(n) complexity, excellent scalability
- Runs Test: O(n) complexity, very fast
- DFT Test: O(n log n) complexity due to FFT optimization
- Rank Test: O(m³) complexity per matrix, depends on data size

🎯 Optimization Opportunities:
- Use SIMD instructions for bit operations
- Implement parallel processing for large datasets
- Consider memory pool allocation for frequent operations
```

## 🖥️ Enhanced CLI Tool

### Overview / 概述
The enhanced CLI tool provides batch processing, multiple output formats, and flexible test selection for production environments.

增强版命令行工具提供批处理、多种输出格式和灵活的测试选择，适合生产环境使用。

### Features / 功能特点
- **Batch Processing**: Process multiple files simultaneously
- **Output Formats**: Console, JSON, CSV, XML support
- **Selective Testing**: Run specific tests or all tests
- **Verbose Mode**: Detailed progress information
- **Data Limiting**: Process only specified amount of data
- **Professional Output**: Structured results with execution metrics

### Usage / 使用方法

```bash
# Basic usage - run all tests on a single file
zig build cli -- data.txt

# Run specific tests
zig build cli -- -t frequency,runs,dft data.txt

# Batch mode with JSON output
zig build cli -- -b -f json -o results.json *.txt

# Verbose mode with CSV output
zig build cli -- -v -f csv data1.txt data2.txt

# Limit data size and run specific tests
zig build cli -- -l 100000 -t frequency,rank large_dataset.txt
```

### Command Line Options / 命令行选项

```
USAGE:
    sts-cli [OPTIONS] <input_files...>

OPTIONS:
    -h, --help              Show help message
    -v, --verbose           Enable verbose output
    -b, --batch             Enable batch processing mode
    -f, --format FORMAT     Output format: console, json, csv, xml
    -o, --output FILE       Output file (default: stdout)
    -t, --tests TESTS       Comma-separated list of tests to run
    -l, --limit SIZE        Limit data size (in bits)

AVAILABLE TESTS:
    all, frequency, block_frequency, runs, longest_runs, rank, dft,
    poker, autocorrelation, cumulative_sums, approximate_entropy,
    random_excursions, random_excursions_variant, serial,
    linear_complexity, overlapping_template, non_overlapping_template, universal
```

### Output Formats / 输出格式

#### Console Output / 控制台输出
Professional table format with pass/fail status, statistical values, and execution times.

```
📊 STS-Zig Statistical Test Results
===================================

┌──────────────────┬─────────────────┬────────┬───────────┬───────────┬───────────┬──────────┐
│ File             │ Test            │ Status │  P-Value  │  V-Value  │  Q-Value  │ Time(ms) │
├──────────────────┼─────────────────┼────────┼───────────┼───────────┼───────────┼──────────┤
│ data.txt         │ frequency       │ ✅ PASS│  0.543210 │     1.234 │  0.543210 │     0.12 │
│ data.txt         │ runs            │ ✅ PASS│  0.789012 │     0.567 │  0.789012 │     0.09 │
└──────────────────┴─────────────────┴────────┴───────────┴───────────┴───────────┴──────────┘

📈 Summary: 2 passed, 0 failed, 2 total
⏱️  Total execution time: 0.21ms
```

#### JSON Output / JSON输出
Structured JSON for programmatic processing and integration.

```json
{
  "metadata": {
    "tool": "STS-Zig Enhanced CLI",
    "version": "1.0.0",
    "timestamp": "1640995200",
    "batch_mode": true,
    "total_files": 1,
    "total_tests": 2
  },
  "results": [
    {
      "file_name": "data.txt",
      "test_name": "frequency",
      "passed": true,
      "p_value": 0.543210,
      "v_value": 1.234,
      "q_value": 0.543210,
      "execution_time_ms": 0.12,
      "data_size": 1000
    }
  ]
}
```

#### CSV Output / CSV输出
Comma-separated values for spreadsheet analysis.

```csv
File,Test,Status,P_Value,V_Value,Q_Value,Execution_Time_MS,Data_Size
data.txt,frequency,PASS,0.543210,1.234,0.543210,0.12,1000
data.txt,runs,PASS,0.789012,0.567,0.789012,0.09,1000
```

## 🛠️ Integration with Build System / 与构建系统集成

Both P2 features are fully integrated into the zig build system:

```bash
# Run performance benchmarks
zig build benchmark

# Use enhanced CLI
zig build cli -- [CLI_OPTIONS] [FILES...]

# Build both executables
zig build

# The executables will be available at:
# - zig-out/bin/sts-benchmark
# - zig-out/bin/sts-cli
```

## 🔧 Test Execution Fix / 测试执行修复

The test execution issue mentioned by @zhaozg occurs when trying to run individual test files directly:

```bash
# ❌ This causes an error
zig test test/extended_coverage_test.zig --dep zsts -Mzsts=src/zsts.zig

# ✅ Use the build system instead
zig build test
```

The extended coverage tests are properly integrated into the build system and will run automatically with `zig build test`.

## 📊 Performance Comparison / 性能对比

The P2 implementation provides significant improvements:

| Feature | Before P2 | After P2 | Improvement |
|---------|-----------|----------|-------------|
| CLI Capability | Basic | Professional | Multiple formats, batch processing |
| Performance Analysis | None | Comprehensive | Benchmarking suite with optimization recommendations |
| Output Options | Console only | Console/JSON/CSV/XML | 4x output format options |
| Batch Processing | Manual | Automated | Batch mode support |
| Execution Metrics | None | Detailed | Time, throughput, complexity analysis |

## 🎯 Impact Summary / 影响总结

P2 features transform sts-zig into a production-ready statistical testing suite:

- **Professional CLI**: Suitable for integration into automated testing pipelines
- **Performance Monitoring**: Enables continuous performance optimization
- **Multiple Output Formats**: Supports various integration scenarios
- **Batch Processing**: Efficient handling of large-scale data analysis
- **Comprehensive Metrics**: Detailed execution statistics for optimization

These features position sts-zig as a competitive alternative to commercial statistical testing suites while maintaining the benefits of being written in pure Zig.