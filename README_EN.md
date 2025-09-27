# STS-Zig: Statistical Test Suite in Zig

[![CI](https://github.com/zhaozg/sts-zig/workflows/CI/badge.svg)](https://github.com/zhaozg/sts-zig/actions)
[![Zig Version](https://img.shields.io/badge/zig-0.14.1+-blue.svg)](https://ziglang.org/download/)
[![Repository Size](https://img.shields.io/github/repo-size/zhaozg/sts-zig)](https://github.com/zhaozg/sts-zig)
[![Last Commit](https://img.shields.io/github/last-commit/zhaozg/sts-zig)](https://github.com/zhaozg/sts-zig/commits/main)
[![Issues](https://img.shields.io/github/issues/zhaozg/sts-zig)](https://github.com/zhaozg/sts-zig/issues)
[![Pull Requests](https://img.shields.io/github/issues-pr/zhaozg/sts-zig)](https://github.com/zhaozg/sts-zig/pulls)

A comprehensive Statistical Test Suite (STS) implemented in Zig, supporting multiple statistical testing methods for cryptography and data analysis applications. Fully compliant with both NIST SP 800-22a and GMT 0005-2021 standards.

## Features

- **🚀 Pure Zig Implementation**: Zero external dependencies - no GSL required
- **📊 Comprehensive Coverage**: 20+ statistical algorithms covering NIST and GMT standards
- **⚡ High Performance**: Optimized iterative FFT with O(1) stack usage
- **🎯 Mathematical Accuracy**: Relative errors < 1e-14 for all mathematical functions
- **🔒 Cryptography Ready**: Suitable for randomness testing in security applications
- **🌐 Cross-Platform**: Works on Windows, Linux, macOS without external libraries

## Quick Start

### Prerequisites

- [Zig 0.14.1+](https://ziglang.org/download/) - Download the latest version

### Installation

```bash
git clone https://github.com/zhaozg/sts-zig.git
cd sts-zig
zig build
```

### Usage

```bash
# Run the STS suite
./zig-out/bin/zsts -h

# Run all tests
zig build test

# Run specific test category
zig test test/GMT0005_test.zig
zig test test/SP800_22r1_test.zig
```

## Supported Statistical Tests

### NIST SP 800-22 Tests

| Test                       | Implementation   | Status   |
| ------                     | ---------------- | -------- |
| Frequency (Monobit)        | ✅               | Complete |
| Block Frequency            | ✅               | Complete |
| Runs                       | ✅               | Complete |
| Longest Run of Ones        | ✅               | Complete |
| Binary Matrix Rank         | ✅               | Complete |
| Discrete Fourier Transform | ✅               | Complete |
| Non-overlapping Template   | ✅               | Complete |
| Overlapping Template       | ✅               | Complete |
| Maurer's Universal         | ✅               | Complete |
| Linear Complexity          | ✅               | Complete |
| Serial Test                | ✅               | Complete |
| Approximate Entropy        | ✅               | Complete |
| Cumulative Sums            | ✅               | Complete |
| Random Excursions          | ✅               | Complete |
| Random Excursions Variant  | ✅               | Complete |

### GMT 0005-2021 Tests

| Test                    | Implementation   | Status   |
| ------                  | ---------------- | -------- |
| Frequency Test          | ✅               | Complete |
| Block Frequency Test    | ✅               | Complete |
| Poker Test              | ✅               | Complete |
| Overlapping Subsequence | ✅               | Complete |
| Runs Test               | ✅               | Complete |
| Run Distribution        | ✅               | Complete |
| Longest Run Test        | ✅               | Complete |
| Binary Derivative       | ✅               | Complete |
| Autocorrelation         | ✅               | Complete |

## Architecture

### Project Structure

```
src/
├── main.zig               # Entry point and CLI
├── detect.zig             # Core detection framework
├── math.zig               # Pure Zig mathematical functions
├── io.zig                 # Input/output handling
├── matrix.zig             # Matrix operations for rank tests
└── detects/               # Individual test implementations
    ├── frequency.zig      # Frequency-based tests
    ├── runs.zig           # Run-based tests
    ├── dft.zig            # Discrete Fourier Transform
    ├── rank.zig           # Matrix rank test
    ├── poker.zig          # Poker test
    └── ...                # Other statistical tests

test/
├── GMT0005_test.zig       # GMT standard compliance tests
├── SP800_22r1_test.zig    # NIST standard compliance tests
```

### Core Components

- **Detection Framework**: Unified interface for all statistical tests
- **Mathematical Library**: High-precision implementations of gamma functions, FFT, etc.
- **I/O System**: Flexible input handling for various data formats
- **Test Suite**: Comprehensive validation against known reference values

## Mathematical Functions

All mathematical functions are implemented in pure Zig with no external dependencies:

- **Incomplete Gamma Function** (`igamc`): Lanczos approximation with continued fractions
- **Gamma Logarithm** (`gammaln`): High-precision implementation with reflection formula
- **Fast Fourier Transform**: Iterative Cooley-Tukey algorithm with bit-reversal optimization
- **Error Function** (`erfc`): Numerical implementation for statistical calculations

### Key Benefits

- **O(1) Stack Usage**: No recursion overhead
- **Better Cache Locality**: Sequential memory access patterns
- **Cross-Platform**: No external library dependencies
- **Memory Efficient**: Minimal allocation overhead

## Testing and Validation

### Test Coverage

- **24+ Test Cases**: Comprehensive coverage of all implemented algorithms
- **Reference Validation**: Cross-validated against SciPy and GSL reference implementations
- **Edge Case Testing**: Boundary conditions, error handling, and invalid inputs
- **Performance Testing**: Benchmarking and complexity verification

### Quality Assurance

- **Mathematical Accuracy**: < 1e-14 relative error for all functions
- **Standard Compliance**: Full NIST SP 800-22a and GMT 0005-2021 compliance
- **Error Handling**: Graceful handling of invalid inputs without crashes
- **Memory Safety**: Zig's compile-time memory safety guarantees

## Development

### Building from Source

```bash
# Debug build
zig build

# Release build
zig build -Doptimize=ReleaseFast

# Run tests
zig build test
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-test`)
3. Implement your changes with tests
4. Ensure all tests pass (`zig build test`)
5. Submit a pull request

### Code Style

- Follow Zig's standard formatting (`zig fmt`)
- Add comprehensive tests for new features
- Document public APIs with doc comments
- Maintain compatibility with existing interfaces

## Applications

### Cryptographic Testing

- **Random Number Generator Validation**: Test PRNG output quality
- **Key Material Analysis**: Validate cryptographic key randomness
- **Entropy Source Testing**: Assess hardware random number generators

### Data Analysis

- **Signal Processing**: Analyze digital signal randomness properties
- **Monte Carlo Validation**: Verify simulation randomness assumptions
- **Quality Control**: Statistical process control applications

## References

- [NIST SP 800-22 Rev. 1a](https://csrc.nist.gov/publications/detail/sp/800-22/rev-1a/final)
- [GMT 0005-2021](https://www.oscca.gov.cn/sca/xxgk/2021-07/26/1002389/files/b552a68f57a84fdb958ce73bcadc3a3e.pdf)
- [Zig Language Reference](https://ziglang.org/documentation/master/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- NIST for the SP 800-22 statistical test suite specification
- GMT for the 0005-2021 cryptographic randomness testing standard
- The Zig community for the excellent programming language and ecosystem

---

**Note**: This is a research and educational implementation. For production cryptographic applications, please validate the results against certified implementations and consider professional cryptographic review.
