const std = @import("std");
const fuizon = @import("fuizon.zig");

const Container = fuizon.widgets.container.Container;
const Borders = fuizon.widgets.container.Borders;

const Style = fuizon.style.Style;
const Alignment = fuizon.style.Alignment;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

pub const Span = struct {
    allocator: std.mem.Allocator,
    content: []const u8,
    style: Style = .{},

    /// Initializes an empty span.
    pub fn init(allocator: std.mem.Allocator) Span {
        return .{
            .allocator = allocator,
            .content = "",
            .style = .{},
        };
    }

    /// Deinitializes the span.
    pub fn deinit(self: Span) void {
        self.allocator.free(self.content);
    }

    /// Updates span content.
    pub fn setContent(
        self: *Span,
        content: []const u8,
    ) std.mem.Allocator.Error!void {
        const new_content = try self.allocator.dupe(u8, content);
        errdefer comptime unreachable;

        self.allocator.free(self.content);
        self.content = new_content;
    }

    /// Returns the number of characters in the line.
    pub fn length(self: Span) u16 {
        var ret: u16 = 0;
        var it = (std.unicode.Utf8View.init(self.content) catch unreachable).iterator();
        while (it.nextCodepoint()) |_| : (ret += 1) {}
        return ret;
    }

    /// Makes a copy of the span using the given allocator.
    pub fn clone(self: Span, allocator: std.mem.Allocator) std.mem.Allocator.Error!Span {
        var span = Span.init(allocator);
        errdefer span.deinit();
        try span.setContent(self.content);
        span.style = self.style;
        return span;
    }
};

pub const Line = struct {
    allocator: std.mem.Allocator,
    alignment: Alignment = .start,
    span_list: std.ArrayList(Span),

    /// Initializes an empty line with custom alignment.
    pub fn init(allocator: std.mem.Allocator, alignment: Alignment) Line {
        var line: Line = undefined;
        line.allocator = allocator;
        line.alignment = alignment;
        line.span_list = std.ArrayList(Span).init(allocator);
        return line;
    }

    /// Deinitializes the line.
    pub fn deinit(self: Line) void {
        for (self.span_list.items) |span|
            span.deinit();
        self.span_list.deinit();
    }

    /// Return the spans in the line.
    pub fn spans(self: Line) []Span {
        return self.span_list.items;
    }

    /// Inserts a span at the specified position.
    pub fn insertSpan(self: *Line, index: usize, content: []const u8, style: Style) std.mem.Allocator.Error!void {
        var span = Span.init(self.allocator);
        errdefer span.deinit();
        try span.setContent(content);
        span.style = style;
        try self.span_list.insert(index, span);
    }

    /// Inserts a span after the last span in the list.
    pub fn appendSpan(self: *Line, content: []const u8, style: Style) std.mem.Allocator.Error!void {
        try self.insertSpan(self.span_list.items.len, content, style);
    }

    /// Removes the span at the specified position.
    pub fn removeSpan(self: *Line, index: usize) void {
        self.span_list.orderedRemove(index).deinit();
    }

    /// Removes the last span.
    pub fn removeLastSpan(self: *Line) void {
        self.removeSpan(self.span_list.items.len - 1);
    }

    /// Removes all spans from the line.
    pub fn clear(self: *Line) void {
        for (self.span_list.items) |span|
            span.deinit();
        self.span_list.clearAndFree();
    }

    /// Returns the number of characters in the line.
    pub fn length(self: Line) usize {
        var ret: u16 = 0;
        for (self.span_list.items) |span|
            ret += span.length();
        return ret;
    }

    /// Makes a copy of the line using the same allocator.
    pub fn clone(self: Line, allocator: std.mem.Allocator) std.mem.Allocator.Error!Line {
        var line = Line.init(allocator, self.alignment);
        errdefer line.deinit();
        for (self.span_list.items) |span| {
            const copy = try span.clone(allocator);
            errdefer copy.deinit();
            try line.span_list.append(copy);
        }
        return line;
    }

    /// Initializes the line iterator.
    pub fn iterator(self: *const Line) LineIterator {
        var it: LineIterator = undefined;
        it.line = self;
        it.span_index = 0;

        // zig fmt: off
        const content: []const u8 =
            if (it.line.span_list.items.len > 0)
                it.line.span_list.items[0].content
            else
                "";
        // zig fmt: on

        it.char_iterator = (std.unicode.Utf8View.init(content) catch unreachable).iterator();

        return it;
    }
};

pub const LineIterator = struct {
    line: *const Line,
    span_index: usize,
    char_iterator: std.unicode.Utf8Iterator,

    pub fn next(self: *LineIterator) ?FrameCell {
        if (self.span_index == self.line.span_list.items.len)
            return null;
        while (true) {
            if (self.char_iterator.nextCodepoint()) |codepoint| {
                var cell: FrameCell = undefined;
                cell.width = 1;
                cell.content = codepoint;
                cell.style = self.line.span_list.items[self.span_index].style;
                return cell;
            }

            self.span_index += 1;
            if (self.span_index == self.line.span_list.items.len)
                return null;
            // zig fmt: off
            self.char_iterator =
                (std.unicode.Utf8View.init(
                    self.line.span_list.items[self.span_index].content,
                    ) catch unreachable).iterator();
            // zig fmt: on
        }
    }
};

pub const Text = struct {
    allocator: std.mem.Allocator,
    line_list: std.ArrayList(Line),

    /// Initializes an empty block of text.
    pub fn init(allocator: std.mem.Allocator) Text {
        var text: Text = undefined;
        text.allocator = allocator;
        text.line_list = std.ArrayList(Line).init(allocator);
        return text;
    }

    /// Deinitializes the block of text.
    pub fn deinit(self: Text) void {
        for (self.line_list.items) |line|
            line.deinit();
        self.line_list.deinit();
    }

    /// Returns the list of lines in the text.
    pub fn lines(self: Text) []Line {
        return self.line_list.items;
    }

    /// Inserts an empty line at the specified position.
    pub fn addLineAt(self: *Text, index: usize) std.mem.Allocator.Error!void {
        const line = Line.init(self.allocator, .start);
        errdefer line.deinit();
        try self.line_list.insert(index, line);
    }

    /// Inserts an empty line after the last line in the text.
    pub fn addLine(self: *Text) std.mem.Allocator.Error!void {
        try self.addLineAt(self.line_list.items.len);
    }

    /// Removes the line at the specified index from the text.
    pub fn removeLine(self: *Text, index: usize) void {
        self.line_list.orderedRemove(index).deinit();
    }

    /// Removes the last line from the text.
    pub fn removeLastLine(self: *Text) void {
        self.removeLine(self.line_list.items.len - 1);
    }

    /// Removes all lines from the text.
    pub fn clear(self: *Text) void {
        for (self.lines()) |line|
            line.deinit();
        self.line_list.clearAndFree();
    }

    /// Makes a copy of the text using the given allocator.
    pub fn clone(self: Text, allocator: std.mem.Allocator) std.mem.Allocator.Error!Text {
        var text = Text.init(allocator);
        errdefer text.deinit();
        for (self.line_list.items) |line| {
            const copy = try line.clone(allocator);
            errdefer copy.deinit();
            try text.line_list.append(copy);
        }
        return text;
    }
};

//
// Tests
//

test "Span.init()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            const span = Span.init(allocator);
            defer span.deinit();
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Span.setContent()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var span = Span.init(allocator);
            defer span.deinit();
            try span.setContent("content");
            try std.testing.expectEqualStrings("content", span.content);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Span.length()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var span = Span.init(allocator);
            defer span.deinit();
            try span.setContent("cöntent");
            span.style = .{ .foreground_color = .blue };

            try std.testing.expectEqual(7, span.length());
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Span.clone()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var span = Span.init(allocator);
            defer span.deinit();
            try span.setContent("content");
            span.style = .{ .foreground_color = .blue };

            const copy = try span.clone(allocator);
            defer copy.deinit();

            try std.testing.expectEqualDeep(span.style, copy.style);
            try std.testing.expectEqualStrings(span.content, copy.content);
            try std.testing.expect(span.content.ptr != copy.content.ptr);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.init() with left alignment" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) anyerror!void {
            const line = Line.init(allocator, .start);
            defer line.deinit();

            try std.testing.expectEqual(.start, line.alignment);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.init() with center alignment" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) anyerror!void {
            const line = Line.init(allocator, .center);
            defer line.deinit();

            try std.testing.expectEqual(.center, line.alignment);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.init() with right alignment" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) anyerror!void {
            var line = Line.init(allocator, .end);
            defer line.deinit();

            try std.testing.expectEqual(.end, line.alignment);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.appendSpan()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var line = Line.init(allocator, undefined);
            defer line.deinit();

            try line.appendSpan("content", .{ .foreground_color = .blue });

            try std.testing.expectEqual(1, line.span_list.items.len);
            try std.testing.expectEqualStrings("content", line.span_list.items[0].content);
            try std.testing.expectEqualDeep(Style{ .foreground_color = .blue }, line.span_list.items[0].style);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.removeLastSpan()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var line = Line.init(allocator, undefined);
            defer line.deinit();

            try line.appendSpan("content", .{ .foreground_color = .blue });
            line.removeLastSpan();

            try std.testing.expectEqual(0, line.span_list.items.len);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.clear()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var line = Line.init(allocator, undefined);
            defer line.deinit();

            try line.appendSpan("content", .{ .foreground_color = .blue });
            try line.appendSpan("", .{});
            try line.insertSpan(0, "", .{});

            line.clear();

            try std.testing.expectEqual(0, line.span_list.items.len);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.length() on empty line" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) anyerror!void {
            const line = Line.init(allocator, undefined);
            defer line.deinit();

            try std.testing.expectEqual(0, line.length());
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.length() on a non-empty line" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var line = Line.init(allocator, undefined);
            defer line.deinit();

            try line.appendSpan("söme cöntent", .{});
            try line.appendSpan("", .{});
            try line.appendSpan("", .{});
            try line.appendSpan("with unicöde cödepöints", .{});

            try std.testing.expectEqual(35, line.length());
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Line.clone()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var line = Line.init(allocator, .center);
            defer line.deinit();
            try line.appendSpan("content", .{ .foreground_color = .blue });

            const copy = try line.clone(allocator);
            defer copy.deinit();

            try std.testing.expectEqual(line.span_list.items.len, copy.span_list.items.len);
            try std.testing.expectEqualStrings(line.span_list.items[0].content, copy.span_list.items[0].content);
            try std.testing.expectEqualDeep(line.span_list.items[0].style, copy.span_list.items[0].style);
            try std.testing.expect(line.span_list.items.ptr != copy.span_list.items.ptr);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Text.init()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            const text = Text.init(allocator);
            defer text.deinit();
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "Text.clone()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            var text = Text.init(allocator);
            defer text.deinit();
            try text.addLine();
            try text.lines()[0].appendSpan("content", .{ .background_color = .black });

            const copy = try text.clone(text.allocator);
            defer copy.deinit();

            try std.testing.expectEqual(text.line_list.items.len, copy.line_list.items.len);
            try std.testing.expectEqualDeep(text.line_list.items[0], copy.line_list.items[0]);
            try std.testing.expect(text.line_list.items.ptr != copy.line_list.items.ptr);
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}
