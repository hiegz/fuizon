const std = @import("std");
const Area = @import("area.zig").Area;
const Buffer = @import("buffer.zig").Buffer;
const Borders = @import("borders.zig").Borders;
const BorderType = @import("border_type.zig").BorderType;
const BorderSet = @import("border_set.zig").BorderSet;
const Character = @import("character.zig").Character;
const Dimensions = @import("dimensions.zig").Dimensions;
const Text = @import("text.zig").Text;
const TextAlignment = @import("text_alignment.zig").TextAlignment;
const Spacing = @import("spacing.zig").Spacing;
const Style = @import("style.zig").Style;
const Void = @import("void.zig").Void;
const Widget = @import("widget.zig").Widget;

pub const Container = struct {
    title: std.ArrayList(Character) = .empty,
    title_alignment: TextAlignment = .left,

    borders: Borders = .none,
    border_type: BorderType = .plain,
    border_style: Style = .{},

    // zig fmt: off

    margin_top:     Spacing = .Fixed(0),
    margin_bottom:  Spacing = .Fixed(0),
    margin_left:    Spacing = .Fixed(0),
    margin_right:   Spacing = .Fixed(0),

    padding_top:    Spacing = .auto,
    padding_bottom: Spacing = .auto,
    padding_left:   Spacing = .auto,
    padding_right:  Spacing = .auto,

    // zig fmt: on

    child: Widget = Widget.impl(&Void),

    pub const empty: Container = .{};

    /// Only needed if container title was initialized or updated.
    pub fn deinit(self: *Container, gpa: std.mem.Allocator) void {
        self.title.deinit(gpa);
    }

    pub fn setTitle(
        self: *Container,
        gpa: std.mem.Allocator,
        title: []const u8,
        style: Style,
    ) error{OutOfMemory}!void {
        self.title.clearRetainingCapacity();
        var iterator = (std.unicode.Utf8View.init(title) catch @panic("Invalid UTF-8")).iterator();
        while (iterator.nextCodepoint()) |codepoint|
            try self.title.append(gpa, Character.init(codepoint, style));
    }

    pub fn getTitleLength(self: Container) u16 {
        return @intCast(self.title.items.len);
    }

    // zig fmt: off

    fn calculateContainerX(self: Container, outer_x: u16) u16 {
        return outer_x
            +| (self.margin_left.min());
    }

    fn calculateContainerY(self: Container, outer_y: u16) u16 {
        return outer_y
            +| (self.margin_top.min());
    }

    fn calculateContainerWidth(self: Container, outer_width: u16) u16 {
        return outer_width
            -| (self.margin_left.min())
            -| (self.margin_right.min());
    }

    fn calculateContainerHeight(self: Container, outer_height: u16) u16 {
        return outer_height
            -| (self.margin_top.min())
            -| (self.margin_bottom.min());
    }

    fn calculateContainerArea(self: Container, outer_area: Area) Area {
        return Area.init(
            self.calculateContainerWidth(outer_area.width),
            self.calculateContainerHeight(outer_area.height),
            self.calculateContainerX(outer_area.x),
            self.calculateContainerY(outer_area.y),
        );
    }

    fn calculateMaxInnerX(self: Container, outer_x: u16) u16 {
        return outer_x
            +| self.margin_left.min()
            +| self.padding_left.min()
            +| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMaxInnerY(self: Container, outer_y: u16) u16 {
        return outer_y
            +| self.margin_top.min()
            +| self.padding_top.min()
            +| (if (self.borders.contain(&.{.top}))  @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMaxInnerWidth(self: Container, outer_width: u16) u16 {
        return outer_width
            -| (self.margin_left.min())
            -| (self.padding_left.min())
            -| (self.margin_right.min())
            -| (self.padding_right.min())
            -| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMaxInnerHeight(self: Container, outer_height: u16) u16 {
        return outer_height
            -| (self.margin_top.min())
            -| (self.padding_top.min())
            -| (self.margin_bottom.min())
            -| (self.padding_bottom.min())
            -| (if (self.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            -| (if (self.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMaxInnerDimensions(self: Container, outer_dimensions: Dimensions) Dimensions {
        return Dimensions.init(
            self.calculateMaxInnerWidth(outer_dimensions.width),
            self.calculateMaxInnerHeight(outer_dimensions.height),
        );
    }

    fn calculateMaxInnerArea(self: Container, outer_area: Area) Area {
        return Area.init(
            self.calculateMaxInnerWidth(outer_area.width),
            self.calculateMaxInnerHeight(outer_area.height),
            self.calculateMaxInnerX(outer_area.x),
            self.calculateMaxInnerY(outer_area.y),
        );
    }

    fn calculateMinOuterWidth(self: Container, inner_width: u16) u16 {
        return inner_width
            +| (self.margin_left.min())
            +| (self.padding_left.min())
            +| (self.margin_right.min())
            +| (self.padding_right.min())
            +| (if (self.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            +| (if (self.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMinOuterHeight(self: Container, inner_height: u16) u16 {
        return inner_height
            +| (self.margin_top.min())
            +| (self.padding_top.min())
            +| (self.margin_bottom.min())
            +| (self.padding_bottom.min())
            +| (if (self.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            +| (if (self.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
    }

    fn calculateMinOuterDimensions(self: Container, inner_dimensions: Dimensions) Dimensions {
        return Dimensions.init(
            self.calculateMinOuterWidth(inner_dimensions.width),
            self.calculateMinOuterHeight(inner_dimensions.height),
        );
    }

    pub fn measure(self: Container, opts: Widget.MeasureOptions) anyerror!Dimensions {
        const child_dimensions = try self.measureChildDimensions (Dimensions.init(opts.max_width, opts.max_height));
        const optimal_width    =     self.calculateMinOuterWidth (child_dimensions.width);
        const optimal_height   =     self.calculateMinOuterHeight(child_dimensions.height);

        return Dimensions.init(
            @min(opts.max_width,  optimal_width),
            @min(opts.max_height, optimal_height),
        );
    }

    fn measureChildDimensions(self: Container, max_outer_dimensions: Dimensions) anyerror!Dimensions {
        const max_inner_dimensions =
            self.calculateMaxInnerDimensions(max_outer_dimensions);

        return try self.child.measure(.{
            .max_width  = max_inner_dimensions.width,
            .max_height = max_inner_dimensions.height,
        });
    }

    fn applyAreaSpacing(
        max:    Area,
        min:    Dimensions,
        top:    Spacing,
        bottom: Spacing,
        left:   Spacing,
        right:  Spacing,
    ) Area {
        var area: Area = undefined;

        // No auto-spacing

        if (left != .auto and right  != .auto) {
            area.width  = max.width;
            area.x      = max.x;
        }

        if (top  != .auto and bottom != .auto) {
            area.height = max.height;
            area.y      = max.y;
        }

        // Top-aligned

        if (top  != .auto and bottom == .auto) {
            area.height = min.height;
            area.y      = max.y;
        }

        // Bottom-aligned

        if (top  == .auto and bottom != .auto) {
            area.height = min.height;
            area.y      = max.y + (max.height -| min.height);
        }

        // Centered

        if (left == .auto and right  == .auto) {
            area.width  = min.width;
            area.x      = max.x + (max.width -| min.width) / 2;
        }

        if (top == .auto and bottom  == .auto) {
            area.height = min.height;
            area.y      = max.y + (max.height -| min.height) / 2;
        }

        // Left-aligned

        if (left != .auto and right  == .auto) {
            area.width  = min.width;
            area.x      = max.x;
        }

        // Right-aligned

        if (left == .auto and right  != .auto) {
            area.width  = min.width;
            area.x      = max.x + (max.width -| min.width);
        }

        return area;
    }

    pub fn render(
        self: Container,
        buffer: *Buffer,
        max_area: Area,
    ) anyerror!void {
        if (max_area.width == 0 or max_area.height == 0)
            return;

        const max_dimensions       = Dimensions.init(max_area.width, max_area.height);
        const min_child_dimensions = try self.measureChildDimensions(max_dimensions);
        const min_outer_dimensions =     self.calculateMinOuterDimensions(min_child_dimensions);

        const outer_area =
            Container.applyAreaSpacing(
                max_area,
                min_outer_dimensions,
                self.margin_top,
                self.margin_bottom,
                self.margin_left,
                self.margin_right,
            );

        const container_area = self.calculateContainerArea(outer_area);
        const max_inner_area = self.calculateMaxInnerArea(outer_area);

        const child_area =
            Container.applyAreaSpacing(
                max_inner_area,
                min_child_dimensions,
                self.padding_top,
                self.padding_bottom,
                self.padding_left,
                self.padding_right,
            );

        self.renderBorders(buffer, container_area);
        self.renderTitle(buffer, container_area);

        try self.child.render(buffer, child_area);
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
        const missing   = self.getTitleLength() -| available;

        // The displayable string fraction is irrelevant and can be omitted at this point.
        if (missing > 0 and self.getTitleLength() - missing < 7)
            return;

        var todo = self.getTitleLength();
        if (missing > 0)
            todo = available - ndots;

        var x = switch (self.title_alignment) {
            .left   => left,
            .center => left + (available -| self.getTitleLength()) / 2,
            .right  => left + (available -| self.getTitleLength()),
        };

        for (self.title.items[0..todo]) |character| {
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
        expected:        []const []const u8,

        margin_top:      Spacing = .Fixed(0),
        margin_bottom:   Spacing = .Fixed(0),
        margin_left:     Spacing = .Fixed(0),
        margin_right:    Spacing = .Fixed(0),

        padding_top:     Spacing = .auto,
        padding_bottom:  Spacing = .auto,
        padding_left:    Spacing = .auto,
        padding_right:   Spacing = .auto,


        pub fn test_fn(self: Self, id: usize) type {
            return struct {
                test {
                    const gpa = std.testing.allocator;

                    const expected = try Buffer.initContent(gpa, self.expected, .{});
                    defer expected.deinit(gpa);

                    var text: Text = try .styled(gpa, self.text, .{});
                    defer text.deinit();
                    text.alignment = .center;
                    text.wrap = true;

                    var container: Container = .empty;
                    defer container.deinit(gpa);
                    try container.setTitle(gpa, self.title, .{});
                    container.title_alignment = self.title_alignment;
                    container.borders = self.borders;
                    container.border_type = self.border_type;
                    container.margin_top = self.margin_top;
                    container.margin_bottom = self.margin_bottom;
                    container.margin_left = self.margin_left;
                    container.margin_right = self.margin_right;
                    container.padding_top = self.padding_top;
                    container.padding_bottom = self.padding_bottom;
                    container.padding_left = self.padding_left;
                    container.padding_right = self.padding_right;
                    container.child = text.widget();

                    const dimensions = try container.measure(.opts(expected.width(), expected.height()));
                    var actual = try Buffer.initDimensions(gpa, dimensions);
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
            .expected        = &[_][]const u8{},
        },


        // Test Case #2
        .{
            .text            = " ",
            .title           = "",
            .title_alignment = .left,
            .borders         = comptime Borders.join(&.{.top}),
            .border_type     = .plain,
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
            .padding_left    = comptime .Fixed(1),
            .padding_right   = comptime .Fixed(1),
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
            .margin_left     = comptime .Fixed(1),
            .margin_right    = comptime .Fixed(1),
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
            .margin_top      = comptime .Fixed(1),
            .margin_bottom   = comptime .Fixed(1),
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
            .margin_top      = comptime .Fixed(1),
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
            .margin_bottom   = comptime .Fixed(1),
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
            .margin_top      = comptime .Fixed(1),
            .margin_bottom   = comptime .Fixed(1),
            .margin_left     = comptime .Fixed(1),
            .margin_right    = comptime .Fixed(1),
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
            .padding_top     = comptime .Fixed(1),
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
            .padding_bottom  = comptime .Fixed(1),
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
            .padding_left    = comptime .Fixed(1),
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
            .padding_right   = comptime .Fixed(1),
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
            .padding_top     = comptime .Fixed(1),
            .padding_bottom  = comptime .Fixed(1),
            .padding_left    = comptime .Fixed(1),
            .padding_right   = comptime .Fixed(1),
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
            .margin_top      = comptime .Fixed(1),
            .margin_bottom   = comptime .Fixed(1),
            .margin_left     = comptime .Fixed(1),
            .margin_right    = comptime .Fixed(1),
            .padding_top     = comptime .Fixed(1),
            .padding_bottom  = comptime .Fixed(1),
            .padding_left    = comptime .Fixed(1),
            .padding_right   = comptime .Fixed(1),
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
