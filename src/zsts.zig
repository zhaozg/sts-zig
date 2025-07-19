pub const std = @import("std");
pub const detect = @import("detect.zig");
pub const io = @import("io.zig");

pub const frequency = @import("detects/frequency.zig");
pub const poker = @import("detects/poker.zig");
pub const runs = @import("detects/runs.zig");
pub const block_frequency = @import("detects/block_frequency.zig");
pub const cumulativeSums = @import("detects/cumulative_sums.zig");
pub const maurerUniversal = @import("detects/maurer_universal.zig");
pub const longestRun = @import("detects/longest_run.zig");
pub const rank = @import("detects/rank.zig");
pub const autocorrelation = @import("detects/autocorrelation.zig");
pub const approximateEntropy = @import("detects/approx_entropy.zig");
pub const binaryDerivative = @import("detects/binary_derivative.zig");
pub const linearComplexity = @import("detects/linear_complexity.zig");
pub const nonOverlappingTemplate = @import("detects/non_overlapping_template.zig");
pub const overlappingseq = @import("detects/overlapping_sequency.zig");
pub const overlappingTemplate = @import("detects/overlapping_template.zig");

pub const runDist = @import("detects/run_distribution.zig");
pub const randomExcursions = @import("detects/random_excursions.zig");
pub const randomExcursionsVariant = @import("detects/random_excursions_variant.zig");
pub const serial = @import("detects/serial.zig");
pub const dft = @import("detects/dft.zig");
