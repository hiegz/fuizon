const std = @import("std");

// zig fmt: off
var b:         *std.Build                = undefined;
var target:     std.Build.ResolvedTarget = undefined;
var optimize:   std.builtin.OptimizeMode = undefined;
var fuizon:    *std.Build.Module         = undefined;
var crossterm:  std.Build.LazyPath       = undefined;
var test_step: *std.Build.Step           = undefined;
// zig fmt: on

fn addTest(
    comptime name: []const u8,
    path: std.Build.LazyPath,
) void {
    // zig fmt: off
    var t:        *std.Build.Step.Compile = undefined;
    var artifact: *std.Build.Step.Run     = undefined;
    // zig fmt: on

    t = b.addTest(.{
        .name = name,
        .root_source_file = path,
        .target = target,
        .optimize = optimize,
    });
    t.linkLibC();
    t.linkLibCpp();
    t.addLibraryPath(crossterm);
    t.addIncludePath(b.path("include"));
    t.linkSystemLibrary("crossterm_ffi");

    artifact = b.addRunArtifact(t);
    test_step.dependOn(&artifact.step);
}

fn addExample(
    comptime name: []const u8,
    comptime description: []const u8,
    path: std.Build.LazyPath,
) void {
    // zig fmt: off
    var example:  *std.Build.Step.Compile = undefined;
    var artifact: *std.Build.Step.Run     = undefined;
    var step:     *std.Build.Step         = undefined;
    // zig fmt: on

    example = b.addExecutable(.{
        .name = name,
        .root_source_file = path,
        .target = target,
        .optimize = optimize,
    });
    example.root_module.addImport("fuizon", fuizon);

    artifact = b.addRunArtifact(example);
    step = b.step("run" ++ "-" ++ name, description);
    step.dependOn(&artifact.step);
}

pub fn build(b_: *std.Build) void {
    b = b_;

    target = b_.standardTargetOptions(.{});
    optimize = b.standardOptimizeOption(.{});

    const build_crossterm = b.addSystemCommand(&.{ "cargo", "build", "--release" });
    build_crossterm.setCwd(b.path("crossterm-ffi"));
    build_crossterm.addArgs(&.{"--target-dir"});
    crossterm = build_crossterm.addOutputDirectoryArg("build/target").path(b, "release");

    const test_crossterm = b.addSystemCommand(&.{ "cargo", "test" });
    test_crossterm.setCwd(b.path("crossterm-ffi"));

    fuizon = b.addModule("fuizon", .{
        .root_source_file = b.path("src/fuizon.zig"),
        .target = target,
        .optimize = optimize,

        .link_libc = true,
        .link_libcpp = true,
        .valgrind = true,
    });
    fuizon.addLibraryPath(crossterm);
    fuizon.addIncludePath(b.path("include"));
    fuizon.linkSystemLibrary("crossterm_ffi", .{ .needed = true });

    test_step = b.step("test", "Run all tests");
    test_step.dependOn(&test_crossterm.step);

    addTest("event", b.path("src/event.zig"));
    addTest("style", b.path("src/style.zig"));

    addExample("crossterm", "Run the crossterm demo", b.path("examples/crossterm.zig"));
    addExample("4-bit-color-demo", "Run the 4-bit color code demo", b.path("examples/base_colors.zig"));
    addExample("8-bit-color-demo", "Run the 8-bit color code demo", b.path("examples/ansi_colors.zig"));
    addExample("24-bit-color-demo", "Run the 24-bit color code demo", b.path("examples/rgb_colors.zig"));
}
