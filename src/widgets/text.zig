const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Area = fuizon.area.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Container = fuizon.widgets.container.Container;
const Borders = fuizon.widgets.container.Borders;

const Style = fuizon.style.Style;
const Alignment = fuizon.style.Alignment;

pub const Character = struct {
    code: u21,
    style: Style = .{},
};

/// Specifies how to wrap a line if it exceeds the content width.
pub const Wrap = enum {
    /// Instructs the wrapper implementation to wrap lines on a per-character basis.
    ///
    /// For instance, the line 'abcabcabc' with a content width of 5 would wrap to
    /// 'abcab\ncabc'.
    character,
};

pub const Line = struct {
    character_list: std.ArrayList(Character),
    alignment: Alignment = .start,

    /// Specifies how to wrap a line if it exceeds the content width.
    ///
    /// At the moment, the wrapper implementation disregards this setting and
    /// wraps all lines on a per-character basis.
    wrap: Wrap = .character,

    frame: Frame,
    content_width: u16,

    //

    /// Inserts a character into the line at the specified position.
    pub fn insert(self: *Line, index: usize, character: Character) std.mem.Allocator.Error!void {
        try self.character_list.insert(index, character);
        try self.rewrap();
    }

    /// Appends a character to the line.
    pub fn append(self: *Line, character: Character) std.mem.Allocator.Error!void {
        return self.insert(self.character_list.items.len, character);
    }

    /// Prepends a character to the line.
    pub fn prepend(self: *Line, character: Character) std.mem.Allocator.Error!void {
        return self.insert(0, character);
    }

    //

    /// Removes a character from the line from the specified position.
    pub fn remove(self: *Line, index: usize) std.mem.Allocator.Error!void {
        _ = self.character_list.orderedRemove(index);
        try self.rewrap();
    }

    /// Removes the first character in the line.
    pub fn removeFirst(self: *Line) std.mem.Allocator.Error!void {
        if (self.character_list.items.len == 0)
            return;
        return self.remove(0);
    }

    /// Removes the last character in the line.
    pub fn removeLast(self: *Line) std.mem.Allocator.Error!void {
        if (self.character_list.items.len == 0)
            return;
        return self.remove(self.length() - 1);
    }

    //

    /// Returns the length of the line.
    pub fn length(self: Line) usize {
        return self.character_list.items.len;
    }

    //

    fn init(allocator: std.mem.Allocator) Line {
        return .{
            .character_list = std.ArrayList(Character).init(allocator),
            .frame = Frame.init(allocator),
            .content_width = 0,
        };
    }

    fn deinit(self: Line) void {
        self.character_list.deinit();
        self.frame.deinit();
    }

    // TODO: add the offset parameter to avoid
    //       rewrapping the entire line when it is not necessary.
    fn rewrap(self: *Line) std.mem.Allocator.Error!void {
        if (self.content_width == 0) {
            try self.frame.resize(0, 0);
            return;
        }

        var line_width: u16 = 0;
        for (self.character_list.items) |_| {
            // TODO: count character width. For now, we'll assume all
            //       characters can fit in a single frame cell.
            line_width += 1;
        }

        if (line_width % self.content_width != 0) {
            try self.frame.resize(self.content_width, (line_width / self.content_width) + 1);
        } else {
            try self.frame.resize(self.content_width, line_width / self.content_width);
        }

        self.frame.fill(self.frame.area, FrameCell.empty);

        var it: usize = 0;
        for (self.character_list.items) |character| {
            if (it % self.content_width == 0) {
                it += switch (self.alignment) {
                    // zig fmt: off
                    .start  => 0,
                    .center => (self.content_width -| (line_width - it)) / 2,
                    .end    => (self.content_width -| (line_width - it)),
                    // zig fmt: on
                };
            }

            // TODO: set the actual character width instead of 1.
            self.frame.buffer[it].width = 1;
            self.frame.buffer[it].content = character.code;
            self.frame.buffer[it].style = character.style;

            it += self.frame.buffer[it].width;
        }
    }
};

pub const LineParameters = struct {
    alignment: Alignment = .start,
    style: Style = .{},
    wrap: Wrap = .character,
};

pub const Text = struct {
    allocator: std.mem.Allocator,
    container: Container = .{},
    line_list: std.ArrayList(Line),
    content_width: u16,

    /// Initializes a new Text instance with the given allocator.
    pub fn init(allocator: std.mem.Allocator) Text {
        var text: Text = undefined;
        text.allocator = allocator;
        text.container = Container{};
        text.line_list = std.ArrayList(Line).init(allocator);
        text.content_width = 0;
        return text;
    }

    /// Deinitializes the Text instance.
    pub fn deinit(self: Text) void {
        for (self.line_list.items) |line|
            line.deinit();
        self.line_list.deinit();
    }

    //

    /// Insert a new line into the block of text at the specified line number.
    pub fn insert(
        self: *Text,
        index: usize,
        content: []const u8,
        params: LineParameters,
    ) std.mem.Allocator.Error!void {
        const line = try self.addOneAt(index);

        line.* = Line.init(self.allocator);
        errdefer line.deinit();
        line.alignment = params.alignment;
        line.wrap = params.wrap;
        line.content_width = self.content_width;

        var string_iterator = (std.unicode.Utf8View.init(content) catch unreachable).iterator();
        while (string_iterator.nextCodepoint()) |codepoint|
            try line.append(.{ .code = codepoint, .style = params.style });
    }

    /// Appends a new line to the block of text.
    pub fn append(
        self: *Text,
        content: []const u8,
        params: LineParameters,
    ) std.mem.Allocator.Error!void {
        return self.insert(self.line_list.items.len, content, params);
    }

    /// Prepends a new line to the block of text.
    pub fn prepend(
        self: *Text,
        content: []const u8,
        params: LineParameters,
    ) std.mem.Allocator.Error!void {
        return self.insert(0, content, params);
    }

    //

    /// Removes a line from the block of text at the specified position.
    pub fn remove(self: *Text, index: usize) void {
        self.line_list.items[index].deinit();
        _ = self.line_list.orderedRemove(index);
    }

    /// Removes the first line from the block of text.
    pub fn removeFirst(self: *Text) void {
        if (self.line_list.items.len == 0)
            return;
        self.remove(0);
    }

    /// Removes the last line from the block of text.
    pub fn removeLast(self: *Text) void {
        if (self.line_list.items.len == 0)
            return;
        self.remove(self.length() - 1);
    }

    //

    /// Returns the number of lines in the block of text.
    pub fn length(self: Text) usize {
        return self.line_list.items.len;
    }

    /// Calculates the total number of lines that the block of text would occupy
    /// within the previously specified content width.
    pub fn height(self: Text) usize {
        var h: usize = 0;
        for (self.line_list.items) |line| {
            h += line.frame.area.height;
        }
        return h;
    }

    //

    /// Sets the content width and rewraps the text.
    ///
    /// The provided content width may differ from the frame's area width.
    /// However, if the content width exceeds the frame width, some content may
    /// be lost during rendering.
    pub fn setContentWidth(self: *Text, content_width: u16) std.mem.Allocator.Error!void {
        self.content_width = content_width;
        for (self.line_list.items) |*line| {
            line.content_width = content_width;
            try line.rewrap();
        }
    }

    //

    /// Renders the block of text within the section of the specified frame,
    /// as defined by the provided area.
    ///
    /// The provided frame width may differ from the previously specified
    /// content width of the text. However, if the content width exceeds the
    /// frame width, some content may be lost during rendering.
    pub fn render(
        self: Text,
        frame: *Frame,
        area: Area,
    ) void {
        frame.fill(frame.area, .{ .width = 1, .content = ' ', .style = .{} });
        self.container.render(frame, area);
        const inner_area = self.container.inner(area);
        var render_y = inner_area.top();
        for (self.line_list.items) |line| {
            const f = &line.frame;
            for (f.area.top()..f.area.bottom()) |y| {
                if (render_y >= inner_area.bottom())
                    return;
                var render_x = switch (line.alignment) {
                    // zig fmt: off
                    .start  => inner_area.left(),
                    .center => inner_area.left() + (inner_area.width -| f.area.width) / 2,
                    .end    => inner_area.left() + (inner_area.width -| f.area.width),
                    // zig fmt: on
                };
                for (f.area.left()..f.area.right()) |x| {
                    if (render_x >= inner_area.right())
                        break;
                    frame.index(render_x, render_y).* = f.index(@intCast(x), @intCast(y)).*;
                    render_x += 1;
                }
                render_y += 1;
            }
        }
    }

    //

    fn addOneAt(self: *Text, index: usize) std.mem.Allocator.Error!*Line {
        try self.line_list.insert(index, undefined);
        errdefer _ = self.line_list.orderedRemove(index);
        return &self.line_list.items[index];
    }
};

//
// Tests
//

test "render()" {
    const TestCase = struct {
        const Self = @This();

        id: usize,

        content: []const []const u8,
        content_width: u16,
        content_wrap: Wrap = .character,
        content_alignment: Alignment,

        borders: Borders = Borders.none,

        // title: ?[]const u8 = null,
        // title_style: Style = undefined,
        // title_alignment: Alignment = undefined,

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
                    try text.setContentWidth(self.content_width);
                    text.container.borders = self.borders;

                    for (self.content) |line| try text.append(line, .{
                        .wrap = self.content_wrap,
                        .alignment = self.content_alignment,
                    });

                    text.render(&actual_frame, actual_frame.area);

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
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .start,
            .content_width = 15,
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
            .content_width = 15,
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
            .content_width = 15,
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
            .content_width = 11,
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
            .content_width = 11,
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
            .content_width = 11,
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
            .content_alignment = .start,
            .content_width = 16,
            .expected = &[_][]const u8{
                "hello world    ",
                "this is a multi",
                "line text      ",
            },
        },
        .{
            .id = 7,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .center,
            .content_width = 16,
            .expected = &[_][]const u8{
                "  hello world  ",
                "this is a multi",
                "   line text   ",
            },
        },
        .{
            .id = 8,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 16,
            .expected = &[_][]const u8{
                "     hello worl",
                "this is a multi",
                "       line tex",
            },
        },
        .{
            .id = 9,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 0,
            .expected = &[_][]const u8{},
        },
        .{
            .id = 10,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .content_alignment = .end,
            .content_width = 15,
            .expected = &[_][]const u8{
                "    hello world",
                "this is a multi",
            },
        },
        .{
            .id = 11,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a multi│",
                "│-line text     │",
                "└───────────────┘",
            },
        },
        .{
            .id = 12,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│this is a multi│",
                "│  -line text   │",
                "└───────────────┘",
            },
        },
        .{
            .id = 13,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 15,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│    hello world│",
                "│this is a multi│",
                "│     -line text│",
                "└───────────────┘",
            },
        },
        .{
            .id = 14,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .start,
            .content_width = 11,
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
            .content_width = 11,
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
            .content_width = 11,
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
            .content_alignment = .start,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│hello world    │",
                "│this is a multi│",
                "│line text      │",
                "└───────────────┘",
            },
        },
        .{
            .id = 18,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .center,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│  hello world  │",
                "│this is a multi│",
                "│   line text   │",
                "└───────────────┘",
            },
        },
        .{
            .id = 19,
            .content = &[_][]const u8{
                "hello world",
                "this is a multi-line text",
            },
            .borders = Borders.all,
            .content_alignment = .end,
            .content_width = 16,
            .expected = &[_][]const u8{
                "┌───────────────┐",
                "│     hello worl│",
                "│this is a multi│",
                "│       line tex│",
                "└───────────────┘",
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "render() with different text alignments" {
    const expected_frame = try Frame.initContent(std.testing.allocator, &[_][]const u8{
        "left alignment",
        "center alignme",
        "      nt      ",
        "right alignmen",
        "             t",
    }, .{});
    defer expected_frame.deinit();

    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
    defer actual_frame.deinit();

    var text = Text.init(std.testing.allocator);
    defer text.deinit();
    try text.setContentWidth(14);

    try text.append("left alignment", .{ .alignment = .start });
    try text.append("center alignment", .{ .alignment = .center });
    try text.append("right alignment", .{ .alignment = .end });

    text.render(&actual_frame, actual_frame.area);

    try std.testing.expectEqualSlices(
        FrameCell,
        expected_frame.buffer,
        actual_frame.buffer,
    );
}

test "(text) insert() + remove()" {
    const expected_frame = try Frame.initContent(std.testing.allocator, &[_][]const u8{
        "0",
        "1",
        "2",
        "3",
    }, .{});
    defer expected_frame.deinit();

    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
    defer actual_frame.deinit();

    var text = Text.init(std.testing.allocator);
    defer text.deinit();
    try text.setContentWidth(14);

    try text.append("1", .{});
    try text.prepend("0", .{});
    try text.append("3", .{});
    try text.insert(2, "2", .{});

    try text.prepend("-1", .{});
    try text.append("NaN", .{});
    try text.insert(1, "404", .{});

    text.remove(1);
    text.removeFirst();
    text.removeLast();

    text.render(&actual_frame, actual_frame.area);

    try std.testing.expectEqual(4, text.length());
    try std.testing.expectEqual(4, text.height());
    try std.testing.expectEqualSlices(
        FrameCell,
        expected_frame.buffer,
        actual_frame.buffer,
    );
}

test "(line) insert() + remove()" {
    const expected_frame = try Frame.initContent(std.testing.allocator, &[_][]const u8{
        "0123",
    }, .{});
    defer expected_frame.deinit();

    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
    defer actual_frame.deinit();

    var text = Text.init(std.testing.allocator);
    defer text.deinit();
    try text.setContentWidth(14);

    try text.append("", .{});

    const line = &text.line_list.items[0];

    try line.append(.{ .code = '1' });
    try line.prepend(.{ .code = '0' });
    try line.append(.{ .code = '3' });
    try line.insert(2, .{ .code = '2' });

    try line.prepend(.{ .code = 5 });
    try line.append(.{ .code = 9 });
    try line.insert(1, .{ .code = 15 });

    try line.remove(1);
    try line.removeFirst();
    try line.removeLast();

    text.render(&actual_frame, actual_frame.area);

    try std.testing.expectEqual(4, line.length());
    try std.testing.expectEqualSlices(
        FrameCell,
        expected_frame.buffer,
        actual_frame.buffer,
    );
}
