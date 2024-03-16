const std = @import("std");
const serde = @import("serde.zig");
const Allocator = std.mem.Allocator;

/// Describes some data allocated in Wasm's linear memory.
/// A pointer to an instance of this can be returned over FFI boundaries.
pub const Region = extern struct {
    /// The beginning of the region expressed as bytes from the beginning of the linear memory
    offset: u32,
    /// The number of bytes available in this region
    capacity: u32,
    /// The number of bytes used in this region
    length: u32,

    /// Creates a new region of the given size.
    pub fn create(size: usize, allocator: Allocator) !*Region {
        // allocate memory according to size
        const data = allocator.alloc(u8, size) catch unreachable;

        // build region
        const region = Region.from_slice(data, allocator) catch unreachable;

        // return region pointer
        return region;
    }

    /// View wasm memory offset as a region pointer
    pub fn from_offset(offset: u32) *Region {
        return @ptrFromInt(offset);
    }

    /// View region pointer as wasm memory offset
    pub fn to_offset(self: *Region) u32 {
        return @intCast(@intFromPtr(self));
    }

    /// View region as JSON string and deserialize into a value of type `t`.
    pub fn json_deserialize(self: *Region, comptime t: type, allocator: Allocator) !t {
        return try serde.from_json_slice(t, self.to_slice(), allocator);
    }

    /// Serialize JSON string and allocate into new region.
    pub fn to_json_region(value: anytype, allocator: Allocator) !*Region {
        const json_string = try serde.to_json_string(value, allocator);

        const region = try Region.from_array_list(json_string, allocator);
        return region;
    }

    /// Creates a new region from a slice of bytes.
    pub fn from_slice(slice: []const u8, allocator: Allocator) !*Region {
        // allocate region
        const region = try allocator.create(Region);

        // build region
        region.offset = @intCast(@intFromPtr(slice.ptr));
        region.length = @intCast(slice.len);
        region.capacity = @intCast(slice.len);

        // return region pointer
        return region;
    }

    pub fn to_slice(self: *Region) []u8 {
        // create multi-item ptr from offset
        const ptr: [*]u8 = @ptrFromInt(self.offset);

        // create bytes slice
        // essentially from `offset` to `offset + length`
        return ptr[0..self.length];
    }

    pub fn from_array_list(list: std.ArrayList(u8), allocator: Allocator) !*Region {
        // allocate region
        const region = try allocator.create(Region);

        // build region
        region.offset = @intCast(@intFromPtr(list.items.ptr));
        region.length = @intCast(list.items.len);
        region.capacity = @intCast(list.capacity);

        // return region pointer
        return region;
    }

    /// Frees the memory associated with the region.
    pub fn free(self: *Region, allocator: Allocator) void {
        // create multi-item ptr from offset
        const ptr: [*]u8 = @ptrFromInt(self.offset);

        // create bytes slice
        // essentially from `offset` to `offset + capacity`
        const data = ptr[0..self.capacity];

        // free data within region
        allocator.free(data);
    }

    /// wasm32 memory offset to the struct containing the region's data
    pub fn as_offset(self: *Region) u32 {
        return @intCast(@intFromPtr(self));
    }
};
