const std = @import("std");

pub const KeyModifier = enum(u3) {
    // zig fmt: off
    shift   = 1 << 0,
    control = 1 << 1,
    alt     = 1 << 2,
    // zig fmt: on

    pub fn format(self: KeyModifier, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .shift   => _ = try writer.write("shift"),
            .control => _ = try writer.write("control"),
            .alt     => _ = try writer.write("alt"),
        }
        // zig fmt: on
    }

    pub fn bitset(self: KeyModifier) u16 {
        return @intFromEnum(self);
    }
};

test "format-shift-key-modifier" {
    try std.testing.expectFmt("shift", "{f}", .{KeyModifier.shift});
}

test "format-control-key-modifier" {
    try std.testing.expectFmt("control", "{f}", .{KeyModifier.control});
}

test "format-alt-key-modifier" {
    try std.testing.expectFmt("alt", "{f}", .{KeyModifier.alt});
}
