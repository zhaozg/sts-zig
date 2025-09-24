const std = @import("std");
const zsts = @import("zsts");
const validation = zsts.validation;
const detect = zsts.detect;
const io = zsts.io;

test "validation: minimum data requirements" {
    // Test frequency algorithm
    try validation.validateDataSize(.Frequency, 1000);
    try std.testing.expectError(validation.ValidationError.InsufficientData, validation.validateDataSize(.Frequency, 50));
    
    // Test rank algorithm
    try validation.validateDataSize(.Rank, 2048);
    try std.testing.expectError(validation.ValidationError.InsufficientData, validation.validateDataSize(.Rank, 512));
    
    // Test universal algorithm  
    try validation.validateDataSize(.MaurerUniversal, 400000);
    try std.testing.expectError(validation.ValidationError.InsufficientData, validation.validateDataSize(.MaurerUniversal, 10000));
}

test "validation: recommended data sizes" {
    const freq_size = validation.getRecommendedDataSize(.Frequency);
    const rank_size = validation.getRecommendedDataSize(.Rank);
    const universal_size = validation.getRecommendedDataSize(.MaurerUniversal);
    
    try std.testing.expect(freq_size >= validation.MinDataRequirements.FREQUENCY);
    try std.testing.expect(rank_size >= validation.MinDataRequirements.RANK);
    try std.testing.expect(universal_size >= validation.MinDataRequirements.MAURER_UNIVERSAL);
    
    // Ensure recommended sizes are reasonable for good statistical power
    try std.testing.expect(freq_size >= 10000);
    try std.testing.expect(rank_size >= 100000);
    try std.testing.expect(universal_size >= 1000000);
}

test "validation: parameter validation" {
    // Valid parameters
    const valid_param = detect.DetectParam{
        .type = .Frequency,
        .n = 10000,
        .extra = null,
    };
    
    const result = try validation.validateParameters(&valid_param);
    try std.testing.expect(result == true);
    
    // Invalid parameters - zero size
    const invalid_param = detect.DetectParam{
        .type = .Frequency,
        .n = 0,
        .extra = null,
    };
    
    try std.testing.expectError(validation.ValidationError.InvalidDataSize, validation.validateParameters(&invalid_param));
    
    // Test rank-specific validation
    const rank_valid = detect.DetectParam{
        .type = .Rank,
        .n = 32768, // Multiple of 1024
        .extra = null,
    };
    
    const rank_result = try validation.validateParameters(&rank_valid);
    try std.testing.expect(rank_result == true);
    
    const rank_invalid = detect.DetectParam{
        .type = .Rank,
        .n = 1500, // Not multiple of 1024
        .extra = null,
    };
    
    try std.testing.expectError(validation.ValidationError.InvalidParameters, validation.validateParameters(&rank_invalid));
}

test "validation: bit sequence validation" {
    const allocator = std.testing.allocator;
    
    // Create a valid bit sequence
    const test_data = "1101001011010010110100101101001011010010110100101101001011010010110100101101001011010010";
    const input_stream = io.InputStream.fromMemory(allocator, test_data);
    const bits = io.BitInputStream.fromAsciiInputStream(allocator, input_stream);
    defer bits.close();
    
    // Should pass validation
    try validation.validateBitSequence(&bits);
}

test "validation: comprehensive input validation" {
    const allocator = std.testing.allocator;
    
    // Create test data
    const test_data = "1101001011010010110100101101001011010010110100101101001011010010110100101101001011010010" ** 50;
    const input_stream = io.InputStream.fromMemory(allocator, test_data);
    const bits = io.BitInputStream.fromAsciiInputStream(allocator, input_stream);
    defer bits.close();
    
    const param = detect.DetectParam{
        .type = .Frequency,
        .n = bits.len(),
        .extra = null,
    };
    
    // Should pass comprehensive validation
    try validation.validateInput(&param, &bits);
    
    // Test with insufficient data
    const small_param = detect.DetectParam{
        .type = .Frequency,
        .n = 50, // Too small
        .extra = null,
    };
    
    try std.testing.expectError(validation.ValidationError.InsufficientData, validation.validateInput(&small_param, &bits));
}

test "validation: all algorithm minimum requirements" {
    const algorithms = [_]detect.DetectType{
        .Frequency,
        .BlockFrequency,
        .Runs,
        .LongestRun,
        .Rank,
        .Dft,
        .NonOverlappingTemplate,
        .OverlappingTemplate,
        .MaurerUniversal,
        .RandomExcursions,
        .RandomExcursionsVariant,
        .Serial,
        .ApproxEntropy,
        .CumulativeSums,
        .Poker,
        .Autocorrelation,
        .BinaryDerivative,
        .OverlappingSequency,
        .LinearComplexity,
    };
    
    // Verify all algorithms have reasonable minimum requirements
    for (algorithms) |algorithm| {
        const recommended = validation.getRecommendedDataSize(algorithm);
        try std.testing.expect(recommended >= 100); // At least 100 bits
        try std.testing.expect(recommended <= 2000000); // At most 2M bits for practicality
        
        // Test that recommended size passes validation
        try validation.validateDataSize(algorithm, recommended);
    }
}