const std = @import("std");

const number_of_pages = 2;

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const exe = b.addExecutable(.{
        .name = "entrypoint",
        .root_source_file = .{ .path = "src/entrypoint.zig" },
        .target = target,
        .optimize = .ReleaseSmall,
    });

    // <https://github.com/ziglang/zig/issues/8633>
    exe.global_base = 6560;
    exe.entry = .disabled;
    exe.rdynamic = true;
    exe.export_memory = true;
    exe.stack_size = std.wasm.page_size;
    exe.initial_memory = std.wasm.page_size * number_of_pages;

    b.installArtifact(exe);

    // --- vmtest ---
    const step = b.step("vm-setup", "run integration test with wasmvm");
    step.makeFn = setup_vm_test;
    step.dependOn(&exe.step);
}

fn setup_vm_test(self: *std.Build.Step, progress: *std.Progress.Node) !void {
    const src_file_name = "build.zig";
    const src = @src();
    const src_dir = src.file[0 .. src.file.len - src_file_name.len - 1];

    const wasm_path = src_dir ++ "/zig-out/bin/entrypoint.wasm";
    const dest_path = src_dir ++ "/../cosmwasm/packages/vm/testdata/entrypoint.wasm";

    try std.fs.copyFileAbsolute(wasm_path, dest_path, .{});

    _ = progress;
    _ = self;
}
