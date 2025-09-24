const std = @import("std");
const Area = @import("area.zig").Area;
const Coordinate = @import("coordinate.zig").Coordinate;
const Dimensions = @import("dimensions.zig").Dimensions;
const Character = @import("character.zig").Character;
const Style = @import("style.zig").Style;
const Widget = @import("widget.zig").Widget;

pub const Buffer = struct {
    characters: []Character,
    _width: u16,
    _height: u16,

    pub fn init() Buffer {
        var self: Buffer = undefined;
        self.characters = &.{};
        self._width = 0;
        self._height = 0;
        return self;
    }

    pub fn initDimensions(
        gpa: std.mem.Allocator,
        dimensions: Dimensions,
    ) error{OutOfMemory}!Buffer {
        var self: Buffer = undefined;
        self.characters = try gpa.alloc(Character, dimensions.width * dimensions.height);
        for (self.characters) |*character|
            character.* = .{};
        self._width = dimensions.width;
        self._height = dimensions.height;
        return self;
    }

    pub fn initContent(
        gpa: std.mem.Allocator,
        content: []const []const u8,
        style: Style,
    ) error{ OutOfMemory, Unexpected }!Buffer {
        if (content.len == 0)
            return Buffer.init();

        const h = @as(u16, @intCast(content.len));
        const w = tag: {
            var count: u16 = 0;
            const utf8View = std.unicode.Utf8View.init(content[0]) catch return error.Unexpected;
            var iterator = utf8View.iterator();
            while (iterator.nextCodepoint()) |_| count += 1;
            break :tag count;
        };

        var self = try Buffer.initDimensions(gpa, .init(w, h));
        errdefer self.deinit(gpa);
        var i: usize = 0;

        for (content) |row| {
            const utf8View = std.unicode.Utf8View.init(row) catch return error.Unexpected;
            var iterator = utf8View.iterator();
            while (iterator.nextCodepoint()) |codepoint| {
                std.debug.assert(i < self.characters.len);
                self.characters[i].value = codepoint;
                self.characters[i].style = style;
                i += 1;
            }
        }

        return self;
    }

    pub fn deinit(self: Buffer, gpa: std.mem.Allocator) void {
        gpa.free(self.characters);
    }

    pub fn width(self: Buffer) u16 {
        return self._width;
    }

    pub fn height(self: Buffer) u16 {
        return self._height;
    }

    pub fn getDimensions(self: Buffer) Dimensions {
        return Dimensions.init(self.width(), self.height());
    }

    pub fn getArea(self: Buffer) Area {
        return Area.init(self.width(), self.height(), 0, 0);
    }

    pub fn equals(self: Buffer, other: Buffer) bool {
        if (self.width() != other.width())
            return false;
        if (self.height() != other.height())
            return false;

        for (0..self.characters.len) |i| {
            if (!std.meta.eql(self.characters[i], other.characters[i]))
                return false;
        }

        return true;
    }

    pub fn copy(
        self: *Buffer,
        gpa: std.mem.Allocator,
        other: Buffer,
    ) error{OutOfMemory}!void {
        try self.resize(gpa, .init(other.width(), other.height()));
        @memcpy(self.characters, other.characters);
    }

    pub fn resize(
        self: *Buffer,
        gpa: std.mem.Allocator,
        dimensions: Dimensions,
    ) std.mem.Allocator.Error!void {
        const old_buffer_length = self.characters.len;
        if (dimensions.width * dimensions.height != self.characters.len)
            self.characters = try gpa.realloc(self.characters, dimensions.width * dimensions.height);
        if (self.characters.len > old_buffer_length)
            @memset(self.characters[old_buffer_length..], Character{});
        self._width = dimensions.width;
        self._height = dimensions.height;
    }

    /// Computes the index of a character based on its coordinates.
    pub fn indexOf(self: Buffer, x: u16, y: u16) usize {
        return y * self.width() + x;
    }

    /// Computes the position of a character based on its index in the underlying buffer.
    pub fn posOf(self: Buffer, i: usize) Coordinate {
        return .{
            .x = @intCast(i % @as(usize, @intCast(self.width()))),
            .y = @intCast(i / @as(usize, @intCast(self.width()))),
        };
    }

    pub fn format(self: Buffer, writer: *std.Io.Writer) !void {
        try writer.print("width:  {d}\n", .{self.width()});
        try writer.print("height: {d}\n", .{self.height()});
        try writer.print("content:\n", .{});
        for (self.characters, 0..) |character, i| {
            if (i % self.width() == 0 and i != 0)
                try writer.writeAll("\n");
            try writer.print("{u}", .{character.value});
        }
    }

    pub fn measure(
        self: Buffer,
        opts: Widget.MeasureOptions,
    ) anyerror!Dimensions {
        var d = self.getDimensions();
        d.width = @min(opts.max_width, d.width);
        d.height = @min(opts.max_height, d.height);
        return d;
    }

    pub fn render(
        self: Buffer,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        var i: usize = 0;
        for (area.top()..area.bottom()) |y| {
            for (area.left()..area.right()) |x| {
                if (i >= self.characters.len) return;
                const index = buffer.indexOf(@intCast(x), @intCast(y));
                buffer.characters[index] = self.characters[i];
                i += 1;
            }
        }
    }

    pub fn widget(self: *const Buffer) Widget {
        return Widget.impl(self);
    }
};

//
// Tests
//

test "initDimensions() should initialize buffer dimensions" {
    const gpa = std.testing.allocator;
    const buffer = try Buffer.initDimensions(gpa, .init(5, 9));
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5, buffer.width());
    try std.testing.expectEqual(9, buffer.height());
}

test "initDimensions() should initialize the underlying character array" {
    const gpa = std.testing.allocator;
    const buffer = try Buffer.initDimensions(gpa, .init(5, 9));
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5 * 9, buffer.characters.len);
}

test "copy() with matching buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, .init(5, 9));
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, .init(5, 9));
    defer dest.deinit(gpa);
    for (dest.characters) |*character| {
        character.value = 15;
        character.style = .{};
    }

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(gpa, src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with matching buffer dimensions should not reallocate the underlying destination buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, .init(5, 9));
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, .init(5, 9));
    defer dest.deinit(gpa);
    const dest_ptr = dest.characters.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr == dest.characters.ptr);
}

test "copy() with different buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, .init(5, 9));
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, .init(1, 5));
    defer dest.deinit(gpa);
    for (dest.characters) |*character| {
        character.value = 15;
        character.style = .{};
    }

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(gpa, src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with different buffer dimensions should reallocate the underlying destination buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, .init(5, 9));
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, .init(1, 5));
    defer dest.deinit(gpa);
    const dest_ptr = dest.characters.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr != dest.characters.ptr);
}

test "posOf() should return the position of the character" {
    const gpa = std.testing.allocator;
    var buffer = try Buffer.initDimensions(gpa, .init(5, 9));
    defer buffer.deinit(gpa);

    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 0 }, buffer.posOf(0));
    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 0 }, buffer.posOf(1));
    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 2 }, buffer.posOf(10));
    try std.testing.expectEqualDeep(Coordinate{ .x = 4, .y = 8 }, buffer.posOf(44));
}

test "measure() should just return buffer dimensions" {
    const gpa = std.testing.allocator;
    const buffer: Buffer = try .initDimensions(gpa, .init(5, 9));
    defer buffer.deinit(gpa);

    const dimensions = try buffer.measure(.{});

    return std.testing.expectEqualDeep(dimensions, Dimensions.init(buffer.width(), buffer.height()));
}

test "measure() should not overflow the max dimensions" {
    const gpa = std.testing.allocator;
    const buffer: Buffer = try .initDimensions(gpa, .init(5, 9));
    defer buffer.deinit(gpa);

    const dimensions = try buffer.measure(.opts(1, 5));

    return std.testing.expectEqualDeep(dimensions, Dimensions.init(1, 5));
}

test "render() should copy the buffer" {
    const gpa = std.testing.allocator;

    const expected = try Buffer.initContent(gpa, &[_][]const u8{
        "ab",
        "cd",
    }, .{});
    defer expected.deinit(gpa);

    var buffer = try Buffer.initDimensions(gpa, .init(2, 2));
    defer buffer.deinit(gpa);

    buffer.characters[0] = Character.init('a', .{});
    buffer.characters[1] = Character.init('b', .{});
    buffer.characters[2] = Character.init('c', .{});
    buffer.characters[3] = Character.init('d', .{});

    const dimensions = try buffer.measure(.opts(expected.width(), expected.height()));
    var actual = try Buffer.initDimensions(gpa, dimensions);
    defer actual.deinit(gpa);

    try buffer.render(&actual, actual.getArea());

    std.testing.expect(
        expected.equals(actual),
    ) catch |err| {
        std.debug.print("\t\n", .{});
        std.debug.print("expected:\n{f}\n\n", .{expected});
        std.debug.print("found:\n{f}\n", .{actual});
        return err;
    };
}

test "render() should copy the buffer at a specified offset" {
    const gpa = std.testing.allocator;

    const expected = try Buffer.initContent(gpa, &[_][]const u8{
        "    ",
        " ab ",
        " cd ",
        "    ",
    }, .{});
    defer expected.deinit(gpa);

    var buffer = try Buffer.initDimensions(gpa, .init(2, 2));
    defer buffer.deinit(gpa);

    buffer.characters[0] = Character.init('a', .{});
    buffer.characters[1] = Character.init('b', .{});
    buffer.characters[2] = Character.init('c', .{});
    buffer.characters[3] = Character.init('d', .{});

    var actual = try Buffer.initDimensions(gpa, .init(4, 4));
    defer actual.deinit(gpa);

    try buffer.render(&actual, Area.init(2, 2, 1, 1));

    std.testing.expect(
        expected.equals(actual),
    ) catch |err| {
        std.debug.print("\t\n", .{});
        std.debug.print("expected:\n{f}\n\n", .{expected});
        std.debug.print("found:\n{f}\n", .{actual});
        return err;
    };
}

test "render() should not overflow the destination buffer" {
    const gpa = std.testing.allocator;

    const expected = try Buffer.initContent(gpa, &[_][]const u8{
        "    ",
        " ab ",
        "    ",
    }, .{});
    defer expected.deinit(gpa);

    var buffer = try Buffer.initDimensions(gpa, .init(3, 2));
    defer buffer.deinit(gpa);

    buffer.characters[0] = Character.init('a', .{});
    buffer.characters[1] = Character.init('b', .{});
    buffer.characters[2] = Character.init('c', .{});
    buffer.characters[3] = Character.init('d', .{});

    var actual = try Buffer.initDimensions(gpa, .init(4, 3));
    defer actual.deinit(gpa);

    try buffer.render(&actual, Area.init(2, 1, 1, 1));

    std.testing.expect(
        expected.equals(actual),
    ) catch |err| {
        std.debug.print("\t\n", .{});
        std.debug.print("expected:\n{f}\n\n", .{expected});
        std.debug.print("found:\n{f}\n", .{actual});
        return err;
    };
}
