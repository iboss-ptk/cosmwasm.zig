const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Response = struct {
    atrributes: std.ArrayList(Attribute),

    pub fn init(allocator: Allocator) Response {
        return Response{ .atrributes = std.ArrayList(Attribute).init(allocator) };
    }

    pub fn deinit(self: Response) void {
        self.atrributes.deinit();
    }

    pub fn add_attribute(self: *Response, key: []const u8, value: []const u8) *Response {
        self.atrributes.append(Attribute{ .key = key, .value = value }) catch unreachable;
        return self;
    }

    pub fn build(self: Response) RawResponse {
        const attributes = self.atrributes.items;
        return RawResponse{
            .messages = &[_][]const u8{},
            .attributes = attributes,
            .events = &[_][]const u8{},
            .data = null,
        };
    }
};

// TODO: response builder

pub const Attribute = struct {
    key: []const u8,
    value: []const u8,
};

pub const RawResponse = struct {
    messages: [][]const u8, // TODO: define Message type
    attributes: []Attribute,
    events: [][]const u8, // TODO: define Event type
    data: ?[]const u8,
};
