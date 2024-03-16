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

pub fn to_base64_json(v: anytype, allocator: Allocator) ![]const u8 {
    // serialize the query result
    const json_array_list = try to_json_string(v, allocator);
    defer json_array_list.deinit();
    const json_str = json_array_list.items;

    // base64 encode the query result
    const enc = std.base64.url_safe.Encoder;
    const buf = try allocator.alloc(u8, enc.calcSize(json_str.len));

    // TODO: This should not work, maybe it just works because it's not being reallocated before used
    defer allocator.free(buf);

    return enc.encode(buf, json_str);
}
