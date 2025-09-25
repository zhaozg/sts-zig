# Math Functions Documentation

## Error Functions (erf and erfc)

This document describes the implementation of the error function `erf(x)` and complementary error function `erfc(x)` in the statistical test suite.

### Mathematical Definition

**Error Function (erf)**:
```
erf(x) = (2/√π) ∫₀ˣ e^(-t²) dt
```

**Complementary Error Function (erfc)**:
```
erfc(x) = 1 - erf(x) = (2/√π) ∫ₓ^∞ e^(-t²) dt
```

### Implementation Principles

#### erf(x) Implementation

The error function is implemented using different algorithms based on the input range:

1. **Special Cases**:
   - `erf(0) = 0`
   - `erf(∞) = 1`, `erf(-∞) = -1`
   - `erf(NaN) = NaN`

2. **Small to Medium Values (|x| < 3.0)**:
   Uses Taylor series expansion:
   ```
   erf(x) = (2/√π) * x * Σ(n=0 to ∞) [(-1)^n * x^(2n)] / [n! * (2n+1)]
   ```
   
   Implementation details:
   - Maximum 30 iterations with early convergence detection
   - Convergence threshold: `1e-16` (machine precision)
   - Uses precise constant: `2/√π = 1.1283791670955125738961589031215`

3. **Large Values (|x| ≥ 6.0)**:
   Returns limit values directly: `±1`

4. **Medium-Large Values (3.0 ≤ |x| < 6.0)**:
   Uses the identity: `erf(x) = 1 - erfc(x)`

#### erfc(x) Implementation

The complementary error function implementation:

1. **Special Cases**:
   - `erfc(0) = 1`
   - `erfc(∞) = 0`, `erfc(-∞) = 2`
   - `erfc(NaN) = NaN`

2. **Negative Values**:
   Uses symmetry: `erfc(-x) = 2 - erfc(x)`

3. **Small to Medium Values (x < 3.0)**:
   Uses the identity: `erfc(x) = 1 - erf(x)`

4. **Large Values (x ≥ 6.0)**:
   Returns `0` directly

5. **Medium-Large Values (3.0 ≤ x < 6.0)**:
   Uses asymptotic expansion:
   ```
   erfc(x) ≈ (e^(-x²))/(x√π) * [1 - 1/(2x²) + 3/(4x⁴) - ...]
   ```

### Performance Characteristics

#### Time Complexity
- **erf(x)**: O(1) to O(30) iterations depending on convergence
- **erfc(x)**: O(1) for most cases, delegates to erf(x) for small values

#### Accuracy
- Relative error typically < `1e-15`
- Tested accuracy: `1e-16` for most test cases
- Maintains mathematical identity: `erf(x) + erfc(x) = 1`

### Limitations and Constraints

#### Input Range Limitations
1. **Extreme Values**: For `|x| > 6.0`, functions return limit values without computation
2. **Precision**: Limited by double-precision floating-point arithmetic (IEEE 754)
3. **Overflow Protection**: Large exponentials are avoided through range-specific algorithms

#### Numerical Stability
1. **Convergence**: Taylor series may require up to 30 iterations for high precision
2. **Cancellation**: For values near boundaries, some precision loss may occur
3. **Recursion**: `erfc(-x)` uses recursive call, limited stack depth for extreme negative values

#### Performance Constraints
1. **Small Values**: Taylor series requires multiple iterations
2. **Medium Values**: Cross-references between erf/erfc may cause double computation
3. **Memory**: No lookup tables used, all computations are analytical

### Usage Guidelines

#### Recommended Input Ranges
- **Optimal**: `-3.0 ≤ x ≤ 3.0` (direct Taylor series)
- **Acceptable**: `-6.0 ≤ x ≤ 6.0` (combined algorithms)  
- **Extreme**: `|x| > 6.0` (limit values returned)

#### Accuracy Expectations
- **High Precision**: Relative error < `1e-12` for most inputs
- **Standard Precision**: Relative error < `1e-10` for statistical applications
- **Mathematical Identities**: `erf(-x) = -erf(x)`, `erfc(x) + erf(x) = 1`

### Testing and Validation

The implementation is validated against:
1. **Reference Values**: Mathematically computed expected results
2. **Identity Tests**: Verification of mathematical properties
3. **Performance Tests**: Execution time under 1ms for typical inputs
4. **Edge Cases**: NaN, infinity, and boundary value handling

### Integration with Statistical Tests

These error functions are critical for:
- **Normal Distribution**: Cumulative distribution function calculations
- **Chi-squared Tests**: p-value computations via incomplete gamma function
- **Statistical Analysis**: Various probability and significance testing

The implementation prioritizes both accuracy and performance to support real-time statistical computations without compromising mathematical correctness.