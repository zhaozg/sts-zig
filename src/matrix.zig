const std = @import("std");

const BitSequence = u1;

pub fn createMatrix(M: usize, Q: usize) ![][]BitSequence {
    var allocator = std.heap.page_allocator;
    const matrix = try allocator.alloc([]BitSequence, M);
    for (matrix) |*row| {
        row.* = try allocator.alloc(BitSequence, Q);
        for (row.*) |*v| v.* = 0;
    }
    return matrix;
}

pub fn resetMatrix(matrix: [][]BitSequence) void {
    for (matrix) |*row| {
        for (row.*) |*v| v.* = 0;
    }
}

fn swap_rows(matrix: [][]BitSequence, row1: usize, row2: usize) void {
    const tmp = matrix[row1];
    matrix[row1] = matrix[row2];
    matrix[row2] = tmp;
}

fn perform_elementary_row_operations(matrix: [][]BitSequence, flag: u8, i: usize, M: usize, Q: usize) void {
    if (flag == 0) { // forward
        for ((i+1)..M) |j| {
            if (matrix[j][i] == 1) {
                for (i..Q) |k| {
                    matrix[j][k] = (matrix[j][k] ^ matrix[i][k]);
                }
            }
        }
    } else { // backward
        var j = i;
        while (j > 0) : (j -= 1) {
            const idx = j - 1;
            if (matrix[idx][i] == 1) {
                for (0..Q) |k| {
                    matrix[idx][k] = (matrix[idx][k] ^ matrix[i][k]);
                }
            }
        }
    }
}

fn find_unit_element_and_swap(matrix: [][]BitSequence, flag: u8, i: usize, M: usize, Q: usize) bool {
    _ = Q;
    if (flag == 0) { // forward
        var index = i + 1;
        while (index < M and matrix[index][i] == 0) : (index += 1) {}
        if (index < M) {
            swap_rows(matrix, i, index);
            return true;
        }
    } else { // backward
        var index = i;
        while (index > 0) : (index -= 1) {
            const idx = index - 1;
            if (matrix[idx][i] == 1) {
                swap_rows(matrix, i, idx);
                return true;
            }
        }
    }
    return false;
}

pub fn determine_rank(matrix: [][]BitSequence, m: usize, M: usize, Q: usize) usize {
    var rank = m;
    for (0..M)|i| {
        var allZeroes = true;
        for (0..Q) |j| {
            if (matrix[i][j] == 1) {
                allZeroes = false;
                break;
            }
        }
        if (allZeroes) rank -= 1;
    }
    return rank;
}

pub fn computeRank(matrix: [][]BitSequence, M: usize, Q: usize) usize {
    const m = if (M < Q) M else Q;
    // Forward elimination
    for (0..(m-1))|i| {
        if (matrix[i][i] == 1) {
            perform_elementary_row_operations(matrix, 0, i, M, Q);
        } else if (matrix[i][i] == 0) {
            if (find_unit_element_and_swap(matrix, 0, i, M, Q)) {
                perform_elementary_row_operations(matrix, 0, i, M, Q);
            }
        } else {
            @panic("matrix[i][i] should be 0 or 1");
        }
    }
    // Backward elimination
    var i = m;
    while (i > 1) : (i -= 1) {
        const idx = i - 1;
        if (matrix[idx][idx] == 1) {
            perform_elementary_row_operations(matrix, 1, idx, M, Q);
        } else if (matrix[idx][idx] == 0) {
            if (find_unit_element_and_swap(matrix, 1, idx, M, Q)) {
                perform_elementary_row_operations(matrix, 1, idx, M, Q);
            }
        } else {
            @panic("matrix[i][i] should be 0 or 1");
        }
    }
    return determine_rank(matrix, m, M, Q);
}

test "matrix" {
    const M = 3;
    const Q = 3;
    var matrix = try createMatrix(M, Q);
    // 例子: 3x3 单位矩阵
    matrix[0][0] = 1; matrix[0][1] = 0; matrix[0][2] = 0;
    matrix[1][0] = 0; matrix[1][1] = 1; matrix[1][2] = 0;
    matrix[2][0] = 0; matrix[2][1] = 0; matrix[2][2] = 1;
    const rank = computeRank(matrix, M, Q);
    std.debug.print("Rank = {}\n", .{rank});
}
