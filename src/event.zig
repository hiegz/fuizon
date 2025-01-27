const std = @import("std");
const c = @import("headers.zig").c;

pub const KeyModifiers = struct {
    // zig fmt: off
    pub const none    = KeyModifiers{ .bitset = 0 };
    pub const shift   = KeyModifiers{ .bitset = 1 << 0 };
    pub const control = KeyModifiers{ .bitset = 1 << 1 };
    pub const alt     = KeyModifiers{ .bitset = 1 << 2 };
    pub const super   = KeyModifiers{ .bitset = 1 << 3 };
    pub const hyper   = KeyModifiers{ .bitset = 1 << 4 };
    pub const meta    = KeyModifiers{ .bitset = 1 << 5 };
    pub const keypad  = KeyModifiers{ .bitset = 1 << 6 };
    pub const caps    = KeyModifiers{ .bitset = 1 << 7 };
    pub const numlock = KeyModifiers{ .bitset = 1 << 8 };
    pub const all     = KeyModifiers{ .bitset = 0x1ff };
    // zig fmt: on

    bitset: u16,

    pub fn format(
        self: KeyModifiers,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        var modifiers = [_][]const u8{""} ** 9;
        var nmodifiers: usize = 0;

        if ((self.bitset & KeyModifiers.shift.bitset) != 0) {
            modifiers[nmodifiers] = "shift";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.control.bitset) != 0) {
            modifiers[nmodifiers] = "control";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.alt.bitset) != 0) {
            modifiers[nmodifiers] = "alt";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.super.bitset) != 0) {
            modifiers[nmodifiers] = "super";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.hyper.bitset) != 0) {
            modifiers[nmodifiers] = "hyper";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.meta.bitset) != 0) {
            modifiers[nmodifiers] = "meta";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.keypad.bitset) != 0) {
            modifiers[nmodifiers] = "keypad";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.caps.bitset) != 0) {
            modifiers[nmodifiers] = "caps";
            nmodifiers += 1;
        }
        if ((self.bitset & KeyModifiers.numlock.bitset) != 0) {
            modifiers[nmodifiers] = "numlock";
            nmodifiers += 1;
        }

        try writer.print("[", .{});
        for (0..nmodifiers -| 1) |i|
            try writer.print("{s}+", .{modifiers[i]});
        try writer.print("{s}", .{modifiers[nmodifiers -| 1]});
        try writer.print("]", .{});
    }

    pub fn fromCrosstermKeyModifiers(modifiers: c.crossterm_key_modifiers) KeyModifiers {
        var target = KeyModifiers{ .bitset = 0 };

        // zig fmt: off
        if ((modifiers & c.CROSSTERM_SHIFT_KEY_MODIFIER)     != 0) target.bitset |= KeyModifiers.shift.bitset;
        if ((modifiers & c.CROSSTERM_CONTROL_KEY_MODIFIER)   != 0) target.bitset |= KeyModifiers.control.bitset;
        if ((modifiers & c.CROSSTERM_ALT_KEY_MODIFIER)       != 0) target.bitset |= KeyModifiers.alt.bitset;
        if ((modifiers & c.CROSSTERM_SUPER_KEY_MODIFIER)     != 0) target.bitset |= KeyModifiers.super.bitset;
        if ((modifiers & c.CROSSTERM_HYPER_KEY_MODIFIER)     != 0) target.bitset |= KeyModifiers.hyper.bitset;
        if ((modifiers & c.CROSSTERM_META_KEY_MODIFIER)      != 0) target.bitset |= KeyModifiers.meta.bitset;
        if ((modifiers & c.CROSSTERM_KEYPAD_KEY_MODIFIER)    != 0) target.bitset |= KeyModifiers.keypad.bitset;
        if ((modifiers & c.CROSSTERM_CAPS_LOCK_KEY_MODIFIER) != 0) target.bitset |= KeyModifiers.caps.bitset;
        if ((modifiers & c.CROSSTERM_NUM_LOCK_KEY_MODIFIER)  != 0) target.bitset |= KeyModifiers.numlock.bitset;
        // zig fmt: on

        return target;
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

    pub fn format(
        self: KeyCode,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

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

    pub fn fromCrosstermKeyCode(
        keytype: c.crossterm_key_type,
        keycode: c.crossterm_uint21_t,
    ) ?KeyCode {
        // zig fmt: off
        switch (keytype) {
            c.CROSSTERM_CHAR_KEY => 
                return if (keycode <= std.math.maxInt(u21)) 
                           .{ .char = @intCast(keycode) } 
                       else 
                           null,
            c.CROSSTERM_BACKSPACE_KEY   => return .backspace,
            c.CROSSTERM_ENTER_KEY       => return .enter,
            c.CROSSTERM_LEFT_ARROW_KEY  => return .left_arrow,
            c.CROSSTERM_RIGHT_ARROW_KEY => return .right_arrow,
            c.CROSSTERM_UP_ARROW_KEY    => return .up_arrow,
            c.CROSSTERM_DOWN_ARROW_KEY  => return .down_arrow,
            c.CROSSTERM_HOME_KEY        => return .home,
            c.CROSSTERM_END_KEY         => return .end,
            c.CROSSTERM_PAGE_UP_KEY     => return .page_up,
            c.CROSSTERM_PAGE_DOWN_KEY   => return .page_down,
            c.CROSSTERM_TAB_KEY         => return .tab,
            c.CROSSTERM_BACKTAB_KEY     => return .backtab,
            c.CROSSTERM_DELETE_KEY      => return .delete,
            c.CROSSTERM_INSERT_KEY      => return .insert,
            c.CROSSTERM_ESCAPE_KEY      => return .escape,
            c.CROSSTERM_F1_KEY          => return .f1,
            c.CROSSTERM_F2_KEY          => return .f2,
            c.CROSSTERM_F3_KEY          => return .f3,
            c.CROSSTERM_F4_KEY          => return .f4,
            c.CROSSTERM_F5_KEY          => return .f5,
            c.CROSSTERM_F6_KEY          => return .f6,
            c.CROSSTERM_F7_KEY          => return .f7,
            c.CROSSTERM_F8_KEY          => return .f8,
            c.CROSSTERM_F9_KEY          => return .f9,
            c.CROSSTERM_F10_KEY         => return .f10,
            c.CROSSTERM_F11_KEY         => return .f11,
            c.CROSSTERM_F12_KEY         => return .f12,
            else                        => return null,
        }
        // zig fmt: on
    }
};

pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers,

    pub fn fromCrosstermKeyEvent(event: c.crossterm_key_event) ?KeyEvent {
        return .{
            .code = KeyCode.fromCrosstermKeyCode(event.type, event.code) orelse return null,
            .modifiers = KeyModifiers.fromCrosstermKeyModifiers(event.modifiers),
        };
    }
};

pub const ResizeEvent = struct {
    width: u16,
    height: u16,

    pub fn fromCrosstermResizeEvent(event: c.crossterm_resize_event) ResizeEvent {
        return .{
            .width = event.width,
            .height = event.height,
        };
    }
};

pub const Event = union(enum) {
    key: KeyEvent,
    resize: ResizeEvent,

    pub fn fromCrosstermEvent(event: c.crossterm_event) ?Event {
        switch (event.type) {
            c.CROSSTERM_KEY_EVENT => return .{ .key = KeyEvent.fromCrosstermKeyEvent(event.unnamed_0.key) orelse return null },
            c.CROSSTERM_RESIZE_EVENT => return .{ .resize = ResizeEvent.fromCrosstermResizeEvent(event.unnamed_0.resize) },
            else => return null,
        }
    }
};

//
// Tests
//

test "no-key-modifiers" {
    try std.testing.expectEqual(
        0,
        // zig fmt: off
        (KeyModifiers.shift.bitset     |
         KeyModifiers.control.bitset   |
         KeyModifiers.alt.bitset       |
         KeyModifiers.super.bitset     |
         KeyModifiers.hyper.bitset     |
         KeyModifiers.meta.bitset      |
         KeyModifiers.keypad.bitset    |
         KeyModifiers.caps.bitset      |
         KeyModifiers.numlock.bitset)  & KeyModifiers.none.bitset
        // zig fmt: on
        ,
    );
}

test "all-key-modifiers" {
    try std.testing.expectEqual(
        // zig fmt: off
        KeyModifiers.shift.bitset      |
        KeyModifiers.control.bitset    |
        KeyModifiers.alt.bitset        |
        KeyModifiers.super.bitset      |
        KeyModifiers.hyper.bitset      |
        KeyModifiers.meta.bitset       |
        KeyModifiers.keypad.bitset     |
        KeyModifiers.caps.bitset       |
        KeyModifiers.numlock.bitset
        // zig fmt: on
        ,
        KeyModifiers.all.bitset,
    );
}

test "format-none-key-modifier" {
    try std.testing.expectFmt("[]", "{}", .{KeyModifiers.none});
}

test "format-shift-key-modifier" {
    try std.testing.expectFmt("[shift]", "{}", .{KeyModifiers.shift});
}

test "format-control-key-modifier" {
    try std.testing.expectFmt("[control]", "{}", .{KeyModifiers.control});
}

test "format-alt-key-modifier" {
    try std.testing.expectFmt("[alt]", "{}", .{KeyModifiers.alt});
}

test "format-super-key-modifier" {
    try std.testing.expectFmt("[super]", "{}", .{KeyModifiers.super});
}

test "format-hyper-key-modifier" {
    try std.testing.expectFmt("[hyper]", "{}", .{KeyModifiers.hyper});
}

test "format-meta-key-modifier" {
    try std.testing.expectFmt("[meta]", "{}", .{KeyModifiers.meta});
}

test "format-keypad-key-modifier" {
    try std.testing.expectFmt("[keypad]", "{}", .{KeyModifiers.keypad});
}

test "format-caps-key-modifier" {
    try std.testing.expectFmt("[caps]", "{}", .{KeyModifiers.caps});
}

test "format-numlock-key-modifier" {
    try std.testing.expectFmt("[numlock]", "{}", .{KeyModifiers.numlock});
}

test "format-all-key-modifiers" {
    try std.testing.expectFmt("[shift+control+alt+super+hyper+meta+keypad+caps+numlock]", "{}", .{KeyModifiers.all});
}

test "from-crossterm-to-fuizon-shift-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.shift.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_SHIFT_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-control-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.control.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_CONTROL_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-alt-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.alt.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_ALT_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-super-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.super.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_SUPER_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-hyper-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.hyper.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_HYPER_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-meta-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.meta.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_META_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-keypad-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.keypad.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_KEYPAD_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-caps-lock-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.caps.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_CAPS_LOCK_KEY_MODIFIER).bitset,
    );
}

test "from-crossterm-to-fuizon-num-lock-key-modifier" {
    try std.testing.expectEqual(
        KeyModifiers.numlock.bitset,
        KeyModifiers.fromCrosstermKeyModifiers(c.CROSSTERM_NUM_LOCK_KEY_MODIFIER).bitset,
    );
}

test "format-unicode-key-code" {
    try std.testing.expectFmt("ö", "{}", .{KeyCode{ .char = 0x00f6 }});
}

test "format-backspace-key-code" {
    try std.testing.expectFmt("backspace", "{}", .{@as(KeyCode, KeyCode.backspace)});
}

test "format-enter-key-code" {
    try std.testing.expectFmt("enter", "{}", .{@as(KeyCode, KeyCode.enter)});
}

test "format-left-arrow-key-code" {
    try std.testing.expectFmt("left arrow", "{}", .{@as(KeyCode, KeyCode.left_arrow)});
}

test "format-right-arrow-key-code" {
    try std.testing.expectFmt("right arrow", "{}", .{@as(KeyCode, KeyCode.right_arrow)});
}

test "format-up-arrow-key-code" {
    try std.testing.expectFmt("up arrow", "{}", .{@as(KeyCode, KeyCode.up_arrow)});
}

test "format-down-arrow-key-code" {
    try std.testing.expectFmt("down arrow", "{}", .{@as(KeyCode, KeyCode.down_arrow)});
}

test "format-home-key-code" {
    try std.testing.expectFmt("home", "{}", .{@as(KeyCode, KeyCode.home)});
}

test "format-end-key-code" {
    try std.testing.expectFmt("end", "{}", .{@as(KeyCode, KeyCode.end)});
}

test "format-page-up-key-code" {
    try std.testing.expectFmt("page up", "{}", .{@as(KeyCode, KeyCode.page_up)});
}

test "format-page-down-key-code" {
    try std.testing.expectFmt("page down", "{}", .{@as(KeyCode, KeyCode.page_down)});
}

test "format-tab-key-code" {
    try std.testing.expectFmt("tab", "{}", .{@as(KeyCode, KeyCode.tab)});
}

test "format-backtab-key-code" {
    try std.testing.expectFmt("backtab", "{}", .{@as(KeyCode, KeyCode.backtab)});
}

test "format-delete-key-code" {
    try std.testing.expectFmt("delete", "{}", .{@as(KeyCode, KeyCode.delete)});
}

test "format-insert-key-code" {
    try std.testing.expectFmt("insert", "{}", .{@as(KeyCode, KeyCode.insert)});
}

test "format-escape-key-code" {
    try std.testing.expectFmt("escape", "{}", .{@as(KeyCode, KeyCode.escape)});
}

test "format-f1-key-code" {
    try std.testing.expectFmt("f1", "{}", .{@as(KeyCode, KeyCode.f1)});
}

test "format-f2-key-code" {
    try std.testing.expectFmt("f2", "{}", .{@as(KeyCode, KeyCode.f2)});
}

test "format-f3-key-code" {
    try std.testing.expectFmt("f3", "{}", .{@as(KeyCode, KeyCode.f3)});
}

test "format-f4-key-code" {
    try std.testing.expectFmt("f4", "{}", .{@as(KeyCode, KeyCode.f4)});
}

test "format-f5-key-code" {
    try std.testing.expectFmt("f5", "{}", .{@as(KeyCode, KeyCode.f5)});
}

test "format-f6-key-code" {
    try std.testing.expectFmt("f6", "{}", .{@as(KeyCode, KeyCode.f6)});
}

test "format-f7-key-code" {
    try std.testing.expectFmt("f7", "{}", .{@as(KeyCode, KeyCode.f7)});
}

test "format-f8-key-code" {
    try std.testing.expectFmt("f8", "{}", .{@as(KeyCode, KeyCode.f8)});
}

test "format-f9-key-code" {
    try std.testing.expectFmt("f9", "{}", .{@as(KeyCode, KeyCode.f9)});
}

test "format-f10-key-code" {
    try std.testing.expectFmt("f10", "{}", .{@as(KeyCode, KeyCode.f10)});
}

test "format-f11-key-code" {
    try std.testing.expectFmt("f11", "{}", .{@as(KeyCode, KeyCode.f11)});
}

test "format-f12-key-code" {
    try std.testing.expectFmt("f12", "{}", .{@as(KeyCode, KeyCode.f12)});
}

test "from-crossterm-to-fuizon-unicode-key-code" {
    try std.testing.expectEqual(
        KeyCode{ .char = 5915 },
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_CHAR_KEY, 5915),
    );
}

test "from-crossterm-to-fuizon-backspace-key-code" {
    try std.testing.expectEqual(
        KeyCode.backspace,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_BACKSPACE_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-enter-key-code" {
    try std.testing.expectEqual(
        KeyCode.enter,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_ENTER_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-left-arrow-key-code" {
    try std.testing.expectEqual(
        KeyCode.left_arrow,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_LEFT_ARROW_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-right-arrow-key-code" {
    try std.testing.expectEqual(
        KeyCode.right_arrow,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_RIGHT_ARROW_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-up-arrow-key-code" {
    try std.testing.expectEqual(
        KeyCode.up_arrow,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_UP_ARROW_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-down-arrow-key-code" {
    try std.testing.expectEqual(
        KeyCode.down_arrow,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_DOWN_ARROW_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-home-key-code" {
    try std.testing.expectEqual(
        KeyCode.home,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_HOME_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-end-key-code" {
    try std.testing.expectEqual(
        KeyCode.end,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_END_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-page-up-key-code" {
    try std.testing.expectEqual(
        KeyCode.page_up,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_PAGE_UP_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-page-down-key-code" {
    try std.testing.expectEqual(
        KeyCode.page_down,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_PAGE_DOWN_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-tab-key-code" {
    try std.testing.expectEqual(
        KeyCode.tab,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_TAB_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-backtab-key-code" {
    try std.testing.expectEqual(
        KeyCode.backtab,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_BACKTAB_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-delete-key-code" {
    try std.testing.expectEqual(
        KeyCode.delete,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_DELETE_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-insert-key-code" {
    try std.testing.expectEqual(
        KeyCode.insert,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_INSERT_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-escape-key-code" {
    try std.testing.expectEqual(
        KeyCode.escape,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_ESCAPE_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f1-key-code" {
    try std.testing.expectEqual(
        KeyCode.f1,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F1_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f2-key-code" {
    try std.testing.expectEqual(
        KeyCode.f2,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F2_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f3-key-code" {
    try std.testing.expectEqual(
        KeyCode.f3,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F3_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f4-key-code" {
    try std.testing.expectEqual(
        KeyCode.f4,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F4_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f5-key-code" {
    try std.testing.expectEqual(
        KeyCode.f5,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F5_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f6-key-code" {
    try std.testing.expectEqual(
        KeyCode.f6,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F6_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f7-key-code" {
    try std.testing.expectEqual(
        KeyCode.f7,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F7_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f8-key-code" {
    try std.testing.expectEqual(
        KeyCode.f8,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F8_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f9-key-code" {
    try std.testing.expectEqual(
        KeyCode.f9,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F9_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f10-key-code" {
    try std.testing.expectEqual(
        KeyCode.f10,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F10_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f11-key-code" {
    try std.testing.expectEqual(
        KeyCode.f11,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F11_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-f12-key-code" {
    try std.testing.expectEqual(
        KeyCode.f12,
        KeyCode.fromCrosstermKeyCode(c.CROSSTERM_F12_KEY, undefined),
    );
}

test "from-crossterm-to-fuizon-resize-event" {
    try std.testing.expectEqual(
        ResizeEvent{ .width = 59, .height = 15 },
        ResizeEvent.fromCrosstermResizeEvent(c.crossterm_resize_event{
            .width = 59,
            .height = 15,
        }),
    );
}

test "from-invalid-crossterm-event-to-fuizon-event" {
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = std.math.maxInt(u32),
            .unnamed_0 = undefined,
        }),
    );
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = c.CROSSTERM_KEY_EVENT,
            .unnamed_0 = .{
                .key = .{
                    .type = std.math.maxInt(u32),
                    .code = undefined,
                    .modifiers = undefined,
                },
            },
        }),
    );
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = c.CROSSTERM_KEY_EVENT,
            .unnamed_0 = .{
                .key = .{
                    .type = c.CROSSTERM_CHAR_KEY,
                    .code = std.math.maxInt(u21) + 1,
                    .modifiers = undefined,
                },
            },
        }),
    );
}
