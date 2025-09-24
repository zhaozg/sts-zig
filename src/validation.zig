const std = @import("std");
const detect = @import("detect.zig");
const io = @import("io.zig");

/// Input validation utilities for statistical tests
pub const ValidationError = error{
    InvalidDataSize,
    InvalidParameters,
    InsufficientData,
    InvalidBitSequence,
};

/// Minimum required data sizes for different algorithms (in bits)
pub const MinDataRequirements = struct {
    pub const FREQUENCY = 100;
    pub const BLOCK_FREQUENCY = 100;
    pub const RUNS = 100;
    pub const LONGEST_RUN = 128;
    pub const RANK = 1024; // 32*32 minimum
    pub const DFT = 1000;
    pub const NON_OVERLAPPING_TEMPLATE = 1000;
    pub const OVERLAPPING_TEMPLATE = 1032;
    pub const MAURER_UNIVERSAL = 387840; // L=6, Q=640*6*101
    pub const UNIVERSAL = MAURER_UNIVERSAL; // Alias
    pub const RANDOM_EXCURSIONS = 1000;
    pub const RANDOM_EXCURSIONS_VARIANT = 1000;
    pub const SERIAL = 100;
    pub const APPROX_ENTROPY = 100;
    pub const CUMULATIVE_SUMS = 100;
    pub const POKER = 100;
    pub const AUTOCORRELATION = 100;
    pub const BINARY_DERIVATIVE = 100;
    pub const OVERLAPPING_SEQUENCY = 100;
    pub const LINEAR_COMPLEXITY = 1000;
};

/// Validate input data size for specific algorithm
pub fn validateDataSize(algorithm: detect.DetectType, data_size: usize) ValidationError!void {
    const min_size: usize = switch (algorithm) {
        .Frequency => MinDataRequirements.FREQUENCY,
        .BlockFrequency => MinDataRequirements.BLOCK_FREQUENCY,
        .Runs => MinDataRequirements.RUNS,
        .LongestRun => MinDataRequirements.LONGEST_RUN,
        .Rank => MinDataRequirements.RANK,
        .Dft => MinDataRequirements.DFT,
        .NonOverlappingTemplate => MinDataRequirements.NON_OVERLAPPING_TEMPLATE,
        .OverlappingTemplate => MinDataRequirements.OVERLAPPING_TEMPLATE,
        .Universal => MinDataRequirements.MAURER_UNIVERSAL,
        .MaurerUniversal => MinDataRequirements.MAURER_UNIVERSAL,
        .RandomExcursions => MinDataRequirements.RANDOM_EXCURSIONS,
        .RandomExcursionsVariant => MinDataRequirements.RANDOM_EXCURSIONS_VARIANT,
        .Serial => MinDataRequirements.SERIAL,
        .ApproxEntropy => MinDataRequirements.APPROX_ENTROPY,
        .CumulativeSums => MinDataRequirements.CUMULATIVE_SUMS,
        .Poker => MinDataRequirements.POKER,
        .Autocorrelation => MinDataRequirements.AUTOCORRELATION,
        .AutoCorrelation => MinDataRequirements.AUTOCORRELATION,
        .BinaryDerivative => MinDataRequirements.BINARY_DERIVATIVE,
        .OverlappingSequency => MinDataRequirements.OVERLAPPING_SEQUENCY,
        .LinearComplexity => MinDataRequirements.LINEAR_COMPLEXITY,
        else => 100, // Default minimum
    };
    
    if (data_size < min_size) {
        return ValidationError.InsufficientData;
    }
}

/// Validate bit sequence integrity
pub fn validateBitSequence(bits: *const io.BitInputStream) ValidationError!void {
    // Check if the bit stream is readable by testing len()
    const stream_len = bits.len();
    if (stream_len == 0) {
        return ValidationError.InvalidBitSequence;
    }
    
    // Since we can't restore position, just check that stream is accessible
    // The actual validation will happen during test execution
}

/// Validate test parameters for specific algorithms
pub fn validateParameters(param: *const detect.DetectParam) ValidationError!bool {
    // Basic parameter validation
    if (param.n == 0) {
        return ValidationError.InvalidDataSize;
    }
    
    // Algorithm-specific parameter validation
    switch (param.type) {
        .Poker => {
            if (param.extra) |extra| {
                const poker_param: *const anyopaque = extra;
                // For poker test, m should be 2, 4, or 8
                _ = poker_param;
                // Additional validation can be added here
            }
        },
        .MaurerUniversal => {
            // Universal test requires specific L and Q values
            if (param.n < MinDataRequirements.UNIVERSAL) {
                return ValidationError.InsufficientData;
            }
        },
        .Rank => {
            // Rank test requires data size to be multiple of 1024
            if (param.n < MinDataRequirements.RANK or param.n % 1024 != 0) {
                return ValidationError.InvalidParameters;
            }
        },
        else => {
            // Standard validation for other algorithms
        }
    }
    
    return true;
}

/// Comprehensive validation function
pub fn validateInput(param: *const detect.DetectParam, bits: *const io.BitInputStream) ValidationError!void {
    // Validate data size
    try validateDataSize(param.type, param.n);
    
    // Validate bit sequence
    try validateBitSequence(bits);
    
    // Validate parameters
    _ = try validateParameters(param);
}

/// Get recommended data size for optimal results
pub fn getRecommendedDataSize(algorithm: detect.DetectType) usize {
    return switch (algorithm) {
        .Frequency => 10000,
        .BlockFrequency => 10000,
        .Runs => 10000,
        .LongestRun => 10000,
        .Rank => 100000, // Multiple of 1024 for better matrix formation
        .Dft => 10000,
        .NonOverlappingTemplate => 100000,
        .OverlappingTemplate => 100000,
        .MaurerUniversal => 1000000, // Large data needed for accurate entropy estimation
        .RandomExcursions => 100000,
        .RandomExcursionsVariant => 100000,
        .Serial => 10000,
        .ApproxEntropy => 10000,
        .CumulativeSums => 10000,
        .Poker => 10000,
        .Autocorrelation => 10000,
        .BinaryDerivative => 10000,
        .OverlappingSequency => 10000,
        .LinearComplexity => 10000,
        else => 10000,
    };
}

test "validation: data size requirements" {
    try validateDataSize(.Frequency, 1000);
    try std.testing.expectError(ValidationError.InsufficientData, validateDataSize(.Frequency, 50));
    
    try validateDataSize(.Rank, 2048);
    try std.testing.expectError(ValidationError.InsufficientData, validateDataSize(.Rank, 512));
}

test "validation: recommended data sizes" {
    const freq_size = getRecommendedDataSize(.Frequency);
    const rank_size = getRecommendedDataSize(.Rank);
    const universal_size = getRecommendedDataSize(.Universal);
    
    try std.testing.expect(freq_size >= MinDataRequirements.FREQUENCY);
    try std.testing.expect(rank_size >= MinDataRequirements.RANK);
    try std.testing.expect(universal_size >= MinDataRequirements.UNIVERSAL);
}