const Response = @import("response.zig").Response;

pub fn ContractResult(comptime t: type) type {
    return union(enum) {
        ok: t,
        err: []const u8,

        pub fn ok(v: t) ContractResult(t) {
            return ContractResult(t){ .ok = v };
        }

        pub fn err(message: []const u8) ContractResult(t) {
            return ContractResult(t){ .err = message };
        }
    };
}
