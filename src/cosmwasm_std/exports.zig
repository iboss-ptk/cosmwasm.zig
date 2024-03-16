const std = @import("std");
const Region = @import("memory.zig").Region;

pub const ally = std.heap.page_allocator;

pub export fn interface_version_8() void {}

pub export fn allocate(size: usize) *const Region {
    return Region.create(size, ally) catch unreachable;
}

pub export fn deallocate(region_ptr: u32) void {
    // get region pointer
    const region: *Region = @ptrFromInt(region_ptr);
    defer ally.destroy(region);

    // free memory
    region.free(ally);
}

/// Phantom function to mark the call-site
/// to export all functions from this file
///
/// ```zig
/// export const _ = @import("cosmwasm_std/exports.zig").all;
/// ```
pub fn all() callconv(.C) void {}
