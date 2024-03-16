const std = @import("std");

pub fn max_digits(comptime t: type) comptime_int {
    const max = std.math.maxInt(t);
    if (max < 10) return 1;

    comptime var digits = 0;
    comptime var num = max;
    while (num > 0) : (num /= 10) {
        digits += 1;
    }

    return digits;
}
