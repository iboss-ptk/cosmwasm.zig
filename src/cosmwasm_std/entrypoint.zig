const std = @import("std");
const Region = @import("memory.zig").Region;
const ContractResult = @import("result.zig").ContractResult;

const Response = @import("response.zig").Response;
const ResponseBuilder = @import("response.zig").ResponseBuilder;

const types = @import("types.zig");
const Env = types.Env;
const MessageInfo = types.MessageInfo;
const Coin = types.Coin;

const api = @import("api.zig");

fn QueryFn(comptime m: type) type {
    return fn (env: Env, msg: m) []const u8;
}
fn QueryWithBufFn(comptime m: type) type {
    return fn (env: Env, msg: m, buf: []u8) []const u8;
}
const NakedQueryFn = fn (env_offset: u32, msg_offset: u32) callconv(.C) u32;

fn ActionFn(comptime m: type) type {
    return fn (env: Env, info: MessageInfo, msg: m) ResponseBuilder;
}
fn ActionWithBufFn(comptime m: type) type {
    return fn (env: Env, info: MessageInfo, msg: m, buf: []u8) ResponseBuilder;
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
            return (Region.to_json_region(ContractResult([]const u8).ok(query_fn(env, msg, &buf)), ally) catch unreachable)
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

            const region = Region.to_json_region(ContractResult(Response).ok(res.build()), ally) catch unreachable;
            return region.as_offset();
        }
    }.wrapped;
}

pub inline fn entrypoint(ents: anytype) void {
    const fields = @typeInfo(@TypeOf(ents)).Struct.fields;

    inline for (fields) |field| {
        if (any_of(field.name, .{"query"})) {
            const ent_conf = @field(ents, field.name);
            const ent_conf_type = @typeInfo(@TypeOf(ent_conf));
            const query_entrypoint = switch (ent_conf_type) {
                // set entrypoint function, no buffer passed in
                .Fn => |fn_info| block: {
                    const ent_function_without_buf = ent_conf;

                    // (env = [0], msg = [1])
                    const query_msg_type = fn_info.params[1].type.?;

                    const ent_function = struct {
                        fn _(env: Env, msg: query_msg_type, buf: []u8) []const u8 {
                            _ = buf;
                            return ent_function_without_buf(env, msg);
                        }
                    }._;

                    break :block as_query_entrypoint(query_msg_type, 0, ent_function);
                },
                .Struct => block: {
                    const ent_function = @field(ent_conf, "function");
                    const buf_size = @field(ent_conf, "with_buf_size");

                    // (env = [0], msg = [1])
                    const query_msg_type = @typeInfo(@TypeOf(ent_function)).Fn.params[1].type.?;

                    break :block as_query_entrypoint(query_msg_type, buf_size, ent_function);
                },
                else => @compileError("Invalid entrypoint configuration: " ++ ent_conf_type.name),
            };

            @export(query_entrypoint, .{ .name = field.name, .linkage = .Strong });
        } else if (any_of(field.name, .{ "instantiate", "execute" })) {
            const ent_conf = @field(ents, field.name);
            const ent_conf_type = @typeInfo(@TypeOf(ent_conf));
            const action_entrypoint = switch (ent_conf_type) {
                // set entrypoint function, no buffer passed in
                .Fn => |fn_info| block: {
                    const ent_function_without_buf = ent_conf;

                    // (env = [0], info = [1], msg = [2])
                    const action_msg_type = fn_info.params[2].type.?;

                    const ent_function = struct {
                        fn _(env: Env, info: MessageInfo, msg: action_msg_type, buf: []u8) ResponseBuilder {
                            _ = buf;
                            return ent_function_without_buf(env, info, msg);
                        }
                    }._;

                    break :block as_action_entrypoint(action_msg_type, 0, ent_function);
                },
                .Struct => block: {
                    const ent_function = @field(ent_conf, "function");
                    const buf_size = @field(ent_conf, "with_buf_size");

                    // (env = [0], info = [1], msg = [2])
                    const action_msg_type = @typeInfo(@TypeOf(ent_function)).Fn.params[2].type.?;

                    break :block as_action_entrypoint(action_msg_type, buf_size, ent_function);
                },
                else => @compileError("Invalid entrypoint configuration: " ++ ent_conf_type.name),
            };

            @export(action_entrypoint, .{ .name = field.name, .linkage = .Strong });
        } else {
            @compileError("Unknown entrypoint: " ++ field.name);
        }
    }
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
