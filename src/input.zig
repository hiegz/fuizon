const std = @import("std");
const fuizon = @import("fuizon.zig");
const Key = fuizon.Key;

pub const Input = union(enum) {
    key: Key,

    pub fn format(self: Input, writer: *std.Io.Writer) !void {
        try writer.print("Input {{ {f} }}", .{self.key});
    }
};
