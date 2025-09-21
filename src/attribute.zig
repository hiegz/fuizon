const std = @import("std");

pub const Attribute = enum(u8) {
    // zig fmt: off
    bold      = 1 << 0,
    dim       = 1 << 1,
    underline = 1 << 2,
    reverse   = 1 << 3,
    hidden    = 1 << 4,
    // zig fmt: on

    pub fn format(self: Attribute, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .bold      => _ = try writer.write("bold"),
            .dim       => _ = try writer.write("dim"),
            .underline => _ = try writer.write("underline"),
            .reverse   => _ = try writer.write("reverse"),
            .hidden    => _ = try writer.write("hidden"),
        }
        // zig fmt: on
    }

    pub fn bitset(attribute: Attribute) u8 {
        return @intFromEnum(attribute);
    }
};

test "format-bold-attribute" {
    try std.testing.expectFmt("bold", "{f}", .{Attribute.bold});
}

test "format-dim-attribute" {
    try std.testing.expectFmt("dim", "{f}", .{Attribute.dim});
}

test "format-underline-attribute" {
    try std.testing.expectFmt("underline", "{f}", .{Attribute.underline});
}

test "format-reverse-attribute" {
    try std.testing.expectFmt("reverse", "{f}", .{Attribute.reverse});
}

test "format-hidden-attribute" {
    try std.testing.expectFmt("hidden", "{f}", .{Attribute.hidden});
}
