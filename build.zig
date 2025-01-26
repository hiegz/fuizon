const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fuizon = b.addModule("fuizon", .{
        .root_source_file = b.path("src/fuizon.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = fuizon;
}
