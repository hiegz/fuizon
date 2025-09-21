const std = @import("std");

pub const KeyCode = union(enum) {
    /// A unicode character.
    char: u21,

    space,
    backspace,
    enter,
    left_arrow,
    right_arrow,
    up_arrow,
    down_arrow,
    home,
    end,
    page_up,
    page_down,
    tab,
    delete,
    insert,
    escape,
    pause,

    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,

    pub fn format(self: KeyCode, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .char        => try writer.print("{u}",         .{self.char}),
            .space       => try writer.print("space",       .{}),
            .backspace   => try writer.print("backspace",   .{}),
            .enter       => try writer.print("enter",       .{}),
            .left_arrow  => try writer.print("left arrow",  .{}),
            .right_arrow => try writer.print("right arrow", .{}),
            .up_arrow    => try writer.print("up arrow",    .{}),
            .down_arrow  => try writer.print("down arrow",  .{}),
            .home        => try writer.print("home",        .{}),
            .end         => try writer.print("end",         .{}),
            .page_up     => try writer.print("page up",     .{}),
            .page_down   => try writer.print("page down",   .{}),
            .tab         => try writer.print("tab",         .{}),
            .delete      => try writer.print("delete",      .{}),
            .insert      => try writer.print("insert",      .{}),
            .escape      => try writer.print("escape",      .{}),
            .pause       => try writer.print("pause",       .{}),
            .f1          => try writer.print("f1",          .{}),
            .f2          => try writer.print("f2",          .{}),
            .f3          => try writer.print("f3",          .{}),
            .f4          => try writer.print("f4",          .{}),
            .f5          => try writer.print("f5",          .{}),
            .f6          => try writer.print("f6",          .{}),
            .f7          => try writer.print("f7",          .{}),
            .f8          => try writer.print("f8",          .{}),
            .f9          => try writer.print("f9",          .{}),
            .f10         => try writer.print("f10",         .{}),
            .f11         => try writer.print("f11",         .{}),
            .f12         => try writer.print("f12",         .{}),

        }
        // zig fmt: on
    }
};

test "format-unicode-key-code" {
    try std.testing.expectFmt("ö", "{f}", .{KeyCode{ .char = 0x00f6 }});
}

test "format-space-key-code" {
    try std.testing.expectFmt("space", "{f}", .{@as(KeyCode, KeyCode.space)});
}

test "format-backspace-key-code" {
    try std.testing.expectFmt("backspace", "{f}", .{@as(KeyCode, KeyCode.backspace)});
}

test "format-enter-key-code" {
    try std.testing.expectFmt("enter", "{f}", .{@as(KeyCode, KeyCode.enter)});
}

test "format-left-arrow-key-code" {
    try std.testing.expectFmt("left arrow", "{f}", .{@as(KeyCode, KeyCode.left_arrow)});
}

test "format-right-arrow-key-code" {
    try std.testing.expectFmt("right arrow", "{f}", .{@as(KeyCode, KeyCode.right_arrow)});
}

test "format-up-arrow-key-code" {
    try std.testing.expectFmt("up arrow", "{f}", .{@as(KeyCode, KeyCode.up_arrow)});
}

test "format-down-arrow-key-code" {
    try std.testing.expectFmt("down arrow", "{f}", .{@as(KeyCode, KeyCode.down_arrow)});
}

test "format-home-key-code" {
    try std.testing.expectFmt("home", "{f}", .{@as(KeyCode, KeyCode.home)});
}

test "format-end-key-code" {
    try std.testing.expectFmt("end", "{f}", .{@as(KeyCode, KeyCode.end)});
}

test "format-page-up-key-code" {
    try std.testing.expectFmt("page up", "{f}", .{@as(KeyCode, KeyCode.page_up)});
}

test "format-page-down-key-code" {
    try std.testing.expectFmt("page down", "{f}", .{@as(KeyCode, KeyCode.page_down)});
}

test "format-tab-key-code" {
    try std.testing.expectFmt("tab", "{f}", .{@as(KeyCode, KeyCode.tab)});
}

test "format-delete-key-code" {
    try std.testing.expectFmt("delete", "{f}", .{@as(KeyCode, KeyCode.delete)});
}

test "format-insert-key-code" {
    try std.testing.expectFmt("insert", "{f}", .{@as(KeyCode, KeyCode.insert)});
}

test "format-escape-key-code" {
    try std.testing.expectFmt("escape", "{f}", .{@as(KeyCode, KeyCode.escape)});
}

test "format-pause-key-code" {
    try std.testing.expectFmt("pause", "{f}", .{@as(KeyCode, KeyCode.pause)});
}

test "format-f1-key-code" {
    try std.testing.expectFmt("f1", "{f}", .{@as(KeyCode, KeyCode.f1)});
}

test "format-f2-key-code" {
    try std.testing.expectFmt("f2", "{f}", .{@as(KeyCode, KeyCode.f2)});
}

test "format-f3-key-code" {
    try std.testing.expectFmt("f3", "{f}", .{@as(KeyCode, KeyCode.f3)});
}

test "format-f4-key-code" {
    try std.testing.expectFmt("f4", "{f}", .{@as(KeyCode, KeyCode.f4)});
}

test "format-f5-key-code" {
    try std.testing.expectFmt("f5", "{f}", .{@as(KeyCode, KeyCode.f5)});
}

test "format-f6-key-code" {
    try std.testing.expectFmt("f6", "{f}", .{@as(KeyCode, KeyCode.f6)});
}

test "format-f7-key-code" {
    try std.testing.expectFmt("f7", "{f}", .{@as(KeyCode, KeyCode.f7)});
}

test "format-f8-key-code" {
    try std.testing.expectFmt("f8", "{f}", .{@as(KeyCode, KeyCode.f8)});
}

test "format-f9-key-code" {
    try std.testing.expectFmt("f9", "{f}", .{@as(KeyCode, KeyCode.f9)});
}

test "format-f10-key-code" {
    try std.testing.expectFmt("f10", "{f}", .{@as(KeyCode, KeyCode.f10)});
}

test "format-f11-key-code" {
    try std.testing.expectFmt("f11", "{f}", .{@as(KeyCode, KeyCode.f11)});
}

test "format-f12-key-code" {
    try std.testing.expectFmt("f12", "{f}", .{@as(KeyCode, KeyCode.f12)});
}
