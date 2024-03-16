const std = @import("std");
const imports = @import("imports.zig");

const Allocator = @import("std").mem.Allocator;
const Region = @import("memory.zig").Region;

pub fn debug(comptime fmt: []const u8, args: anytype, allocator: Allocator) void {
    const str = std.fmt.allocPrint(allocator, fmt, args) catch unreachable;
    defer allocator.free(str);

    const src = Region.from_slice(str, allocator) catch unreachable;

    imports.debug(@intFromPtr(src));
    defer src.free(allocator);
}
