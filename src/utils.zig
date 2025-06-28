
pub fn clamp(val: i32, min: i32, max: i32) i32 {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}
