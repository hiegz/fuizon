const std = @import("std");

pub const Border = enum(u8) {
    // zig fmt: off
    top    = 1 << 0,
    bottom = 1 << 1,
    left   = 1 << 2,
    right  = 1 << 3,
    // zig fmt: on

    pub fn format(
        self: Border,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            // zig fmt: off
            .top    => _ = try writer.write("top"),
            .bottom => _ = try writer.write("bottom"),
            .left   => _ = try writer.write("left"),
            .right  => _ = try writer.write("right"),
            // zig fmt: on
        }
    }

    pub fn bitset(self: Border) u8 {
        return @intFromEnum(self);
    }
};

pub const Borders = struct {
    // zig fmt: off
    pub const none = Borders.join(&.{});
    pub const all  = Borders.join(&.{.top, .bottom, .left, .right});
    // zig fmt: on

    bitset: u8,

    pub fn join(borders: []const Border) Borders {
        var target: Borders = .{ .bitset = 0 };
        target.set(borders);
        return target;
    }

    pub fn set(self: *Borders, borders: []const Border) void {
        for (borders) |border| {
            self.bitset |= border.bitset();
        }
    }

    pub fn reset(self: *Borders, borders: []const Border) void {
        for (borders) |border| {
            self.bitset &= ~border.bitset();
        }
    }

    pub fn contain(self: Borders, borders: []const Border) bool {
        for (borders) |border|
            if ((self.bitset & border.bitset()) == 0)
                return false;
        return true;
    }

    pub fn format(
        self: Borders,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        var borders: [4]Border = undefined;
        var nborders: usize = 0;

        if (self.contain(&.{.top})) {
            borders[nborders] = .top;
            nborders += 1;
        }
        if (self.contain(&.{.bottom})) {
            borders[nborders] = .bottom;
            nborders += 1;
        }
        if (self.contain(&.{.left})) {
            borders[nborders] = .left;
            nborders += 1;
        }
        if (self.contain(&.{.right})) {
            borders[nborders] = .right;
            nborders += 1;
        }

        try writer.print("{any}", .{borders[0..nborders]});
    }
};

pub const BorderType = enum(u8) {
    /// A plain, simple border.
    ///
    /// ┌───────┐
    /// │       │
    /// └───────┘
    ///
    plain = 0,

    /// A plain border with rounded corners.
    ///
    /// ╭───────╮
    /// │       │
    /// ╰───────╯
    ///
    rounded = 1,

    /// A doubled border.
    ///
    /// ╔═══════╗
    /// ║       ║
    /// ╚═══════╝
    ///
    double = 2,

    /// A thick border.
    ///
    /// ┏━━━━━━━┓
    /// ┃       ┃
    /// ┗━━━━━━━┛
    ///
    thick = 3,
};

const BorderSet = struct {
    // zig fmt: off
    h:  u21, // horizontal line
    v:  u21, // vertical line
    tl: u21, // top left corner
    tr: u21, // top right corner
    bl: u21, // bottom left corner
    br: u21, // bottom right corner
    // zig fmt: on

    pub fn fromBorderType(border_type: BorderType) *const BorderSet {
        const t = map[@intFromEnum(border_type)][0];
        const v = &map[@intFromEnum(border_type)][1];

        std.debug.assert(t == border_type);

        return v;
    }

    const map = [_]struct {
        BorderType,
        BorderSet,
    }{
        // Plain (i = 0)
        // zig fmt: off
        .{
            BorderType.plain,
            .{
                .h  = '─',
                .v  = '│',
                .tl = '┌',
                .bl = '└',
                .tr = '┐',
                .br = '┘',
            },
        },
        // zig fmt: on

        // Rounded (i = 1)
        // zig fmt: off
        .{
            BorderType.rounded,
            .{
                .h  = '─',
                .v  = '│',
                .tl = '╭',
                .bl = '╰',
                .tr = '╮',
                .br = '╯',
            },
        },
        // zig fmt: on

        // Double (i = 2)
        // zig fmt: off
        .{
            BorderType.double,
            .{
                .h  = '═',
                .v  = '║',
                .tl = '╔',
                .bl = '╚',
                .tr = '╗',
                .br = '╝',
            },
        },

        // Thick (i = 3)
        // zig fmt: off
        .{
            BorderType.thick,
            .{
                .h  = '━',
                .v  = '┃',
                .tl = '┏',
                .bl = '┗',
                .tr = '┓',
                .br = '┛',
            },
        }
        // zig fmt: on
    };  // zig fmt: on
};

//
// Tests
//

test "Border.format() the top border" {
    try std.testing.expectFmt("top", "{}", .{Border.top});
}

test "Border.format() the bottom border" {
    try std.testing.expectFmt("bottom", "{}", .{Border.bottom});
}

test "Border.format() the left border" {
    try std.testing.expectFmt("left", "{}", .{Border.left});
}

test "Border.format() the right border" {
    try std.testing.expectFmt("right", "{}", .{Border.right});
}

test "Borders.format() with no borders" {
    try std.testing.expectFmt("{  }", "{}", .{Borders.none});
}

test "Borders.format() with the top borders" {
    try std.testing.expectFmt("{ top }", "{}", .{Borders.join(&.{.top})});
}

test "Borders.format() with the bottom borders" {
    try std.testing.expectFmt("{ bottom }", "{}", .{Borders.join(&.{.bottom})});
}

test "Borders.format() with the left borders" {
    try std.testing.expectFmt("{ left }", "{}", .{Borders.join(&.{.left})});
}

test "Borders.format() with the right borders" {
    try std.testing.expectFmt("{ right }", "{}", .{Borders.join(&.{.right})});
}

test "Borders.format() with all borders" {
    try std.testing.expectFmt("{ top, bottom, left, right }", "{}", .{Borders.all});
}

test "Borders.set() should add and Borders.reset() should remove the specified borders" {
    var left = Borders.none;
    left.set(&.{ .top, .bottom });
    var right = Borders.all;
    right.reset(&.{ .left, .right });

    try std.testing.expectEqual(left.bitset, right.bitset);
}
