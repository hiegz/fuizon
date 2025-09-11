const std = @import("std");
const c = @import("headers.zig").c;

pub const Attribute = enum(u8) {
    // zig fmt: off
    bold       = 1 << 0,
    dim        = 1 << 1,
    underlined = 1 << 2,
    reverse    = 1 << 3,
    hidden     = 1 << 4,
    // zig fmt: on

    pub fn format(self: Attribute, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .bold       => _ = try writer.write("bold"),
            .dim        => _ = try writer.write("dim"),
            .underlined => _ = try writer.write("underlined"),
            .reverse    => _ = try writer.write("reverse"),
            .hidden     => _ = try writer.write("hidden"),
        }
        // zig fmt: on
    }

    pub fn bitset(attribute: Attribute) u8 {
        return @intFromEnum(attribute);
    }
};

pub const Attributes = struct {
    // zig fmt: off
    pub const none = Attributes.join(&.{});
    pub const all  = Attributes.join(&.{ .bold, .dim, .underlined, .reverse, .hidden });
    // zig fmt: on

    bitset: u8,

    pub fn join(attributes: []const Attribute) Attributes {
        var target = Attributes{ .bitset = 0 };
        target.set(attributes);
        return target;
    }

    pub fn set(self: *Attributes, attributes: []const Attribute) void {
        for (attributes) |attribute| {
            self.bitset |= attribute.bitset();
        }
    }

    pub fn reset(self: *Attributes, attributes: []const Attribute) void {
        for (attributes) |attribute| {
            self.bitset &= ~attribute.bitset();
        }
    }

    pub fn contain(self: Attributes, attributes: []const Attribute) bool {
        for (attributes) |attribute| {
            if ((self.bitset & attribute.bitset()) == 0)
                return false;
        }
        return true;
    }

    pub fn format(self: Attributes, writer: *std.io.Writer) !void {
        var attributes = [_]Attribute{.bold} ** 5;
        var nattributes: usize = 0;

        if (self.contain(&.{.bold})) {
            attributes[nattributes] = .bold;
            nattributes += 1;
        }
        if (self.contain(&.{.dim})) {
            attributes[nattributes] = .dim;
            nattributes += 1;
        }
        if (self.contain(&.{.underlined})) {
            attributes[nattributes] = .underlined;
            nattributes += 1;
        }
        if (self.contain(&.{.reverse})) {
            attributes[nattributes] = .reverse;
            nattributes += 1;
        }
        if (self.contain(&.{.hidden})) {
            attributes[nattributes] = .hidden;
            nattributes += 1;
        }

        _ = try writer.write("{");
        for (attributes[0..nattributes], 0..) |attribute, i| {
            try writer.print(" {f}", .{attribute});
            if (i + 1 < nattributes)
                _ = try writer.write(",");
        }
        _ = try writer.write(" }");
    }
};

pub const Alignment = enum {
    start,
    center,
    end,
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
    default,
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
            .default      => return .{ .type = c.CROSSTERM_RESET_COLOR,        .unnamed_0 = undefined },
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
    foreground_color: ?Color = .default,
    background_color: ?Color = .default,

    attributes: Attributes = Attributes.none,
};

test "no-attributes" {
    try std.testing.expectEqual(0, Attributes.none.bitset);
}

test "all-attributes" {
    try std.testing.expect(Attributes.all.contain(&.{
        .bold,
        .dim,
        .underlined,
        .reverse,
        .hidden,
    }));
}

test "attributes-contain" {
    var attributes = Attributes.all;
    attributes.reset(&.{ .bold, .reverse });

    try std.testing.expect(!attributes.contain(&.{.bold}));
    try std.testing.expect(!attributes.contain(&.{.reverse}));
    try std.testing.expect(!attributes.contain(&.{ .bold, .reverse }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .bold }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .reverse }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .bold, .reverse }));
    try std.testing.expect(attributes.contain(&.{.dim}));
}

test "attributes-set-reset" {
    var left = Attributes.none;
    left.set(&.{ .dim, .hidden, .underlined });
    var right = Attributes.all;
    right.reset(&.{ .bold, .reverse });
    try std.testing.expectEqual(left.bitset, right.bitset);
}

test "format-bold-attribute" {
    try std.testing.expectFmt("bold", "{f}", .{Attribute.bold});
}

test "format-dim-attribute" {
    try std.testing.expectFmt("dim", "{f}", .{Attribute.dim});
}

test "format-underlined-attribute" {
    try std.testing.expectFmt("underlined", "{f}", .{Attribute.underlined});
}

test "format-reverse-attribute" {
    try std.testing.expectFmt("reverse", "{f}", .{Attribute.reverse});
}

test "format-hidden-attribute" {
    try std.testing.expectFmt("hidden", "{f}", .{Attribute.hidden});
}

test "format-empty-attribute-set" {
    try std.testing.expectFmt("{ }", "{f}", .{Attributes.none});
}

test "format-all-attributes" {
    try std.testing.expectFmt("{ bold, dim, underlined, reverse, hidden }", "{f}", .{Attributes.all});
}

test "from-fuizon-to-crossterm-default-color" {
    try std.testing.expectEqual(
        @as(c_uint, @intCast(c.CROSSTERM_RESET_COLOR)),
        Color.toCrosstermColor(.default).type,
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
