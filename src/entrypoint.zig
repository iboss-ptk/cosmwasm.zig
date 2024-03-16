const std = @import("std");
const Allocator = std.mem.Allocator;
const ally = std.heap.page_allocator;

const serde = @import("cosmwasm_std/serde.zig");

const memory = @import("cosmwasm_std/memory.zig");
const Region = memory.Region;

const response = @import("cosmwasm_std/response.zig");
const Response = response.Response;
const Attribute = response.Attribute;

const result = @import("cosmwasm_std/result.zig");
const ContractResult = result.ContractResult;

const api = @import("cosmwasm_std/api.zig");
const store = @import("cosmwasm_std/store.zig");

const types = @import("cosmwasm_std/types.zig");
const Env = types.Env;
const MessageInfo = types.MessageInfo;

const entrypoint = @import("cosmwasm_std/entrypoint.zig").entrypoint;
const max_digits = @import("utils.zig").max_digits;

/// Mark all exports from `cosmwasm_std/exports.zig` as exports from this module
const exports = @import("cosmwasm_std/exports.zig");
export const _ = exports.all;

// --- msgs ---

const InstantiateMsg = struct {
    count: []const u8, // parse as u128
};

const ExecuteMsg = union(enum) {
    increase: struct { amount: []const u8 }, // parse as u128
    decrease: struct { amount: []const u8 }, // parse as u128
};

const QueryMsg = union(enum) {
    count: struct {},
};

const CountResponse = struct {
    count: []const u8, // u128 as string
};

// --- entrypoints ---

comptime {
    entrypoint(.{ .instantiate = instantiate });
}
fn instantiate(env: Env, info: MessageInfo, msg: InstantiateMsg) *Response {
    _ = env;
    _ = info;

    var res = Response.init(ally);

    // write count to store
    store.write("count", msg.count, ally);

    // construct response
    return res
        .add_attribute("action", "instantiate")
        .add_attribute("count", msg.count);
}

comptime {
    entrypoint(.{
        .execute = .{ .function = execute, .with_buf_size = max_digits(u128) },
    });
}
fn execute(env: Env, info: MessageInfo, msg: ExecuteMsg, buf: []u8) *Response {
    _ = env;
    _ = info;

    const count_reader = store.read("count", ally).?;
    defer count_reader.deinit();
    const count = std.fmt.parseInt(u128, count_reader.read(), 10) catch unreachable;

    var res = Response.init(ally);

    return switch (msg) {
        .increase => |payload| block: {
            const amount = std.fmt.parseInt(u128, payload.amount, 10) catch unreachable;

            const new_count = std.fmt.bufPrint(buf, "{d}", .{count + amount}) catch unreachable;
            store.write("count", new_count, ally);

            break :block res
                .add_attribute("action", "increase")
                .add_attribute("count", new_count);
        },
        .decrease => |payload| block: {
            const amount = std.fmt.parseInt(u128, payload.amount, 10) catch unreachable;

            const new_count = std.fmt.bufPrint(buf, "{d}", .{count - amount}) catch unreachable;
            store.write("count", new_count, ally);

            break :block res
                .add_attribute("action", "decrease")
                .add_attribute("count", new_count);
        },
    };
}

comptime {
    entrypoint(.{ .query = query });
}
fn query(env: Env, msg: QueryMsg) []const u8 {
    _ = env;
    return switch (msg) {
        .count => block: {
            const count_reader = store.read("count", ally).?;
            defer count_reader.deinit();
            const count = count_reader.read(); // u128 as string

            const res = CountResponse{ .count = count };
            const data = serde.to_base64_json(res, ally) catch unreachable;

            break :block data;
        },
    };
}

// TODO:
// - ResponseBuilder -> Response, Response -> RawResponse
// - error handling
// - make cw_std a module
