const std = @import("std");
const imports = @import("imports.zig");

const Allocator = std.mem.Allocator;
const Region = @import("memory.zig").Region;

pub fn write(key: []const u8, value: []const u8, allocator: Allocator) void {
    const key_region = Region.from_slice(@constCast(key), allocator) catch unreachable;
    defer key_region.free(allocator);

    const value_region = Region.from_slice(@constCast(value), allocator) catch unreachable;
    defer value_region.free(allocator);

    imports.db_write(@intFromPtr(key_region), @intFromPtr(value_region));
}

pub fn read(key: []const u8, allocator: Allocator) ?StoreReader {
    const key_region = Region.from_slice(@constCast(key), allocator) catch unreachable;
    defer key_region.free(allocator);

    const value_region_ptr = imports.db_read(@intFromPtr(key_region));
    if (value_region_ptr == 0) {
        return null;
    }

    return StoreReader.init(value_region_ptr, allocator);
}

pub const StoreReader = struct {
    allocator: Allocator,
    region: *Region,

    pub fn init(region_ptr: u32, allocator: Allocator) StoreReader {
        const region: *Region = @ptrFromInt(region_ptr);
        return StoreReader{ .allocator = allocator, .region = region };
    }

    pub fn deinit(self: StoreReader) void {
        self.region.free(self.allocator);
    }

    pub fn read(self: StoreReader) []const u8 {
        return self.region.to_slice();
    }
};
