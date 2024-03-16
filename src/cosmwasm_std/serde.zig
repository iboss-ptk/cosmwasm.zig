const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn to_json_string(v: anytype, allocator: Allocator) !std.ArrayList(u8) {
    var string = std.ArrayList(u8).init(allocator);
    try std.json.stringify(v, .{}, string.writer());

    return string;
}

pub fn from_json_slice(t: anytype, slice: []const u8, allocator: Allocator) !t {
    const parsed = try std.json.parseFromSlice(
        t,
        allocator,
        slice,
        .{},
    );
    defer parsed.deinit();

    return parsed.value;
}
