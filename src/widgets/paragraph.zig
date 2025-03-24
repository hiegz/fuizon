const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Container = fuizon.widgets.container.Container;
const Borders = fuizon.widgets.container.Borders;

const Style = fuizon.style.Style;
const Alignment = fuizon.style.Alignment;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Span = fuizon.text.Span;
const Line = fuizon.text.Line;
const Text = fuizon.text.Text;

const FatLine = struct {
    alignment: fuizon.style.Alignment = .start,
    cell_list: std.ArrayList(fuizon.frame.FrameCell),

    fn length(self: FatLine) u16 {
        var ret: u16 = 0;
        for (self.cell_list.items) |cell|
            ret += cell.width;
        return ret;
    }
};

fn wrap(
    allocator: std.mem.Allocator,
    text: Text,
    width: u16,
) std.mem.Allocator.Error![]FatLine {
    var line_list = std.ArrayList(FatLine).init(allocator);
    errdefer line_list.deinit();
    errdefer for (line_list.items) |fat_line|
        fat_line.cell_list.deinit();

    if (width == 0)
        return try line_list.toOwnedSlice();

    var line_length = @as(u16, 0);
    var char_list = std.ArrayList(FrameCell).init(allocator);
    defer char_list.deinit();

    for (text.line_list.items) |line| {
        var it = line.iterator();
        while (it.next()) |cell| {
            if (cell.width > width) continue;
            if (line_length + cell.width > width) {
                var fat_line: FatLine = undefined;
                fat_line.alignment = line.alignment;
                fat_line.cell_list = char_list;
                try line_list.append(fat_line);
                char_list = std.ArrayList(FrameCell).init(allocator);
                line_length = 0;
            }
            try char_list.append(cell);
            line_length += cell.width;
        }
        var fat_line: FatLine = undefined;
        fat_line.alignment = line.alignment;
        fat_line.cell_list = char_list;
        try line_list.append(fat_line);
        char_list = std.ArrayList(FrameCell).init(allocator);
        line_length = 0;
    }

    return try line_list.toOwnedSlice();
}

pub const Paragraph = struct {
    container: Container = .{},

    /// Calculates the optimal width required to display the given text without
    /// line wrapping.
    pub fn optimalWidth(self: Paragraph, text: Text) u16 {
        var max_line_length: u16 = 0;
        for (text.lines()) |line| {
            const length = @as(u16, @intCast(line.length()));
            if (length > max_line_length)
                max_line_length = length;
        }
        return self.widthForContent(max_line_length);
    }

    /// Calculates the height of the paragraph when rendered with an optimal
    /// width and no line wrapping.
    pub fn optimalHeight(self: Paragraph, text: Text) u16 {
        return self.heightForContent(@intCast(text.lines().len));
    }

    /// Calculates the width of the paragraph given its content width.
    pub fn widthForContent(self: Paragraph, content_width: u16) u16 {
        // zig fmt: off
        return content_width
            + self.container.margin_left + self.container.margin_right
            + (if (self.container.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Calculates the height of the paragraph given its content height.
    pub fn heightForContent(self: Paragraph, content_height: u16) u16 {
        // zig fmt: off
        return content_height
            + self.container.margin_top + self.container.margin_bottom
            + (if (self.container.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    /// Calculates the height of the paragraph when rendered with the given
    /// width.
    pub fn heightForWidth(
        self: Paragraph,
        allocator: std.mem.Allocator,
        text: Text,
        width: u16,
    ) std.mem.Allocator.Error!u16 {
        const lines = try wrap(allocator, text, self.container.innerWidth(width));
        defer allocator.free(lines);
        defer for (lines) |line|
            line.cell_list.deinit();
        return self.heightForContent(@intCast(lines.len));
    }

    /// Renders the block of text to the frame within the given area.
    pub fn render(
        self: Paragraph,
        allocator: std.mem.Allocator,
        text: Text,
        frame: *Frame,
        area: Area,
    ) std.mem.Allocator.Error!void {
        self.container.render(frame, area);
        const inner_area = self.container.inner(area);
        const lines = try wrap(allocator, text, inner_area.width);
        defer allocator.free(lines);
        defer for (lines) |line|
            line.cell_list.deinit();
        var y = inner_area.top();
        for (lines) |line| {
            if (y >= inner_area.bottom())
                break;
            const line_length = line.length();
            const left = inner_area.left() + switch (line.alignment) {
                // zig fmt: off
                .start  => 0,
                .center => (inner_area.width -| line_length) / 2,
                .end    => (inner_area.width -| line_length),
                // zig fmt: on
            };
            for (left..left + line_length) |x|
                frame.index(@intCast(x), @intCast(y)).* = line.cell_list.items[x - left];
            y += 1;
        }
    }
};

//
// Tests
//

test "optimalWidth()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var paragraph = @as(Paragraph, undefined);
            paragraph.container.margin_left = 2;
            paragraph.container.margin_right = 2;
            paragraph.container.borders = Borders.join(&.{ .left, .right });

            var text = Text.init(allocator);
            defer text.deinit();

            try text.addLine();
            try text.lines()[0].appendSpan("cöntent", .{});
            try text.addLine();
            try text.lines()[1].appendSpan("more cöntent", .{});
            try text.addLine();
            try text.lines()[2].appendSpan("", .{});

            try std.testing.expectEqual(18, paragraph.optimalWidth(text));
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "optimalHeight()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var paragraph = @as(Paragraph, undefined);
            paragraph.container.margin_top = 2;
            paragraph.container.margin_bottom = 2;
            paragraph.container.borders = Borders.join(&.{ .top, .bottom });

            var text = Text.init(allocator);
            defer text.deinit();

            try text.addLine();
            try text.lines()[0].appendSpan("cöntent", .{});
            try text.addLine();
            try text.lines()[1].appendSpan("more cöntent", .{});
            try text.addLine();
            try text.lines()[2].appendSpan("", .{});

            try std.testing.expectEqual(9, paragraph.optimalHeight(text));
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "render()" {
    const TestCase = struct {
        const Self = @This();

        id: usize,

        content: []const []const u8,
        content_alignment: Alignment,

        borders: Borders = Borders.none,
        margin_top: u16 = 0,
        margin_bottom: u16 = 0,
        margin_left: u16 = 0,
        margin_right: u16 = 0,

        expected: []const []const u8,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    const expected_frame = try Frame.initContent(std.testing.allocator, self.expected, .{});
                    defer expected_frame.deinit();

                    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
                    defer actual_frame.deinit();

                    var text = Text.init(std.testing.allocator);
                    defer text.deinit();
                    for (self.content) |line| {
                        try text.addLine();
                        try text.lines()[text.lines().len - 1].appendSpan(line, .{});
                        text.lines()[text.lines().len - 1].alignment = self.content_alignment;
                    }

                    var paragraph = Paragraph{};
                    paragraph.container.borders = self.borders;
                    paragraph.container.margin_top = self.margin_top;
                    paragraph.container.margin_bottom = self.margin_bottom;
                    paragraph.container.margin_left = self.margin_left;
                    paragraph.container.margin_right = self.margin_right;

                    try paragraph.render(
                        std.testing.allocator,
                        text,
                        &actual_frame,
                        actual_frame.area,
                    );

                    // std.debug.print("hello?", .{});
                    // for (actual_frame.buffer, 0..) |cell, i| {
                    //     if (i % actual_frame.area.width == 0)
                    //         std.debug.print("\n", .{});
                    //     if (cell.content == ' ') {
                    //         std.debug.print("_", .{});
                    //     } else {
                    //         std.debug.print("{u}", .{cell.content});
                    //     }
                    // }
                    // std.debug.print("\n", .{});

                    try std.testing.expectEqualSlices(FrameCell, expected_frame.buffer, actual_frame.buffer);
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{
            .id = 0,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
                "-line text     ",
            },
        },
        .{
            .id = 1,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
                "  -line text   ",
            },
        },
        .{
            .id = 2,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
                "     -line text",
            },
        },
        .{
            .id = 3,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .margin_right = 4,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a m    ",
                "ulti-line t    ",
            },
        },
        .{
            .id = 4,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .margin_left = 2,
            .margin_right = 2,
            .expected = &[_][]const u8{
                "  hello world  ",
                "  this is a m  ",
                "  ulti-line t  ",
            },
        },
        .{
            .id = 5,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .margin_left = 4,
            .expected = &[_][]const u8{
                "    hello world",
                "    this is a m",
                "    ulti-line t",
            },
        },
        .{
            .id = 6,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
            },
        },
        .{
            .id = 7,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a multi│",
                "│-line text     │",
                "└───────────────┘",
            },
        },
        .{
            .id = 8,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│this is a multi│",
                "│  -line text   │",
                "└───────────────┘",
            },
        },
        .{
            .id = 9,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│    hello world│",
                "│this is a multi│",
                "│     -line text│",
                "└───────────────┘",
            },
        },
        .{
            .id = 10,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .margin_right = 4,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a m    │",
                "│ulti-line t    │",
                "└───────────────┘",
            },
        },
        .{
            .id = 15,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .margin_left = 2,
            .margin_right = 2,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│  this is a m  │",
                "│  ulti-line t  │",
                "└───────────────┘",
            },
        },
        .{
            .id = 16,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .margin_left = 4,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│    hello world│",
                "│    this is a m│",
                "│    ulti-line t│",
                "└───────────────┘",
            },
        },
        .{
            .id = 17,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "┌┐",
                "└┘",
            },
        },
        .{
            .id = 18,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.none,
            .content_alignment = .end,
            .expected = &[_][]const u8{
                "",
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}
