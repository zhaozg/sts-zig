const std = @import("std");
const detect = @import("detect.zig");
const io = @import("io.zig");
const compat = @import("compat.zig");

const frequency = @import("detects/frequency.zig");
const block_frequency = @import("detects/block_frequency.zig");
const poker = @import("detects/poker.zig");
const overlappingseq = @import("detects/overlapping_sequency.zig");
const runs = @import("detects/runs.zig");
const runDist = @import("detects/run_distribution.zig");
const longestRun = @import("detects/longest_run.zig");
const binaryDerivative = @import("detects/binary_derivative.zig");
const autocorrelation = @import("detects/autocorrelation.zig");
const rank = @import("detects/rank.zig");
const cumulativeSums = @import("detects/cumulative_sums.zig");
const approximateEntropy = @import("detects/approx_entropy.zig");
const linearComplexity = @import("detects/linear_complexity.zig");
const maurerUniversal = @import("detects/maurer_universal.zig");
const dft = @import("detects/dft.zig");

const nonOverlappingTemplate = @import("detects/non_overlapping_template.zig");
const overlappingTemplate = @import("detects/overlapping_template.zig");
const serial = @import("detects/serial.zig");
const randomExcursions = @import("detects/random_excursions.zig");
const randomExcursionsVarariant = @import("detects/random_excursions_variant.zig");

pub const DetectSuite = struct {
    allocator: std.mem.Allocator,
    detects: compat.ArrayList(*detect.StatDetect),

    pub fn init(allocator: std.mem.Allocator) !DetectSuite {
        return DetectSuite{
            .allocator = allocator,
            .detects = try compat.ArrayList(*detect.StatDetect).initCapacity(allocator, 8),
        };
    }

    pub fn registerAll(self: *DetectSuite, param: detect.DetectParam) !void {
        // Register all tests - kept for backward compatibility
        return self.registerSelected(param, null);
    }

    pub fn registerSelected(self: *DetectSuite, param: detect.DetectParam, selected_tests: ?[][]const u8) !void {
        const shouldInclude = struct {
            fn call(test_name: []const u8, tests: ?[][]const u8) bool {
                if (tests == null) return true; // Include all if no filter
                for (tests.?) |selected| {
                    if (std.mem.eql(u8, test_name, selected)) return true;
                }
                return false;
            }
        }.call;

        if (shouldInclude("frequency", selected_tests)) {
            const freq = try frequency.frequencyDetectStatDetect(self.allocator, param);
            try self.detects.append(freq);
        }

        if (shouldInclude("block_frequency", selected_tests)) {
            const block_freq = try block_frequency.blockFrequencyDetectStatDetect(self.allocator, param, 10);
            try self.detects.append(block_freq);
        }

        if (shouldInclude("poker", selected_tests)) {
            const pok = try poker.pokerDetectStatDetect(self.allocator, param, 4);
            try self.detects.append(pok);
        }

        if (shouldInclude("overlapping_sequency", selected_tests)) {
            const overseq = try overlappingseq.overlappingSequencyDetectStatDetect(self.allocator, param, 3);
            try self.detects.append(overseq);
        }

        if (shouldInclude("runs", selected_tests)) {
            const run = try runs.runsDetectStatDetect(self.allocator, param);
            try self.detects.append(run);
        }

        if (shouldInclude("run_distribution", selected_tests)) {
            const run_dist = try runDist.runDistributionDetectStatDetect(self.allocator, param);
            try self.detects.append(run_dist);
        }

        if (shouldInclude("longest_runs", selected_tests)) {
            const longest = try longestRun.longestRunDetectStatDetect(self.allocator, param);
            try self.detects.append(longest);
        }

        if (shouldInclude("binary_derivative", selected_tests)) {
            const binary = try binaryDerivative.binaryDerivativeDetectStatDetect(self.allocator, param, 3);
            try self.detects.append(binary);
        }

        if (shouldInclude("autocorrelation", selected_tests)) {
            const corr = try autocorrelation.autocorrelationDetectStatDetect(self.allocator, param, 1);
            try self.detects.append(corr);
        }

        if (shouldInclude("rank", selected_tests)) {
            const rnk = try rank.rankDetectStatDetect(self.allocator, param);
            try self.detects.append(rnk);
        }

        if (shouldInclude("cumulative_sums", selected_tests)) {
            const sumsums = try cumulativeSums.cumulativeSumsDetectStatDetect(self.allocator, param);
            try self.detects.append(sumsums);
        }

        if (shouldInclude("approximate_entropy", selected_tests)) {
            const approx = try approximateEntropy.approxEntropyDetectStatDetect(self.allocator, param, 2);
            try self.detects.append(approx);
        }

        if (shouldInclude("linear_complexity", selected_tests)) {
            const linear = try linearComplexity.linearComplexityDetectStatDetect(self.allocator, param);
            try self.detects.append(linear);
        }

        if (shouldInclude("universal", selected_tests)) {
            const univ = try maurerUniversal.maurerUniversalDetectStatDetect(self.allocator, param, 6, 10 * (1 << 6));
            try self.detects.append(univ);
        }

        if (shouldInclude("dft", selected_tests)) {
            const dft_detect = try dft.dftDetectStatDetect(self.allocator, param);
            try self.detects.append(dft_detect);
        }

        if (shouldInclude("non_overlapping_template", selected_tests)) {
            const non_overlapping = try nonOverlappingTemplate.nonOverlappingTemplateDetectStatDetect(self.allocator, param);
            try self.detects.append(non_overlapping);
        }

        if (shouldInclude("overlapping_template", selected_tests)) {
            const overlapping = try overlappingTemplate.overlappingTemplateDetectStatDetect(self.allocator, param);
            try self.detects.append(overlapping);
        }

        if (shouldInclude("serial", selected_tests)) {
            const serial_detect = try serial.serialDetectStatDetect(self.allocator, param);
            try self.detects.append(serial_detect);
        }

        if (shouldInclude("random_excursions", selected_tests)) {
            const random_excursions = try randomExcursions.randomExcursionsDetectStatDetect(self.allocator, param);
            try self.detects.append(random_excursions);
        }

        if (shouldInclude("random_excursions_variant", selected_tests)) {
            const random_excursions_variant = try randomExcursionsVarariant.randomExcursionsVariantDetectStatDetect(self.allocator, param);
            try self.detects.append(random_excursions_variant);
        }
    }

    pub fn runAll(self: *DetectSuite, bits: *const io.BitInputStream, level: detect.PrintLevel) !void {
        const items = self.detects.toOwnedSlice();
        for (items) |t| {
            t.init(t.param);
            bits.reset();
            _ = bits.bits();
            bits.reset();
            const result = t.iterate(bits);
            t.print(&result, level);
            t.destroy();
        }
    }
};
