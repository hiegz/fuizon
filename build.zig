const std = @import("std");

pub fn build(b: *std.Build) void {
    // var targets = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const check_step = b.step("check", "Check if projects builds");

    const fuizon_module = b.addModule("fuizon", .{
        .root_source_file = b.path("src/fuizon.zig"),
        .target = target,
        .optimize = optimize,

        .link_libc = true,
        .link_libcpp = true,
        .valgrind = true,
    });

    // Tests
    {
        const test_step = b.step("test", "Run all tests");
        const fuizon_tests = b.addTest(.{ .name = "fuizon", .root_module = fuizon_module });

        test_step.dependOn(&b.addRunArtifact(fuizon_tests).step);
        check_step.dependOn(&fuizon_tests.step);
    }

    // Examples
    {
        const examples = &[_]struct {
            name: []const u8,
            desc: []const u8,
            path: []const u8,
        }{
            // zig fmt: off
            .{ .name = "backend-demo", .desc = "Run the backend demo",    .path = "examples/backend.zig" },
            .{ .name = "color-demo",   .desc = "Run the base color demo", .path = "examples/colors.zig" },
            .{ .name = "ansi-demo",    .desc = "Run the ANSI color demo", .path = "examples/ansi.zig" },
            .{ .name = "rgb-demo",     .desc = "Run the RGB color demo",  .path = "examples/rgb.zig" },
            .{ .name = "logo-demo",    .desc = "Run the logo demo",       .path = "examples/logo.zig" },
            // zig fmt: on
        };

        inline for (examples) |example| {
            const mod = b.addModule(example.name, .{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            });
            mod.addImport("fuizon", fuizon_module);

            const exe = b.addExecutable(.{
                .name = example.name,
                .root_module = mod,
            });
            const run_exe = b.addRunArtifact(exe);
            const run_step = b.step("run-" ++ example.name, example.desc);
            run_step.dependOn(&run_exe.step);

            check_step.dependOn(&exe.step);
        }
    }

    // Still on zig 0.13.0
    //
    // Generate compile commands database
    // @import("compile-commands").createStep(b, "cdb", targets.toOwnedSlice() catch @panic("OOM"));
}
