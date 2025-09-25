const std = @import("std");
const Key = @import("key.zig").Key;

pub const Input = union(enum) {
    key: Key,
    resize,
    eof,

    pub fn format(self: Input, writer: *std.Io.Writer) !void {
        try switch (self) {
            // zig fmt: off
            .key    => |key| writer.print("Input {{ {f} }}", .{key}),
            .resize =>       writer.print("Input {{ resize }}", .{}),
            .eof    =>       writer.print("Input {{ eof }}", .{}),
            // zig fmt: on
        };
    }
};
