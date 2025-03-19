const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Color = fuizon.style.Color;
const Style = fuizon.style.Style;
const Alignment = fuizon.style.Alignment;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;
const Area = fuizon.layout.Area;

pub const Container = struct {
    title: []const u8 = "",
    title_style: Style = .{},
    title_alignment: Alignment = .start,

    borders: Borders = Borders.none,
    border_style: Style = .{},
    border_type: BorderType = .plain,

    margin_top: u16 = 0,
    margin_bottom: u16 = 0,
    margin_left: u16 = 0,
    margin_right: u16 = 0,

    //

    /// Calculates the inner area of the container based on its borders and
    /// margins.
    pub fn inner(
        self: Container,
        area: Area,
    ) Area {
        return .{
            .width = self.innerWidth(area.width),
            .height = self.innerHeight(area.height),
            .origin = .{
                .x = self.innerX(area.origin.x),
                .y = self.innerY(area.origin.y),
            },
        };
    }

    /// Calculates the inner width of the container based on its borders and
    /// margins.
    pub fn innerWidth(self: Container, outer_width: u16) u16 {
        // zig fmt: off
        return outer_width
            -| (self.margin_left + self.margin_right)
            -| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Calculates the inner height of the container based on its borders and
    /// margins.
    pub fn innerHeight(self: Container, outer_heigth: u16) u16 {
        // zig fmt: off
        return outer_heigth
            -| (self.margin_top + self.margin_bottom)
            -| (if (self.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Calculates the x coordinate of the inner origin based on the
    /// container's borders and margins.
    pub fn innerX(self: Container, outer_x: u16) u16 {
        // zig fmt: off
        return outer_x
            + self.margin_left
            + (if (self.borders.contain(&.{.left})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Calculates the y coordinate of the inner origin based on the
    /// container's borders and margins.
    pub fn innerY(self: Container, outer_y: u16) u16 {
        // zig fmt: off
        return outer_y
            + self.margin_top
            + (if (self.borders.contain(&.{.top})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    //

    /// Renders the container within a section of the specified frame,
    /// as defined by the provided area.
    pub fn render(self: Container, frame: *Frame, area: Area) void {
        if (area.width == 0 or area.height == 0)
            return;

        self.renderBorders(frame, area);
        self.renderTitle(frame, area);
    }

    //

    fn renderTitle(self: Container, frame: *Frame, area: Area) void {
        const left: u16 = area.left() + if (self.borders.contain(&.{.left})) @as(u16, 1) else @as(u16, 0);
        const right: u16 = area.right() - if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0);

        if (self.title.len == 0)
            return;
        if (left >= right)
            return;

        var utf8it: std.unicode.Utf8Iterator = undefined;

        var title_length: usize = 0;
        utf8it = (std.unicode.Utf8View.init(self.title) catch unreachable).iterator();
        while (utf8it.nextCodepoint()) |_| : (title_length += 1) {}

        const available_length = right - left;
        const missing_length = title_length -| available_length;

        // The displayable string fraction is irrelevant and can be omitted at this stage.
        if (missing_length > 0 and title_length - missing_length < 7)
            return;

        if (missing_length > 0) {
            const title_end = title_length - missing_length - 3;
            utf8it = (std.unicode.Utf8View.init(self.title) catch unreachable).iterator();
            var x = left;
            const y = area.top();
            while (utf8it.nextCodepoint()) |code_point| : (x += 1) {
                if (x - left >= title_end)
                    break;
                std.debug.assert(x < right);
                const cell = frame.index(x, y);
                cell.content = code_point;
                cell.width = 1;
                cell.style = self.title_style;
            }
            while (x < right) : (x += 1) {
                const cell = frame.index(x, y);
                cell.content = '.';
                cell.width = 1;
                cell.style = self.title_style;
            }
            return;
        }

        const free_space = available_length - title_length;
        const start = switch (self.title_alignment) {
            // zig fmt: off
            .start  => left,
            .center => left + free_space / 2,
            .end    => left + free_space,
            // zig fmt: on
        };
        utf8it = (std.unicode.Utf8View.init(self.title) catch unreachable).iterator();
        var x = start;
        const y = area.top();
        while (utf8it.nextCodepoint()) |code_point| : (x += 1) {
            std.debug.assert(x < right);
            const cell = frame.index(@intCast(x), @intCast(y));
            cell.content = code_point;
            cell.width = 1;
            cell.style = self.title_style;
        }
    }

    //

    fn renderBorders(self: Container, frame: *Frame, area: Area) void {
        self.renderTopSide(frame, area);
        self.renderBottomSide(frame, area);
        self.renderLeftSide(frame, area);
        self.renderRightSide(frame, area);

        self.renderTopLeftCorner(frame, area);
        self.renderTopRightCorner(frame, area);
        self.renderBottomLeftCorner(frame, area);
        self.renderBottomRightCorner(frame, area);
    }

    fn renderTopSide(self: Container, frame: *Frame, area: Area) void {
        if (!self.borders.contain(&.{.top}))
            return;

        const y = area.top();
        const content = BorderSet.fromBorderType(self.border_type).h;

        for (area.left()..area.right()) |x| {
            const cell = frame.index(@intCast(x), @intCast(y));
            cell.width = 1;
            cell.content = content;
            cell.style = self.border_style;
        }
    }

    fn renderBottomSide(self: Container, frame: *Frame, area: Area) void {
        if (!self.borders.contain(&.{.bottom}))
            return;

        const y = area.bottom() - 1;
        const content = BorderSet.fromBorderType(self.border_type).h;

        for (area.left()..area.right()) |x| {
            const cell = frame.index(@intCast(x), @intCast(y));
            cell.width = 1;
            cell.content = content;
            cell.style = self.border_style;
        }
    }

    fn renderLeftSide(self: Container, frame: *Frame, area: Area) void {
        if (!self.borders.contain(&.{.left}))
            return;

        const x = area.left();
        const content = BorderSet.fromBorderType(self.border_type).v;

        for (area.top()..area.bottom()) |y| {
            const cell = frame.index(@intCast(x), @intCast(y));
            cell.width = 1;
            cell.content = content;
            cell.style = self.border_style;
        }
    }

    fn renderRightSide(self: Container, frame: *Frame, area: Area) void {
        if (!self.borders.contain(&.{.right}))
            return;

        const x = area.right() - 1;
        const content = BorderSet.fromBorderType(self.border_type).v;

        for (area.top()..area.bottom()) |y| {
            const cell = frame.index(@intCast(x), @intCast(y));
            cell.width = 1;
            cell.content = content;
            cell.style = self.border_style;
        }
    }

    fn renderTopLeftCorner(self: Container, frame: *Frame, area: Area) void {
        if (area.width == 0 or area.height == 0 or !self.borders.contain(&.{ .top, .left }))
            return;
        const cell = frame.index(area.left(), area.top());
        cell.width = 1;
        cell.content = BorderSet.fromBorderType(self.border_type).tl;
        cell.style = self.border_style;
    }

    fn renderTopRightCorner(self: Container, frame: *Frame, area: Area) void {
        if (area.width == 0 or area.height == 0 or !self.borders.contain(&.{ .top, .right }))
            return;
        const cell = frame.index(area.right() - 1, area.top());
        cell.width = 1;
        cell.content = BorderSet.fromBorderType(self.border_type).tr;
        cell.style = self.border_style;
    }

    fn renderBottomLeftCorner(self: Container, frame: *Frame, area: Area) void {
        if (area.width == 0 or area.height == 0 or !self.borders.contain(&.{ .bottom, .left }))
            return;
        const cell = frame.index(area.left(), area.bottom() - 1);
        cell.width = 1;
        cell.content = BorderSet.fromBorderType(self.border_type).bl;
        cell.style = self.border_style;
    }

    fn renderBottomRightCorner(self: Container, frame: *Frame, area: Area) void {
        if (area.width == 0 or area.height == 0 or !self.borders.contain(&.{ .bottom, .right }))
            return;
        const cell = frame.index(area.right() - 1, area.bottom() - 1);
        cell.width = 1;
        cell.content = BorderSet.fromBorderType(self.border_type).br;
        cell.style = self.border_style;
    }
};

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
// Border Tests
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

//
// Container Tests
//

test "Container.render() should render borders" {
    const TestCase = struct {
        const Self = @This();

        id: usize,
        content: []const []const u8,
        borders: Borders = Borders.none,
        border_type: BorderType = .plain,

        title: ?[]const u8 = null,
        title_style: Style = undefined,
        title_alignment: Alignment = undefined,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    const expected_frame = try Frame.initContent(std.testing.allocator, self.content, .{});
                    defer expected_frame.deinit();

                    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
                    defer actual_frame.deinit();
                    actual_frame.reset();

                    var container = Container{};

                    container.borders = self.borders;
                    container.border_type = self.border_type;
                    if (self.title) |title| {
                        container.title = title;
                        container.title_style = self.title_style;
                        container.title_alignment = self.title_alignment;
                    }

                    container.render(&actual_frame, actual_frame.area);

                    try std.testing.expectEqualSlices(
                        FrameCell,
                        expected_frame.buffer,
                        actual_frame.buffer,
                    );
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{
            .id = 0,
            .borders = Borders.all,
            .border_type = .plain,
            .content = &[_][]const u8{},
        },
        .{
            .id = 1,
            .borders = Borders.all,
            .border_type = .plain,
            .content = &[_][]const u8{
                "",
            },
        },
        .{
            .id = 2,
            .borders = comptime Borders.join(&.{.top}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "─",
            },
        },
        .{
            .id = 3,
            .borders = comptime Borders.join(&.{.top}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "──",
            },
        },
        .{
            .id = 4,
            .borders = comptime Borders.join(&.{.bottom}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "─",
            },
        },
        .{
            .id = 5,
            .borders = comptime Borders.join(&.{.bottom}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "──",
            },
        },
        .{
            .id = 6,
            .borders = comptime Borders.join(&.{ .top, .bottom }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "─",
            },
        },
        .{
            .id = 7,
            .borders = comptime Borders.join(&.{ .top, .bottom }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "──",
            },
        },
        .{
            .id = 8,
            .borders = comptime Borders.join(&.{.left}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
            },
        },
        .{
            .id = 9,
            .borders = comptime Borders.join(&.{.left}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
                "│",
            },
        },
        .{
            .id = 10,
            .borders = comptime Borders.join(&.{.right}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
            },
        },
        .{
            .id = 11,
            .borders = comptime Borders.join(&.{.right}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
                "│",
            },
        },
        .{
            .id = 12,
            .borders = comptime Borders.join(&.{ .left, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
            },
        },
        .{
            .id = 13,
            .borders = comptime Borders.join(&.{ .left, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│",
                "│",
            },
        },
        .{
            .id = 14,
            .borders = comptime Borders.join(&.{ .top, .left }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "┌",
            },
        },
        .{
            .id = 15,
            .borders = comptime Borders.join(&.{ .top, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "┐",
            },
        },
        .{
            .id = 16,
            .borders = comptime Borders.join(&.{ .bottom, .left }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "└",
            },
        },
        .{
            .id = 17,
            .borders = comptime Borders.join(&.{ .bottom, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "┘",
            },
        },
        .{
            .id = 18,
            .borders = Borders.all,
            .border_type = .plain,
            .content = &[_][]const u8{
                "┌┐",
                "└┘",
            },
        },
        .{
            .id = 19,
            .borders = comptime Borders.join(&.{.top}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "──",
                "  ",
            },
        },
        .{
            .id = 20,
            .borders = comptime Borders.join(&.{.bottom}),
            .border_type = .plain,
            .content = &[_][]const u8{
                "  ",
                "──",
            },
        },
        .{
            .id = 21,
            .borders = comptime Borders.join(&.{ .top, .bottom }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "──",
                "──",
            },
        },
        .{
            .id = 22,
            .borders = comptime Borders.join(&.{ .top, .left }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "┌─",
                "│ ",
            },
        },
        .{
            .id = 23,
            .borders = comptime Borders.join(&.{ .top, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "─┐",
                " │",
            },
        },
        .{
            .id = 24,
            .borders = comptime Borders.join(&.{ .bottom, .right }),
            .border_type = .plain,
            .content = &[_][]const u8{
                " │",
                "─┘",
            },
        },
        .{
            .id = 25,
            .borders = comptime Borders.join(&.{ .bottom, .left }),
            .border_type = .plain,
            .content = &[_][]const u8{
                "│ ",
                "└─",
            },
        },
        .{
            .id = 26,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .content = &[_][]const u8{
                "┌──┐",
                "│  │",
                "└──┘",
            },
        },
        .{
            .id = 27,
            .borders = comptime Borders.all,
            .border_type = .rounded,
            .content = &[_][]const u8{
                "╭──╮",
                "│  │",
                "╰──╯",
            },
        },
        .{
            .id = 28,
            .borders = comptime Borders.all,
            .border_type = .double,
            .content = &[_][]const u8{
                "╔══╗",
                "║  ║",
                "╚══╝",
            },
        },
        .{
            .id = 29,
            .borders = comptime Borders.all,
            .border_type = .thick,
            .content = &[_][]const u8{
                "┏━━┓",
                "┃  ┃",
                "┗━━┛",
            },
        },
        .{
            .id = 30,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌Title┐",
                "│     │",
                "└─────┘",
            },
        },
        .{
            .id = 31,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .center,
            .content = &[_][]const u8{
                "┌Title┐",
                "│     │",
                "└─────┘",
            },
        },
        .{
            .id = 32,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .end,
            .content = &[_][]const u8{
                "┌Title┐",
                "│     │",
                "└─────┘",
            },
        },
        .{
            .id = 33,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌──────┐",
                "│      │",
                "└──────┘",
            },
        },
        .{
            .id = 34,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .center,
            .content = &[_][]const u8{
                "┌──────┐",
                "│      │",
                "└──────┘",
            },
        },
        .{
            .id = 35,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .end,
            .content = &[_][]const u8{
                "┌──────┐",
                "│      │",
                "└──────┘",
            },
        },
        .{
            .id = 36,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌Titl...┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 37,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .center,
            .content = &[_][]const u8{
                "┌Titl...┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 38,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .end,
            .content = &[_][]const u8{
                "┌Titl...┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 39,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌Title──┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 40,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .center,
            .content = &[_][]const u8{
                "┌─Title─┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 41,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .end,
            .content = &[_][]const u8{
                "┌──Title┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 40,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "Title ö",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌Title ö┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 40,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "ä Title ö",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌ä Ti...┐",
                "│       │",
                "└───────┘",
            },
        },
        .{
            .id = 41,
            .borders = comptime Borders.all,
            .border_type = .plain,
            .title = "ä Title ö and some other text that doesn't fit",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "┌──────┐",
                "│      │",
                "└──────┘",
            },
        },
        .{
            .id = 42,
            .borders = comptime Borders.none,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .start,
            .content = &[_][]const u8{
                "Title    ",
                "         ",
                "         ",
            },
        },
        .{
            .id = 43,
            .borders = comptime Borders.none,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .center,
            .content = &[_][]const u8{
                "  Title  ",
                "         ",
                "         ",
            },
        },
        .{
            .id = 44,
            .borders = comptime Borders.none,
            .title = "Title",
            .title_style = .{},
            .title_alignment = .end,
            .content = &[_][]const u8{
                "    Title",
                "         ",
                "         ",
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "Container.inner() should return the area inside the container, taking into account its borders" {
    const TestCase = struct {
        const Self = @This();

        id: usize,
        borders: Borders,
        outer: Area,
        inner: Area,

        margin_top: u16 = 0,
        margin_bottom: u16 = 0,
        margin_left: u16 = 0,
        margin_right: u16 = 0,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    var container = Container{};
                    container.borders = self.borders;
                    container.margin_top = self.margin_top;
                    container.margin_bottom = self.margin_bottom;
                    container.margin_left = self.margin_left;
                    container.margin_right = self.margin_right;
                    try std.testing.expectEqualDeep(self.inner, container.inner(self.outer));
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{
            .id = 0,
            .borders = Borders.all,
            .outer = .{ .width = 2, .height = 2, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 1, .y = 1 } },
        },
        .{
            .id = 1,
            .borders = Borders.all,
            .outer = .{ .width = 0, .height = 0, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 1, .y = 1 } },
        },
        .{
            .id = 2,
            .borders = comptime Borders.join(&.{.top}),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 1, .height = 0, .origin = .{ .x = 0, .y = 1 } },
        },
        .{
            .id = 3,
            .borders = comptime Borders.join(&.{.bottom}),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 1, .height = 0, .origin = .{ .x = 0, .y = 0 } },
        },
        .{
            .id = 4,
            .borders = comptime Borders.join(&.{.left}),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 1, .origin = .{ .x = 1, .y = 0 } },
        },
        .{
            .id = 5,
            .borders = comptime Borders.join(&.{.right}),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 1, .origin = .{ .x = 0, .y = 0 } },
        },
        .{
            .id = 6,
            .borders = comptime Borders.join(&.{ .top, .left }),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 1, .y = 1 } },
        },
        .{
            .id = 7,
            .borders = comptime Borders.join(&.{ .right, .bottom }),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 0, .y = 0 } },
        },
        .{
            .id = 8,
            .borders = comptime Borders.join(&.{ .top, .right, .bottom }),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 0, .y = 1 } },
        },
        .{
            .id = 9,
            .borders = comptime Borders.join(&.{ .left, .right, .bottom }),
            .outer = .{ .width = 1, .height = 1, .origin = .{ .x = 0, .y = 0 } },
            .inner = .{ .width = 0, .height = 0, .origin = .{ .x = 1, .y = 0 } },
        },
        .{
            .id = 10,
            .borders = Borders.all,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 3, .height = 7, .origin = .{ .x = 2, .y = 6 } },
        },
        .{
            .id = 11,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
        },
        .{
            .id = 12,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 5, .height = 8, .origin = .{ .x = 1, .y = 6 } },
            .margin_top = 1,
        },
        .{
            .id = 13,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 5, .height = 8, .origin = .{ .x = 1, .y = 5 } },
            .margin_bottom = 1,
        },
        .{
            .id = 14,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 4, .height = 9, .origin = .{ .x = 2, .y = 5 } },
            .margin_left = 1,
        },
        .{
            .id = 15,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 4, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .margin_right = 1,
        },
        .{
            .id = 16,
            .borders = Borders.none,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 3, .height = 7, .origin = .{ .x = 2, .y = 6 } },
            .margin_top = 1,
            .margin_bottom = 1,
            .margin_left = 1,
            .margin_right = 1,
        },
        .{
            .id = 17,
            .borders = Borders.all,
            .outer = .{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } },
            .inner = .{ .width = 1, .height = 5, .origin = .{ .x = 3, .y = 7 } },
            .margin_top = 1,
            .margin_bottom = 1,
            .margin_left = 1,
            .margin_right = 1,
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}
