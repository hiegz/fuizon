const std = @import("std");
const Key = @import("key.zig").Key;

pub const Input = union(enum) {
    key: Key,

    pub fn format(self: Input, writer: *std.Io.Writer) !void {
        try writer.print("Input {{ {f} }}", .{self.key});
    }
};
