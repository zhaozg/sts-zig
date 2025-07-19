const std = @import("std");
const detect = @import("detect.zig");
const io = @import("io.zig");

const frequency = @import("detects/frequency.zig");
const poker = @import("detects/poker.zig");
const runs = @import("detects/runs.zig");
const block_frequency = @import("detects/block_frequency.zig");
const cumulativeSums = @import("detects/cumulative_sums.zig");
const maurerUniversal = @import("detects/maurer_universal.zig");
const longestRun = @import("detects/longest_run.zig");
const rank = @import("detects/rank.zig");
const autocorrelation = @import("detects/autocorrelation.zig");
const approximateEntropy = @import("detects/approx_entropy.zig");
const binaryDerivative = @import("detects/binary_derivative.zig");
const linearComplexity = @import("detects/linear_complexity.zig");
const nonOverlappingTemplate = @import("detects/non_overlapping_template.zig");
const overlappingseq = @import("detects/overlapping_sequency.zig");
const overlappingTemplate = @import("detects/overlapping_template.zig");

const runDist = @import("detects/run_distribution.zig");
const randomExcursions = @import("detects/random_excursions.zig");
const randomExcursionsVarariant = @import("detects/random_excursions_variant.zig");
const serial = @import("detects/serial.zig");
const dft = @import("detects/dft.zig");

pub fn detectPrint(self: *detect.StatDetect, result: *const detect.DetectResult) void {
    std.debug.print("Test {s:>24}: passed={s}, V={d:>14.6} P={d:<10.6} Q={d:<10.6}\n",
    .{
        self.name,
        if(result.passed) "Yes" else "No ",
        result.v_value,
        result.p_value,
        result.q_value,
    });
}
pub const DetectSuite = struct {
    allocator: std.mem.Allocator,
    detects: std.ArrayList(*detect.StatDetect),

    pub fn init(allocator: std.mem.Allocator) !DetectSuite {
        return DetectSuite{
            .allocator = allocator,
            .detects = try std.ArrayList(*detect.StatDetect).initCapacity(allocator, 8),
        };
    }

    pub fn registerAll(self: *DetectSuite, param: detect.DetectParam) !void {
        const freq = try frequency.frequencyDetectStatDetect(self.allocator, param);
        try self.detects.append(freq);

        const block_freq = try block_frequency.blockFrequencyDetectStatDetect(self.allocator, param, 10);
        try self.detects.append(block_freq);

        const pok = try poker.pokerDetectStatDetect(self.allocator, param, 4);
        try self.detects.append(pok);

        const run = try runs.runsDetectStatDetect(self.allocator, param);
        try self.detects.append(run);

        const sumsums = try cumulativeSums.cumulativeSumsDetectStatDetect(self.allocator, param, true);
        try self.detects.append(sumsums);

        const univ = try maurerUniversal.maurerUniversalDetectStatDetect(self.allocator, param, 6, 10*(1<<6));
        try self.detects.append(univ);

        const longest1 = try longestRun.longestRunDetectStatDetect(self.allocator, param, 1);
        try self.detects.append(longest1);

        const longest0 = try longestRun.longestRunDetectStatDetect(self.allocator, param, 0);
        try self.detects.append(longest0);

        const rnk = try rank.rankDetectStatDetect(self.allocator, param);
        try self.detects.append(rnk);

        const corr = try autocorrelation.autocorrelationDetectStatDetect(self.allocator, param, 1);
        try self.detects.append(corr);

        const approx = try approximateEntropy.approxEntropyDetectStatDetect(self.allocator, param, 2);
        try self.detects.append(approx);

        const binary = try binaryDerivative.binaryDerivativeDetectStatDetect(self.allocator, param, 3);
        try self.detects.append(binary);

        const linear = try linearComplexity.linearComplexityDetectStatDetect(self.allocator, param);
        try self.detects.append(linear);

        const non_overlapping = try nonOverlappingTemplate.nonOverlappingTemplateDetectStatDetect(self.allocator, param);
        try self.detects.append(non_overlapping);

        const overseq = try overlappingseq.overlappingSequencyDetectStatDetect(self.allocator, param, 3);
        try self.detects.append(overseq);

        const overlapping = try overlappingTemplate.overlappingTemplateDetectStatDetect(self.allocator, param);
        try self.detects.append(overlapping);

        const run_dist = try runDist.runDistributionDetectStatDetect(self.allocator, param);
        try self.detects.append(run_dist);

        const random_excursions = try randomExcursions.randomExcursionsDetectStatDetect(self.allocator, param);
        try self.detects.append(random_excursions);

        const random_excursions_variant = try randomExcursionsVarariant.randomExcursionsVariantDetectStatDetect(self.allocator, param);
        try self.detects.append(random_excursions_variant);

        const serial_detect = try serial.serialDetectStatDetect(self.allocator, param);
        try self.detects.append(serial_detect);

        const dft_detect = try dft.dftDetectStatDetect(self.allocator, param);
        try self.detects.append(dft_detect);
    }

    pub fn runAll(self: *DetectSuite, bits: *const io.BitInputStream) !void {
        for (self.detects.items) |t| {
            t.init(t.param);
            bits.reset();
            const result = t.iterate(bits);
            detectPrint(t, &result);
            t.destroy();
        }
    }
};
