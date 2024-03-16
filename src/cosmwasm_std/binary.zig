const std = @import("std");
const to_json_string = @import("./serde.zig").to_json_string;
const debug = @import("api.zig").debug;

pub const Binary = std.ArrayList(u8);

pub fn to_json_binary(v: anytype, allocator: std.mem.Allocator) !Binary {
    // serialize the query result
    const json_array_list = try to_json_string(v, allocator);
    defer json_array_list.deinit();
    const json_str = json_array_list.items;

    // base64 encode the query result
    const enc = std.base64.url_safe.Encoder;
    const res_size = enc.calcSize(json_str.len);
    const buf = try allocator.alloc(u8, res_size);
    const data = enc.encode(buf, json_str);

    return Binary.fromOwnedSlice(allocator, @constCast(data));
}
