const std = @import("std");
const c = @import("headers.zig").c;

pub const Attributes = struct {
    // zig fmt: off
    pub const none       = Attributes{ .bitset = 0      };
    pub const bold       = Attributes{ .bitset = 1 << 0 };
    pub const dim        = Attributes{ .bitset = 1 << 1 };
    pub const underlined = Attributes{ .bitset = 1 << 2 };
    pub const reverse    = Attributes{ .bitset = 1 << 3 };
    pub const hidden     = Attributes{ .bitset = 1 << 4 };
    pub const all        = Attributes{ .bitset = 0x1f   };
    // zig fmt: on

    bitset: u8,

    pub fn format(
        self: Attributes,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        var attributes = [_][]const u8{""} ** 5;
        var nattributes: usize = 0;

        if ((self.bitset & Attributes.bold.bitset) != 0) {
            attributes[nattributes] = "bold";
            nattributes += 1;
        }
        if ((self.bitset & Attributes.dim.bitset) != 0) {
            attributes[nattributes] = "dim";
            nattributes += 1;
        }
        if ((self.bitset & Attributes.underlined.bitset) != 0) {
            attributes[nattributes] = "underlined";
            nattributes += 1;
        }
        if ((self.bitset & Attributes.reverse.bitset) != 0) {
            attributes[nattributes] = "reverse";
            nattributes += 1;
        }
        if ((self.bitset & Attributes.hidden.bitset) != 0) {
            attributes[nattributes] = "hidden";
            nattributes += 1;
        }

        try writer.print("[", .{});
        for (0..nattributes -| 1) |i|
            try writer.print("{s}, ", .{attributes[i]});
        try writer.print("{s}", .{attributes[nattributes -| 1]});
        try writer.print("]", .{});
    }

    pub fn toCrosstermAttributes(attributes: Attributes) c.crossterm_attributes {
        var target: c.crossterm_attributes = 0;

        // zig fmt: off
        if ((attributes.bitset & Attributes.bold.bitset)       != 0) target |= @intCast(c.CROSSTERM_BOLD_ATTRIBUTE);
        if ((attributes.bitset & Attributes.dim.bitset)        != 0) target |= @intCast(c.CROSSTERM_DIM_ATTRIBUTE);
        if ((attributes.bitset & Attributes.underlined.bitset) != 0) target |= @intCast(c.CROSSTERM_UNDERLINED_ATTRIBUTE);
        if ((attributes.bitset & Attributes.reverse.bitset)    != 0) target |= @intCast(c.CROSSTERM_REVERSE_ATTRIBUTE);
        if ((attributes.bitset & Attributes.hidden.bitset)     != 0) target |= @intCast(c.CROSSTERM_HIDDEN_ATTRIBUTE);
        // zig fmt: on

        return target;
    }
};

pub const AnsiColor = struct {
    value: u8,

    pub fn toCrosstermAnsiColor(color: AnsiColor) c.crossterm_ansi_color {
        return .{ .value = color.value };
    }
};

pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn toCrosstermRgbColor(color: RgbColor) c.crossterm_rgb_color {
        return .{ .r = color.r, .g = color.g, .b = color.b };
    }
};

pub const Color = union(enum) {
    black,
    white,
    red,
    green,
    blue,
    yellow,
    magenta,
    cyan,
    grey,
    dark_red,
    dark_green,
    dark_blue,
    dark_yellow,
    dark_magenta,
    dark_cyan,
    dark_grey,

    ansi: AnsiColor,
    rgb: RgbColor,

    pub fn toCrosstermColor(color: Color) c.crossterm_color {
        // zig fmt: off
        switch (color) {
            .black        => return .{ .type = c.CROSSTERM_BLACK_COLOR,        .unnamed_0 = undefined },
            .white        => return .{ .type = c.CROSSTERM_WHITE_COLOR,        .unnamed_0 = undefined },
            .red          => return .{ .type = c.CROSSTERM_RED_COLOR,          .unnamed_0 = undefined },
            .green        => return .{ .type = c.CROSSTERM_GREEN_COLOR,        .unnamed_0 = undefined },
            .blue         => return .{ .type = c.CROSSTERM_BLUE_COLOR,         .unnamed_0 = undefined },
            .yellow       => return .{ .type = c.CROSSTERM_YELLOW_COLOR,       .unnamed_0 = undefined },
            .magenta      => return .{ .type = c.CROSSTERM_MAGENTA_COLOR,      .unnamed_0 = undefined },
            .cyan         => return .{ .type = c.CROSSTERM_CYAN_COLOR,         .unnamed_0 = undefined },
            .grey         => return .{ .type = c.CROSSTERM_GREY_COLOR,         .unnamed_0 = undefined },
            .dark_red     => return .{ .type = c.CROSSTERM_DARK_RED_COLOR,     .unnamed_0 = undefined },
            .dark_green   => return .{ .type = c.CROSSTERM_DARK_GREEN_COLOR,   .unnamed_0 = undefined },
            .dark_blue    => return .{ .type = c.CROSSTERM_DARK_BLUE_COLOR,    .unnamed_0 = undefined },
            .dark_yellow  => return .{ .type = c.CROSSTERM_DARK_YELLOW_COLOR,  .unnamed_0 = undefined },
            .dark_magenta => return .{ .type = c.CROSSTERM_DARK_MAGENTA_COLOR, .unnamed_0 = undefined },
            .dark_cyan    => return .{ .type = c.CROSSTERM_DARK_CYAN_COLOR,    .unnamed_0 = undefined },
            .dark_grey    => return .{ .type = c.CROSSTERM_DARK_GREY_COLOR,    .unnamed_0 = undefined },

            .ansi         => return .{ .type = c.CROSSTERM_ANSI_COLOR,         .unnamed_0 = .{ .ansi = color.ansi.toCrosstermAnsiColor() } },
            .rgb          => return .{ .type = c.CROSSTERM_RGB_COLOR,          .unnamed_0 = .{ .rgb  = color.rgb.toCrosstermRgbColor() } },
        }
        // zig fmt: on
    }
};

pub const Style = struct {
    foreground_color: ?Color = null,
    background_color: ?Color = null,

    attributes: Attributes = Attributes.none,

    pub fn toCrosstermStyle(style: Style) c.crossterm_style {
        var target: c.crossterm_style = undefined;

        if (style.foreground_color) |foreground| {
            target.has_foreground_color = true;
            target.foreground_color = foreground.toCrosstermColor();
        } else {
            target.has_foreground_color = false;
        }

        if (style.background_color) |background| {
            target.has_background_color = true;
            target.background_color = background.toCrosstermColor();
        } else {
            target.has_background_color = false;
        }

        target.has_underline_color = false;
        target.attributes = style.attributes.toCrosstermAttributes();

        return target;
    }
};

test "null-attribute" {
    try std.testing.expectEqual(
        0,
        // zig fmt: off
        (Attributes.bold.bitset       |
         Attributes.dim.bitset        |
         Attributes.underlined.bitset |
         Attributes.reverse.bitset    |
         Attributes.hidden.bitset)    & Attributes.none.bitset
        // zig fmt: on
        ,
    );
}

test "all-attributes" {
    try std.testing.expectEqual(
        // zig fmt: off
        Attributes.bold.bitset        |
        Attributes.dim.bitset         |
        Attributes.underlined.bitset  |
        Attributes.reverse.bitset     |
        Attributes.hidden.bitset
        // zig fmt: on
        ,
        Attributes.all.bitset,
    );
}

test "format-null-attribute" {
    try std.testing.expectFmt("[]", "{}", .{Attributes.none});
}

test "format-bold-attribute" {
    try std.testing.expectFmt("[bold]", "{}", .{Attributes.bold});
}

test "format-dim-attribute" {
    try std.testing.expectFmt("[dim]", "{}", .{Attributes.dim});
}

test "format-underlined-attribute" {
    try std.testing.expectFmt("[underlined]", "{}", .{Attributes.underlined});
}

test "format-reverse-attribute" {
    try std.testing.expectFmt("[reverse]", "{}", .{Attributes.reverse});
}

test "format-hidden-attribute" {
    try std.testing.expectFmt("[hidden]", "{}", .{Attributes.hidden});
}

test "format-all-attributes" {
    try std.testing.expectFmt("[bold, dim, underlined, reverse, hidden]", "{}", .{Attributes.all});
}

test "from-fuizon-to-crossterm-bold-attribute" {
    try std.testing.expectEqual(
        c.CROSSTERM_BOLD_ATTRIBUTE,
        Attributes.bold.toCrosstermAttributes(),
    );
}

test "from-fuizon-to-crossterm-dim-attribute" {
    try std.testing.expectEqual(
        c.CROSSTERM_DIM_ATTRIBUTE,
        Attributes.dim.toCrosstermAttributes(),
    );
}

test "from-fuizon-to-crossterm-underlined-attribute" {
    try std.testing.expectEqual(
        c.CROSSTERM_UNDERLINED_ATTRIBUTE,
        Attributes.underlined.toCrosstermAttributes(),
    );
}

test "from-fuizon-to-crossterm-reverse-attribute" {
    try std.testing.expectEqual(
        c.CROSSTERM_REVERSE_ATTRIBUTE,
        Attributes.reverse.toCrosstermAttributes(),
    );
}

test "from-fuizon-to-crossterm-hidden-attribute" {
    try std.testing.expectEqual(
        c.CROSSTERM_HIDDEN_ATTRIBUTE,
        Attributes.hidden.toCrosstermAttributes(),
    );
}

test "from-fuizon-to-crossterm-black-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_BLACK_COLOR)),
        Color.toCrosstermColor(.black).type,
    );
}

test "from-fuizon-to-crossterm-white-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_WHITE_COLOR)),
        Color.toCrosstermColor(.white).type,
    );
}

test "from-fuizon-to-crossterm-red-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_RED_COLOR)),
        Color.toCrosstermColor(.red).type,
    );
}

test "from-fuizon-to-crossterm-green-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_GREEN_COLOR)),
        Color.toCrosstermColor(.green).type,
    );
}

test "from-fuizon-to-crossterm-blue-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_BLUE_COLOR)),
        Color.toCrosstermColor(.blue).type,
    );
}

test "from-fuizon-to-crossterm-yellow-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_YELLOW_COLOR)),
        Color.toCrosstermColor(.yellow).type,
    );
}

test "from-fuizon-to-crossterm-magenta-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_MAGENTA_COLOR)),
        Color.toCrosstermColor(.magenta).type,
    );
}

test "from-fuizon-to-crossterm-cyan-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_CYAN_COLOR)),
        Color.toCrosstermColor(.cyan).type,
    );
}

test "from-fuizon-to-crossterm-grey-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_GREY_COLOR)),
        Color.toCrosstermColor(.grey).type,
    );
}

test "from-fuizon-to-crossterm-dark-red-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_RED_COLOR)),
        Color.toCrosstermColor(.dark_red).type,
    );
}

test "from-fuizon-to-crossterm-dark-green-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_GREEN_COLOR)),
        Color.toCrosstermColor(.dark_green).type,
    );
}

test "from-fuizon-to-crossterm-dark-blue-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_BLUE_COLOR)),
        Color.toCrosstermColor(.dark_blue).type,
    );
}

test "from-fuizon-to-crossterm-dark-yellow-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_YELLOW_COLOR)),
        Color.toCrosstermColor(.dark_yellow).type,
    );
}

test "from-fuizon-to-crossterm-dark-magenta-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_MAGENTA_COLOR)),
        Color.toCrosstermColor(.dark_magenta).type,
    );
}

test "from-fuizon-to-crossterm-dark-cyan-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_CYAN_COLOR)),
        Color.toCrosstermColor(.dark_cyan).type,
    );
}

test "from-fuizon-to-crossterm-dark-grey-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_DARK_GREY_COLOR)),
        Color.toCrosstermColor(.dark_grey).type,
    );
}

test "from-fuizon-to-crossterm-ansi-color" {
    const expected = c.crossterm_color{ .type = c.CROSSTERM_ANSI_COLOR, .unnamed_0 = .{ .ansi = .{ .value = 59 } } };
    const actual = Color.toCrosstermColor(.{ .ansi = .{ .value = 59 } });

    try std.testing.expectEqual(expected.type, actual.type);
    try std.testing.expectEqual(expected.unnamed_0.ansi, actual.unnamed_0.ansi);
}

test "from-fuizon-to-crossterm-rgb-color" {
    const expected = c.crossterm_color{ .type = c.CROSSTERM_RGB_COLOR, .unnamed_0 = .{ .rgb = .{ .r = 5, .b = 9, .g = 15 } } };
    const actual = Color.toCrosstermColor(.{ .rgb = .{ .r = 5, .b = 9, .g = 15 } });

    try std.testing.expectEqual(expected.type, actual.type);
    try std.testing.expectEqual(expected.unnamed_0.rgb, actual.unnamed_0.rgb);
}
