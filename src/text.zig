const std = @import("std");
const Area = @import("area.zig").Area;
const Buffer = @import("buffer.zig").Buffer;
const Dimensions = @import("dimensions.zig").Dimensions;
const Character = @import("character.zig").Character;
const TextAlignment = @import("text_alignment.zig").TextAlignment;
const TextOpts = @import("text_opts.zig").TextOpts;
const Span = @import("span.zig").Span;
const Attributes = @import("attributes.zig").Attributes;
const Style = @import("style.zig").Style;
const Widget = @import("widget.zig").Widget;

pub const Text = struct {
    gpa: std.mem.Allocator,
    line_list: std.ArrayList(std.ArrayList(Character)),
    alignment: TextAlignment,
    wrap: bool,

    pub fn init(gpa: std.mem.Allocator, opts: TextOpts) error{OutOfMemory}!Text {
        return Text.rich(gpa, &.{}, opts);
    }

    pub fn raw(
        gpa: std.mem.Allocator,
        text: []const u8,
        opts: TextOpts,
    ) error{OutOfMemory}!Text {
        return Text.styled(gpa, text, .{}, opts);
    }

    pub fn styled(
        gpa: std.mem.Allocator,
        text: []const u8,
        style: Style,
        opts: TextOpts,
    ) error{OutOfMemory}!Text {
        return Text.rich(gpa, &.{.styled(text, style)}, opts);
    }

    pub fn rich(
        gpa: std.mem.Allocator,
        spans: []const Span,
        opts: TextOpts,
    ) error{OutOfMemory}!Text {
        var self: Text = undefined;
        self.gpa = gpa;
        self.line_list = .empty;
        self.alignment = opts.alignment;
        self.wrap = opts.wrap;
        try self.breakLine(); // init the first line
        for (spans) |span|
            try self.write(span.content, span.style);
        return self;
    }

    pub fn wrapped(
        gpa: std.mem.Allocator,
        other: Text,
        wrap_width: u16,
    ) error{OutOfMemory}!Text {
        var self: Text = try .init(gpa, .{ .alignment = other.alignment, .wrap = false });
        errdefer self.deinit();

        var x: u16 = undefined;
        for (other.line_list.items) |line| {
            x = 0;
            for (line.items) |character| {
                if (x == wrap_width) {
                    try self.breakLine();
                    x = 0;
                }
                try self.writeCharacter(character);
                x += 1;
            }
            try self.breakLine();
        }

        // remove the last line created by breakLine()
        _ = self.line_list.pop();

        return self;
    }

    pub fn deinit(self: *Text) void {
        for (self.line_list.items) |*line|
            line.deinit(self.gpa);
        self.line_list.deinit(self.gpa);
    }

    pub fn write(
        self: *Text,
        text: []const u8,
        style: Style,
    ) error{OutOfMemory}!void {
        var iterator = (std.unicode.Utf8View.init(text) catch @panic("Invalid UTF-8")).iterator();
        while (iterator.nextCodepoint()) |codepoint| {
            try self.writeCharacter(Character.init(codepoint, style));
        }
    }

    pub fn writeCharacter(
        self: *Text,
        character: Character,
    ) error{OutOfMemory}!void {
        switch (character.value) {
            // zig fmt: off
            '\n' => try self.breakLine(),
            '\t' => for (0..4) |_| try self.writeCharacter(Character.init(' ', character.style)),
            else => try self.line_list.items[self.line_list.items.len - 1].append(self.gpa, character),
            // zig fmt: on
        }
    }

    pub fn breakLine(self: *Text) error{OutOfMemory}!void {
        try self.line_list.append(self.gpa, .empty);
    }

    pub fn width(self: Text) u16 {
        var w: u16 = 0;
        for (self.line_list.items) |line| {
            w = @max(@as(u16, @intCast(line.items.len)), w);
        }
        return w;
    }

    pub fn height(self: Text) u16 {
        return @intCast(self.line_list.items.len);
    }

    pub fn measure(
        self: Text,
        opts: Widget.MeasureOptions,
    ) anyerror!Dimensions {
        var text = if (self.wrap) try Text.wrapped(self.gpa, self, opts.max_width) else self;
        defer if (self.wrap) text.deinit();

        return Dimensions{
            // zig fmt: off
            .width  = @min(opts.max_width,  text.width()),
            .height = @min(opts.max_height, text.height()),
            // zig fmt: on
        };
    }

    pub fn render(
        self: Text,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        var text = if (self.wrap) try Text.wrapped(self.gpa, self, area.width) else self;
        defer if (self.wrap) text.deinit();

        const alignX = struct {
            pub fn function(alignment: TextAlignment, offset: u16, container_width: u16, content_width: u16) u16 {
                return switch (alignment) {
                    // zig fmt: off
                    .left  => offset,
                    .center      => offset + (container_width - @min(container_width, content_width)) / 2,
                    .right => offset + (container_width - @min(container_width, content_width)),
                    // zig fmt: on
                };
            }
        }.function;

        var x: u16 = undefined;
        var y: u16 = area.top();

        for (text.line_list.items) |line| {
            if (y >= area.bottom())
                break;

            x = alignX(self.alignment, area.left(), area.width, @intCast(line.items.len));

            for (line.items) |character| {
                if (x >= area.right())
                    break;
                buffer.characters[buffer.indexOf(x, y)] = character;
                x += 1;
            }

            y += 1;
        }
    }

    pub fn widget(self: *const Text) Widget {
        return Widget.impl(self);
    }
};

test "render()" {
    const TestCase = struct {
        const Self = @This();

        wrap: bool,
        alignment: TextAlignment,

        content: []const []const u8,
        expected: []const []const u8,

        pub fn test_fn(self: Self, id: usize) type {
            return struct {
                test {
                    const gpa = std.testing.allocator;

                    const expected = try Buffer.initContent(gpa, self.expected, .{});
                    defer expected.deinit(gpa);

                    var text: Text = try .init(gpa, .{ .alignment = self.alignment, .wrap = self.wrap });
                    defer text.deinit();
                    for (self.content) |line| {
                        try text.write(line, .{});
                        try text.breakLine();
                    }
                    // remove the last line created by breakLine()
                    _ = text.line_list.pop();

                    const dimensions = try text.measure(.{ .max_width = expected.width() });
                    var actual = try Buffer.initDimensions(gpa, dimensions.width, dimensions.height);
                    defer actual.deinit(gpa);

                    try text.render(&actual, Area.init(actual.width(), actual.height(), 0, 0));

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
        // zig fmt: off

        // Test Case #0
        .{
            .wrap      = true,
            .alignment = .left,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
                "-line text     ",
            },
        },

        // Test Case #1
        .{
            .wrap      = true,
            .alignment = .center,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
                "  -line text   ",
            },
        },

        // Test Case #2
        .{
            .wrap      = true,
            .alignment = .right,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
                "     -line text",
            },
        },

        // Test Case #3
        .{
            .wrap      = false,
            .alignment = .left,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
            },
        },

        // Test Case #4
        .{
            .wrap      = false,
            .alignment = .center,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
            },
        },

        // Test Case #5
        .{
            .wrap      = false,
            .alignment = .right,

            .content  = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
            },
        },

        // zig fmt: on
    }, 0..) |test_case, id| {
        _ = test_case.test_fn(id);
    }
}
