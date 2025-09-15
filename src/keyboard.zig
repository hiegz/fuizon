const std = @import("std");

pub const KeyModifier = enum(u16) {
    // zig fmt: off
    shift   = 1 << 0,
    control = 1 << 1,
    alt     = 1 << 2,
    super   = 1 << 3,
    hyper   = 1 << 4,
    meta    = 1 << 5,
    keypad  = 1 << 6,
    caps    = 1 << 7,
    numlock = 1 << 8,
    // zig fmt: on

    pub fn format(self: KeyModifier, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .shift   => _ = try writer.write("shift"),
            .control => _ = try writer.write("control"),
            .alt     => _ = try writer.write("alt"),
            .super   => _ = try writer.write("super"),
            .hyper   => _ = try writer.write("hyper"),
            .meta    => _ = try writer.write("meta"),
            .keypad  => _ = try writer.write("keypad"),
            .caps    => _ = try writer.write("caps"),
            .numlock => _ = try writer.write("numlock"),
        }
        // zig fmt: on
    }

    pub fn bitset(self: KeyModifier) u16 {
        return @intFromEnum(self);
    }
};

pub const KeyModifiers = struct {
    // zig fmt: off
    pub const none = KeyModifiers.join(&.{});
    pub const all  = KeyModifiers.join(&.{
        .shift,
        .control,
        .alt,
        .super,
        .hyper,
        .meta,
        .keypad,
        .caps,
        .numlock,
    });
    // zig fmt: on

    bitset: u16,

    pub fn join(modifiers: []const KeyModifier) KeyModifiers {
        var target = KeyModifiers{ .bitset = 0 };
        target.set(modifiers);
        return target;
    }

    pub fn set(self: *KeyModifiers, modifiers: []const KeyModifier) void {
        for (modifiers) |modifier| {
            self.bitset |= modifier.bitset();
        }
    }

    pub fn reset(self: *KeyModifiers, modifiers: []const KeyModifier) void {
        for (modifiers) |modifier| {
            self.bitset &= ~modifier.bitset();
        }
    }

    pub fn contain(self: KeyModifiers, modifiers: []const KeyModifier) bool {
        for (modifiers) |modifier| {
            if ((self.bitset & modifier.bitset()) == 0)
                return false;
        }
        return true;
    }

    pub fn format(self: KeyModifiers, writer: *std.io.Writer) !void {
        var modifiers = [_]KeyModifier{.shift} ** 9;
        var nmodifiers: usize = 0;

        if (self.contain(&.{.shift})) {
            modifiers[nmodifiers] = .shift;
            nmodifiers += 1;
        }
        if (self.contain(&.{.control})) {
            modifiers[nmodifiers] = .control;
            nmodifiers += 1;
        }
        if (self.contain(&.{.alt})) {
            modifiers[nmodifiers] = .alt;
            nmodifiers += 1;
        }
        if (self.contain(&.{.super})) {
            modifiers[nmodifiers] = .super;
            nmodifiers += 1;
        }
        if (self.contain(&.{.hyper})) {
            modifiers[nmodifiers] = .hyper;
            nmodifiers += 1;
        }
        if (self.contain(&.{.meta})) {
            modifiers[nmodifiers] = .meta;
            nmodifiers += 1;
        }
        if (self.contain(&.{.keypad})) {
            modifiers[nmodifiers] = .keypad;
            nmodifiers += 1;
        }
        if (self.contain(&.{.caps})) {
            modifiers[nmodifiers] = .caps;
            nmodifiers += 1;
        }
        if (self.contain(&.{.numlock})) {
            modifiers[nmodifiers] = .numlock;
            nmodifiers += 1;
        }

        _ = try writer.write("{");
        for (modifiers[0..nmodifiers], 0..) |modifier, i| {
            try writer.print(" {f}", .{modifier});
            if (i + 1 < nmodifiers)
                _ = try writer.write(",");
        }
        _ = try writer.write(" }");
    }
};

pub const KeyCode = union(enum) {
    /// A unicode character.
    char: u21,

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
    backtab,
    delete,
    insert,
    escape,

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
            .backtab     => try writer.print("backtab",     .{}),
            .delete      => try writer.print("delete",      .{}),
            .insert      => try writer.print("insert",      .{}),
            .escape      => try writer.print("escape",      .{}),
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

//
// Tests
//

test "no-key-modifiers" {
    try std.testing.expectEqual(0, KeyModifiers.none.bitset);
}

test "all-key-modifiers" {
    try std.testing.expect(KeyModifiers.all.contain(&.{
        .shift,
        .control,
        .alt,
        .super,
        .hyper,
        .meta,
        .keypad,
        .caps,
        .numlock,
    }));
}

test "key-modifiers-contain" {
    var modifiers = KeyModifiers.all;
    modifiers.reset(&.{ .hyper, .super });

    try std.testing.expect(!modifiers.contain(&.{.hyper}));
    try std.testing.expect(!modifiers.contain(&.{.super}));
    try std.testing.expect(!modifiers.contain(&.{ .hyper, .super }));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .hyper }));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .super }));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .hyper, .super }));
    try std.testing.expect(modifiers.contain(&.{.alt}));
}

test "key-modifiers-set-reset" {
    var left = KeyModifiers.none;
    left.set(&.{ .shift, .control });
    var right = KeyModifiers.all;
    right.reset(&.{ .alt, .super, .hyper, .keypad, .meta, .caps, .numlock });

    try std.testing.expectEqual(left.bitset, right.bitset);
}

test "format-shift-key-modifier" {
    try std.testing.expectFmt("shift", "{f}", .{KeyModifier.shift});
}

test "format-control-key-modifier" {
    try std.testing.expectFmt("control", "{f}", .{KeyModifier.control});
}

test "format-alt-key-modifier" {
    try std.testing.expectFmt("alt", "{f}", .{KeyModifier.alt});
}

test "format-super-key-modifier" {
    try std.testing.expectFmt("super", "{f}", .{KeyModifier.super});
}

test "format-hyper-key-modifier" {
    try std.testing.expectFmt("hyper", "{f}", .{KeyModifier.hyper});
}

test "format-meta-key-modifier" {
    try std.testing.expectFmt("meta", "{f}", .{KeyModifier.meta});
}

test "format-keypad-key-modifier" {
    try std.testing.expectFmt("keypad", "{f}", .{KeyModifier.keypad});
}

test "format-caps-key-modifier" {
    try std.testing.expectFmt("caps", "{f}", .{KeyModifier.caps});
}

test "format-numlock-key-modifier" {
    try std.testing.expectFmt("numlock", "{f}", .{KeyModifier.numlock});
}

test "format-empty-key-modifier-set" {
    try std.testing.expectFmt("{ }", "{f}", .{KeyModifiers.none});
}

test "format-all-key-modifiers" {
    try std.testing.expectFmt("{ shift, control, alt, super, hyper, meta, keypad, caps, numlock }", "{f}", .{KeyModifiers.all});
}

test "format-unicode-key-code" {
    try std.testing.expectFmt("ö", "{f}", .{KeyCode{ .char = 0x00f6 }});
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

test "format-backtab-key-code" {
    try std.testing.expectFmt("backtab", "{f}", .{@as(KeyCode, KeyCode.backtab)});
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
