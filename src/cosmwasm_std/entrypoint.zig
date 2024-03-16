const std = @import("std");
const StructField = std.builtin.Type.StructField;

const Region = @import("memory.zig").Region;
const ContractResult = @import("result.zig").ContractResult;

const Binary = @import("binary.zig").Binary;

const RawResponse = @import("response.zig").RawResponse;
const Response = @import("response.zig").Response;

const types = @import("types.zig");
const Env = types.Env;
const MessageInfo = types.MessageInfo;
const Coin = types.Coin;

const api = @import("api.zig");

fn QueryFn(comptime m: type) type {
    return fn (env: Env, msg: m) Binary;
}
fn QueryWithBufFn(comptime m: type) type {
    return fn (env: Env, msg: m, buf: []u8) Binary;
}
const NakedQueryFn = fn (env_offset: u32, msg_offset: u32) callconv(.C) u32;

fn ActionFn(comptime m: type) type {
    return fn (env: Env, info: MessageInfo, msg: m) *Response;
}
fn ActionWithBufFn(comptime m: type) type {
    return fn (env: Env, info: MessageInfo, msg: m, buf: []u8) *Response;
}
const NakedActionFn = fn (env_offset: u32, info_offset: u32, msg_offset: u32) callconv(.C) u32;

const ally = std.heap.page_allocator;

inline fn as_query_entrypoint(m: type, buf_size: comptime_int, comptime query_fn: QueryWithBufFn(m)) NakedQueryFn {
    return struct {
        fn wrapped(env_offset: u32, msg_offset: u32) callconv(.C) u32 {
            const env = Region
                .from_offset(env_offset)
                .json_deserialize(Env, ally) catch unreachable;

            const msg = Region
                .from_offset(msg_offset)
                .json_deserialize(m, ally) catch unreachable;

            var buf: [buf_size]u8 = undefined;

            const res = query_fn(env, msg, &buf);
            defer res.deinit();

            return (Region.to_json_region(ContractResult([]const u8).ok(res.items), ally) catch unreachable)
                .as_offset();
        }
    }.wrapped;
}

inline fn as_action_entrypoint(m: type, buf_size: comptime_int, comptime write_fn: ActionWithBufFn(m)) NakedActionFn {
    return struct {
        fn wrapped(env_offset: u32, info_offset: u32, msg_offset: u32) callconv(.C) u32 {
            const env = Region
                .from_offset(env_offset)
                .json_deserialize(Env, ally) catch unreachable;

            const info = Region
                .from_offset(info_offset)
                .json_deserialize(MessageInfo, ally) catch unreachable;

            const msg = Region
                .from_offset(msg_offset)
                .json_deserialize(m, ally) catch unreachable;

            var buf: [buf_size]u8 = undefined;
            const res = write_fn(env, info, msg, &buf);
            defer res.deinit();

            const region = Region.to_json_region(ContractResult(RawResponse).ok(res.build()), ally) catch unreachable;
            return region.as_offset();
        }
    }.wrapped;
}

pub inline fn entrypoint(ents: anytype) void {
    const fields = @typeInfo(@TypeOf(ents)).Struct.fields;

    inline for (fields) |field| {
        if (any_of(field.name, .{"query"})) {
            // msg params: (env = [0], msg = [1])
            construct_exports(ents, field, as_query_entrypoint, 1);
        } else if (any_of(field.name, .{ "instantiate", "execute" })) {
            // msg params: (env = [0], info = [1] msg = [2])
            construct_exports(ents, field, as_action_entrypoint, 2);
        } else {
            @compileError("Unknown entrypoint: " ++ field.name);
        }
    }
}

inline fn construct_exports(ents: anytype, field: StructField, wrapper_fn: anytype, msg_param_index: comptime_int) void {
    const ent_conf = @field(ents, field.name);

    const ent_conf_type = @typeInfo(@TypeOf(ent_conf));
    const action_entrypoint = switch (ent_conf_type) {
        // set entrypoint function, no buffer passed in
        .Fn => |fn_info| block: {
            const ent_function_without_buf = ent_conf;
            const msg_type = fn_info.params[msg_param_index].type.?;
            const ent_function = switch (msg_param_index) {
                // msg params: (env = [0], msg = [1])
                1 => struct {
                    fn _(env: Env, msg: msg_type, buf: []u8) Binary {
                        _ = buf;
                        return ent_function_without_buf(env, msg);
                    }
                },
                // msg params: (env = [0], info = [1] msg = [2])
                2 => struct {
                    fn _(env: Env, info: MessageInfo, msg: msg_type, buf: []u8) *Response {
                        _ = buf;
                        return ent_function_without_buf(env, info, msg);
                    }
                },
                else => @compileError("Invalid message parameter index: " ++ msg_param_index.toString()),
            }._;

            break :block wrapper_fn(msg_type, 0, ent_function);
        },
        .Struct => block: {
            const ent_function = @field(ent_conf, "function");
            const buf_size = @field(ent_conf, "with_buf_size");

            const msg_type = @typeInfo(@TypeOf(ent_function)).Fn.params[msg_param_index].type.?;
            break :block wrapper_fn(msg_type, buf_size, ent_function);
        },
        else => @compileError("Invalid entrypoint configuration: " ++ ent_conf_type.name),
    };

    @export(action_entrypoint, .{ .name = field.name, .linkage = .Strong });
}

inline fn any_of(v: []const u8, args: anytype) bool {
    const eql = std.mem.eql;
    inline for (args) |arg| {
        if (eql(u8, v, arg)) {
            return true;
        }
    }
    return false;
}
