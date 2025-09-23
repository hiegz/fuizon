const std = @import("std");
const Coordinate = @import("coordinate.zig").Coordinate;
const Character = @import("character.zig").Character;
const Style = @import("style.zig").Style;

pub const Buffer = struct {
    characters: []Character,
    _width: u16,

    pub fn init() Buffer {
        var self: Buffer = undefined;
        self.characters = &.{};
        self._width = 0;
        std.debug.assert(self.height() == 0);
        return self;
    }

    pub fn initDimensions(
        gpa: std.mem.Allocator,
        w: u16,
        h: u16,
    ) error{OutOfMemory}!Buffer {
        var self: Buffer = undefined;
        self.characters = try gpa.alloc(Character, w * h);
        for (self.characters) |*character|
            character.* = .{};
        self._width = w;
        std.debug.assert(self.height() == h);
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

        var self = try Buffer.initDimensions(gpa, w, h);
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
        if (self.width() == 0) return 0;
        return @intCast(self.characters.len / @as(usize, @intCast(self.width())));
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
        try self.resize(gpa, other.width(), other.height());
        @memcpy(self.characters, other.characters);
    }

    pub fn resize(
        self: *Buffer,
        gpa: std.mem.Allocator,
        w: u16,
        h: u16,
    ) std.mem.Allocator.Error!void {
        const old_buffer_length = self.characters.len;
        if (w * h != self.characters.len)
            self.characters = try gpa.realloc(self.characters, w * h);
        if (self.characters.len > old_buffer_length)
            @memset(self.characters[old_buffer_length..], Character{});
        self._width = w;
        std.debug.assert(self.height() == h);
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
};

//
// Tests
//

test "initDimensions() should initialize buffer dimensions" {
    const gpa = std.testing.allocator;
    const buffer = try Buffer.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5, buffer.width());
    try std.testing.expectEqual(9, buffer.height());
}

test "initDimensions() should initialize the underlying character array" {
    const gpa = std.testing.allocator;
    const buffer = try Buffer.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5 * 9, buffer.characters.len);
}

test "copy() with matching buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, 5, 9);
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

    var src = try Buffer.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, 5, 9);
    defer dest.deinit(gpa);
    const dest_ptr = dest.characters.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr == dest.characters.ptr);
}

test "copy() with different buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Buffer.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, 1, 5);
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

    var src = try Buffer.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.characters) |*character| {
        character.value = 59;
        character.style = .{};
    }

    var dest = try Buffer.initDimensions(gpa, 1, 5);
    defer dest.deinit(gpa);
    const dest_ptr = dest.characters.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr != dest.characters.ptr);
}

test "posOf() should return the position of the character" {
    const gpa = std.testing.allocator;
    var buffer = try Buffer.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 0 }, buffer.posOf(0));
    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 0 }, buffer.posOf(1));
    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 2 }, buffer.posOf(10));
    try std.testing.expectEqualDeep(Coordinate{ .x = 4, .y = 8 }, buffer.posOf(44));
}
