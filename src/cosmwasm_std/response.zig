const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Response = struct {
    messages: [][]const u8, // TODO: define Message type
    attributes: []Attribute,
    events: [][]const u8, // TODO: define Event type
    data: ?[]const u8,

    pub fn new(conf: struct {
        messages: [][]const u8 = &[_][]const u8{},
        attributes: []Attribute = &[_]Attribute{},
        events: [][]const u8 = &[_][]const u8{},
        data: ?[]const u8 = null,
    }) Response {
        return Response{
            .messages = conf.messages,
            .attributes = conf.attributes,
            .events = conf.events,
            .data = conf.data,
        };
    }
};

pub const ResponseBuilder = struct {
    atrributes: std.ArrayList(Attribute),

    pub fn init(allocator: Allocator) ResponseBuilder {
        return ResponseBuilder{ .atrributes = std.ArrayList(Attribute).init(allocator) };
    }

    pub fn deinit(self: ResponseBuilder) void {
        self.atrributes.deinit();
    }

    pub fn add_attribute(self: *ResponseBuilder, key: []const u8, value: []const u8) *ResponseBuilder {
        self.atrributes.append(Attribute{ .key = key, .value = value }) catch unreachable;
        return self;
    }

    pub fn build(self: ResponseBuilder) Response {
        const attributes = self.atrributes.items;
        return Response{
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
