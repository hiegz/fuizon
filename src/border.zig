const std = @import("std");

// zig fmt: off

pub const Border = enum(u8) {
    top    = 1 << 0,
    bottom = 1 << 1,
    left   = 1 << 2,
    right  = 1 << 3,

    pub fn format(self: Border, writer: *std.Io.Writer) !void {
        switch (self) {
            .top    => _ = try writer.write("top"),
            .bottom => _ = try writer.write("bottom"),
            .left   => _ = try writer.write("left"),
            .right  => _ = try writer.write("right"),
        }
    }

    pub fn bitset(self: Border) u8 {
        return @intFromEnum(self);
    }
};

// zig fmt: on

test "Border.format() the top border" {
    try std.testing.expectFmt("top", "{f}", .{Border.top});
}

test "Border.format() the bottom border" {
    try std.testing.expectFmt("bottom", "{f}", .{Border.bottom});
}

test "Border.format() the left border" {
    try std.testing.expectFmt("left", "{f}", .{Border.left});
}

test "Border.format() the right border" {
    try std.testing.expectFmt("right", "{f}", .{Border.right});
}
