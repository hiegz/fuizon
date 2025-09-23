const std = @import("std");
const Area = @import("area.zig").Area;
const Buffer = @import("buffer.zig").Buffer;
const Borders = @import("borders.zig").Borders;
const BorderType = @import("border_type.zig").BorderType;
const BorderSet = @import("border_set.zig").BorderSet;
const Character = @import("character.zig").Character;
const ContainerTitle = @import("container_title.zig").ContainerTitle;
const Dimensions = @import("dimensions.zig").Dimensions;
const Text = @import("text.zig").Text;
const TextAlignment = @import("text_alignment.zig").TextAlignment;
const Margin = @import("margin.zig").Margin;
const Padding = @import("padding.zig").Padding;
const Style = @import("style.zig").Style;
const Widget = @import("widget.zig").Widget;

pub const Container = struct {
    title: ContainerTitle = .empty,

    borders: Borders = .none,
    border_type: BorderType = .plain,
    border_style: Style = .{},

    margin: Margin = .none,
    padding: Padding = .none,

    child: ?Widget = null,

    pub const empty: Container = .{};

    /// Only needed if container title was initialized or updated.
    pub fn deinit(self: *Container, gpa: std.mem.Allocator) void {
        self.title.deinit(gpa);
    }

    // zig fmt: off

    fn calculateContainerX(self: Container, outer_x: u16) u16  {
        return outer_x + self.margin.left;
    }

    fn calculateContainerY(self: Container, outer_y: u16) u16 {
        return outer_y + self.margin.top;
    }

    fn calculateContainerWidth(self: Container, outer_width: u16) u16 {
        return outer_width - self.margin.left - self.margin.right;
    }

    fn calculateContainerHeight(self: Container, outer_height: u16) u16 {
        return outer_height - self.margin.top - self.margin.bottom;
    }

    fn calculateContainerArea(self: Container, outer_area: Area) Area {
        return Area.init(
            self.calculateContainerWidth(outer_area.width),
            self.calculateContainerHeight(outer_area.height),
            self.calculateContainerX(outer_area.x),
            self.calculateContainerY(outer_area.y),
        );
    }

    fn calculateInnerX(self: Container, outer_x: u16) u16 {
        return outer_x
            + self.margin.left + self.padding.left
            + (if (self.borders.contain(&.{.left})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateInnerY(self: Container, outer_y: u16) u16 {
        return outer_y
            + self.margin.top + self.padding.top
            + (if (self.borders.contain(&.{.top})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateInnerWidth(self: Container, outer_width: u16) u16 {
        return outer_width
            -| (self.margin.left  + self.margin.right)
            -| (self.padding.left + self.padding.right)
            -| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateInnerHeight(self: Container, outer_height: u16) u16 {
        return outer_height
            -| (self.margin.top  + self.margin.bottom)
            -| (self.padding.top + self.padding.bottom)
            -| (if (self.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateInnerArea(self: Container, outer_area: Area) Area {
        return Area.init(
            self.calculateInnerWidth(outer_area.width),
            self.calculateInnerHeight(outer_area.height),
            self.calculateInnerX(outer_area.x),
            self.calculateInnerY(outer_area.y),
        );

    }

    fn calculateOuterWidth(self: Container, inner_width: u16) u16 {
        return inner_width
            +| (self.margin.left  + self.margin.right)
            +| (self.padding.left + self.padding.right)
            +| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            +| (if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateOuterHeight(self: Container, inner_height: u16) u16 {
        return inner_height
            +| (self.margin.top  + self.margin.bottom)
            +| (self.padding.top + self.padding.bottom)
            +| (if (self.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            +| (if (self.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateOuterDimensions(self: Container, inner_dimensions: Dimensions) Dimensions {
        return Dimensions.init(
            self.calculateOuterWidth(inner_dimensions.width),
            self.calculateOuterHeight(inner_dimensions.height),
        );
    }

    pub fn measure(
        self: Container,
        opts: Widget.MeasureOptions,
    ) anyerror!Dimensions {
        const max_width  = self.calculateInnerWidth(opts.max_width);
        const max_height = self.calculateInnerHeight(opts.max_height);
        const inner      = if (self.child) |child| try child.measure(.opts(max_width, max_height)) else Dimensions.init(0, 0);
        var   outer      = self.calculateOuterDimensions(inner);

        outer.width  = @min(opts.max_width,  outer.width);
        outer.height = @min(opts.max_height, outer.height);

        return outer;
    }

    // zig fmt: off

    pub fn render(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        if (area.width == 0 or area.height == 0)
            return;

        const container_area = self.calculateContainerArea(area);

        self.renderBorders(buffer, container_area);
        self.renderTitle(buffer, container_area);

        if (self.child) |child| {
            try child.render(buffer, self.calculateInnerArea(area));
        }
    }

    fn renderTitle(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        // If the text overflows, we indicate truncation with dots.
        // The number of dots is defined by this constant.
        const ndots = 3;

        const left:  u16 = (area.left()      ) +  if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0);
        const right: u16 = (area.right() -| 1) -| if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0);

        if (left >= right)
            return;

        const available = right - left + 1;
        const missing   = self.title.length() -| available;

        // The displayable string fraction is irrelevant and can be omitted at this point.
        if (missing > 0 and self.title.length() - missing < 7)
            return;

        var todo = self.title.length();
        if (missing > 0)
            todo = available - ndots;

        var x = switch (self.title.alignment) {
            .left   => left,
            .center => left + (available -| self.title.length()) / 2,
            .right  => left + (available -| self.title.length()),
        };

        for (self.title.character_list.items[0..todo]) |character| {
            const index = buffer.indexOf(x, area.top());
            buffer.characters[index] = character;
            x += 1;
        }

        if (missing == 0)
            return;

        while (x <= right) : (x += 1) {
            const index = buffer.indexOf(x, area.top());
            buffer.characters[index] = Character.init('.', .{});
        }
    }

    fn renderBorders(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        self.renderTopBorder(buffer, area);
        self.renderBottomBorder(buffer, area);
        self.renderLeftBorder(buffer, area);
        self.renderRightBorder(buffer, area);

        self.renderTopLeftCorner(buffer, area);
        self.renderTopRightCorner(buffer, area);
        self.renderBottomLeftCorner(buffer, area);
        self.renderBottomRightCorner(buffer, area);
    }

    fn renderTopBorder(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.top}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).h;
        const character = Character.init(border, self.border_style);

        for (area.left()..area.right()) |x| {
            const index = buffer.indexOf(@intCast(x), area.top());
            buffer.characters[index] = character;
        }
    }

    fn renderBottomBorder(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.bottom}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).h;
        const character = Character.init(border, self.border_style);

        for (area.left()..area.right()) |x| {
            const index = buffer.indexOf(@intCast(x), area.bottom() - 1);
            buffer.characters[index] = character;
        }
    }

    fn renderLeftBorder(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.left}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).v;
        const character = Character.init(border, self.border_style);

        for (area.top()..area.bottom()) |y| {
            const index = buffer.indexOf(area.left(), @intCast(y));
            buffer.characters[index] = character;
        }
    }

    fn renderRightBorder(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.right}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).v;
        const character = Character.init(border, self.border_style);

        for (area.top()..area.bottom()) |y| {
            const index = buffer.indexOf(area.right() - 1, @intCast(y));
            buffer.characters[index] = character;
        }
    }

    fn renderTopLeftCorner(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.top, .left}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).tl;
        const character = Character.init(border, self.border_style);
        const index = buffer.indexOf(area.left(), area.top());

        buffer.characters[index] = character;
    }

    fn renderTopRightCorner(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.top, .right}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).tr;
        const character = Character.init(border, self.border_style);
        const index = buffer.indexOf(area.right() - 1, area.top());

        buffer.characters[index] = character;
    }

    fn renderBottomLeftCorner(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.bottom, .left}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).bl;
        const character = Character.init(border, self.border_style);
        const index = buffer.indexOf(area.left(), area.bottom() - 1);

        buffer.characters[index] = character;
    }

    fn renderBottomRightCorner(
        self: Container,
        buffer: *Buffer,
        area: Area,
    ) void {
        if (!self.borders.contain(&.{.bottom, .right}))
            return;

        const border = BorderSet.fromBorderType(self.border_type).br;
        const character = Character.init(border, self.border_style);
        const index = buffer.indexOf(area.right() - 1, area.bottom() - 1);

        buffer.characters[index] = character;
    }
};

// zig fmt: off

test "render()" {
    const TestCase = struct {
        const Self = @This();

        text:            []const u8,
        title:           []const u8,
        title_alignment: TextAlignment = .left,
        borders:         Borders = .none,
        border_type:     BorderType = .plain,
        margin:          Margin = .none,
        padding:         Padding = .none,
        expected:        []const []const u8,

        pub fn test_fn(self: Self, id: usize) type {
            return struct {
                test {
                    const gpa = std.testing.allocator;

                    const expected = try Buffer.initContent(gpa, self.expected, .{});
                    defer expected.deinit(gpa);

                    var text: Text = try .init(gpa, .{ .alignment = .center, .wrap = true });
                    defer text.deinit();
                    try text.write(self.text, .{});

                    var container: Container = .empty;
                    defer container.deinit(gpa);
                    try container.title.append(gpa, self.title, .{});
                    container.title.alignment = self.title_alignment;
                    container.borders = self.borders;
                    container.border_type = self.border_type;
                    container.margin = self.margin;
                    container.padding = self.padding;
                    container.child = text.widget();

                    const dimensions = try container.measure(.opts(expected.width(), expected.height()));
                    var actual = try Buffer.initDimensions(gpa, dimensions.width, dimensions.height);
                    defer actual.deinit(gpa);

                    try container.render(&actual, Area.init(actual.width(), actual.height(), 0, 0));

                    std.testing.expect(
                        expected.equals(actual),
                    ) catch |err| {
                        std.debug.print("\t\n", .{});
                        std.debug.print("test case #{d} failed\n", .{id});
                        std.debug.print("expected:\n{f}\n\n", .{expected});
                        std.debug.print("found:\n{f}\n", .{actual});
                        return err;
                    };
                }
            };
        }
    };

    inline for ([_]TestCase{
        // Test Case #0
        .{
            .text            = "",
            .title           = "",
            .title_alignment = .left,
            .borders         = Borders.all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{},
        },


        // Test Case #2
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.top}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "─",
                " ",
            },
        },

        // Test Case #3
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.bottom}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                " ",
                "─",
            },
        },

        // Test Case #4
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.top, .bottom}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "─",
                " ",
                "─",
            },
        },

        // Test Case #5
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.left}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "│ ",
            },
        },

        // Test Case #6
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.right}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                " │",
            },
        },

        // Test Case #7
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .none,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                " ",
            },
        },

        // Test Case #8
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.left, .top}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌"
            },
        },

        // Test Case #9
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.left, .top}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌──",
                "│  ",
            },
        },

        // Test Case #10
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.top, .right}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┐",
            },
        },

        // Test Case #11
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.top, .right}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "──┐",
                "  │",
            },
        },

        // Test Case #12
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.bottom, .left}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "└",
            },
        },

        // Test Case #13
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.bottom, .left}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "│  ",
                "└──",
            },
        },

        // Test Case #14
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.bottom, .right}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┘",
            },
        },

        // Test Case #15
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.bottom, .right}),
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "  │",
                "──┘",
            },
        },

        // Test Case #16
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌┐",
                "└┘",
            },
        },

        // Test Case #17
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌─┐",
                "└─┘",
            },
        },

        // Test Case #18
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌─┐",
                "│ │",
                "└─┘",
            },
        },

        // Test Case #19
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌──┐",
                "│  │",
                "└──┘",
            },
        },

        // Test Case #20
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .rounded,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "╭──╮",
                "│  │",
                "╰──╯",
            },
        },

        // Test Case #21
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .double,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "╔══╗",
                "║  ║",
                "╚══╝",
            },
        },

        // Test Case #22
        .{
            .text            = "  ",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .thick,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┏━━┓",
                "┃  ┃",
                "┗━━┛",
            },
        },

        // Test Case #23
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌─────────────────────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #24
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(0, 0, 1, 1),
            .expected        = &[_][]const u8{
                "┌───────────────────────┐",
                "│ Hello world. Here is  │",
                "│ some text for testing │",
                "│  the container widget │",
                "└───────────────────────┘",
            },
        },

        // Test Case #25
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(0, 0, 1, 1),
            .padding         = .none,
            .expected        = &[_][]const u8{
                " ┌─────────────────────┐ ",
                " │Hello world. Here is │ ",
                " │some text for testing│ ",
                " │ the container widget│ ",
                " └─────────────────────┘ ",
            },
        },

        // Test Case #26
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(1, 1, 0, 0),
            .padding         = .none,
            .expected        = &[_][]const u8{
                "                       ",
                "┌─────────────────────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
                "                       ",
            },
        },

        // Test Case #27
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(1, 0, 0, 0),
            .padding         = .none,
            .expected        = &[_][]const u8{
                "                       ",
                "┌─────────────────────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #28
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(0, 1, 0, 0),
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌─────────────────────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
                "                       ",
            },
        },

        // Test Case #29
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(1, 1, 1, 1),
            .padding         = .none,
            .expected        = &[_][]const u8{
                "                         ",
                " ┌─────────────────────┐ ",
                " │Hello world. Here is │ ",
                " │some text for testing│ ",
                " │ the container widget│ ",
                " └─────────────────────┘ ",
                "                         ",
            },
        },

        // Test Case #29
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(1, 0, 0, 0),
            .expected        = &[_][]const u8{
                "┌─────────────────────┐",
                "│                     │",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #30
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(0, 1, 0, 0),
            .expected        = &[_][]const u8{
                "┌─────────────────────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "│                     │",
                "└─────────────────────┘",
            },
        },

        // Test Case #31
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(0, 0, 1, 0),
            .expected        = &[_][]const u8{
                "┌──────────────────────┐",
                "│ Hello world. Here is │",
                "│ some text for testing│",
                "│  the container widget│",
                "└──────────────────────┘",
            },
        },

        // Test Case #32
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(0, 0, 0, 1),
            .expected        = &[_][]const u8{
                "┌──────────────────────┐",
                "│Hello world. Here is  │",
                "│some text for testing │",
                "│ the container widget │",
                "└──────────────────────┘",
            },
        },

        // Test Case #33
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = comptime .init(1, 1, 1, 1),
            .expected        = &[_][]const u8{
                "┌───────────────────────┐",
                "│                       │",
                "│ Hello world. Here is  │",
                "│ some text for testing │",
                "│  the container widget │",
                "│                       │",
                "└───────────────────────┘",
            },
        },

        // Test Case #34
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = comptime .init(1, 1, 1, 1),
            .padding         = comptime .init(1, 1, 1, 1),
            .expected        = &[_][]const u8{
                "                           ",
                " ┌───────────────────────┐ ",
                " │                       │ ",
                " │ Hello world. Here is  │ ",
                " │ some text for testing │ ",
                " │  the container widget │ ",
                " │                       │ ",
                " └───────────────────────┘ ",
                "                           ",
            },
        },

        // Test Case #35
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container Title──────┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #36
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .center,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌───Container Title───┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #37
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .right,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌──────Container Title┐",
                "│Hello world. Here is │",
                "│some text for testing│",
                "│ the container widget│",
                "└─────────────────────┘",
            },
        },

        // Test Case #37
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .right,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container Title┐",
                "│Hello world. He│",
                "│re is some text│",
                "│ for testing th│",
                "│e container wid│",
                "│      get      │",
                "└───────────────┘",
            },
        },

        // Test Case #38
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .center,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container Title┐",
                "│Hello world. He│",
                "│re is some text│",
                "│ for testing th│",
                "│e container wid│",
                "│      get      │",
                "└───────────────┘",
            },
        },

        // Test Case #39
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container T...┐",
                "│Hello world. H│",
                "│ere is some te│",
                "│xt for testing│",
                "│ the container│",
                "│    widget    │",
                "└──────────────┘",
            },
        },

        // Test Case #40
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .center,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container T...┐",
                "│Hello world. H│",
                "│ere is some te│",
                "│xt for testing│",
                "│ the container│",
                "│    widget    │",
                "└──────────────┘",
            },
        },

        // Test Case #41
        .{
            .text            = "Hello world. Here is some text for testing the container widget",
            .title           = "Container Title",
            .title_alignment = .right,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Container T...┐",
                "│Hello world. H│",
                "│ere is some te│",
                "│xt for testing│",
                "│ the container│",
                "│    widget    │",
                "└──────────────┘",
            },
        },

        // Test Case #42
        .{
            .text            = "Hello world",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Containe...┐",
                "│Hello world│",
                "└───────────┘",
            },
        },

        // Test Case #43
        .{
            .text            = "Hello world",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Contai...┐",
                "│Hello wor│",
                "└─────────┘",
            },
        },

        // Test Case #44
        .{
            .text            = "Hello world",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌Cont...┐",
                "│Hello w│",
                "└───────┘",
            },
        },

        // Test Case #45
        .{
            .text            = "Hello world",
            .title           = "Container Title",
            .title_alignment = .left,
            .borders         = .all,
            .border_type     = .plain,
            .margin          = .none,
            .padding         = .none,
            .expected        = &[_][]const u8{
                "┌──────┐",
                "│Hello │",
                "└──────┘",
            },
        },
    }, 0..) |test_case, id| {
        _ = test_case.test_fn(id);
    }
}
