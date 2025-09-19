const std = @import("std");
const Coordinate = @import("coordinate.zig").Coordinate;
const Style = @import("style.zig").Style;
const Self = @This();

pub const Cell = struct {
    content: u21 = ' ',
    style: Style = .{},

    pub fn init(content: u21, style: Style) Cell {
        return .{ .content = content, .style = style };
    }
};

cells: []Cell,
_width: u16,

pub fn init() Self {
    var self: Self = undefined;
    self.cells = &.{};
    self._width = 0;
    std.debug.assert(self.height() == 0);
    return self;
}

pub fn initDimensions(
    gpa: std.mem.Allocator,
    w: u16,
    h: u16,
) error{OutOfMemory}!Self {
    var self: Self = undefined;
    self.cells = try gpa.alloc(Cell, w * h);
    self._width = w;
    std.debug.assert(self.height() == h);
    return self;
}

pub fn initContent(
    gpa: std.mem.Allocator,
    content: []const []const u8,
    style: Style,
) error{ OutOfMemory, Unexpected }!Self {
    if (content.len == 0)
        return Self.init();

    const h = @as(u16, @intCast(content.len));
    const w = tag: {
        var count: u16 = 0;
        const utf8View = std.unicode.Utf8View.init(content[0]) catch return error.Unexpected;
        var iterator = utf8View.iterator();
        while (iterator.nextCodepoint()) |_| count += 1;
        break :tag count;
    };

    var self = try Self.initDimensions(gpa, w, h);
    errdefer self.deinit(gpa);
    var i: usize = 0;

    for (content) |row| {
        const utf8View = std.unicode.Utf8View.init(row) catch return error.Unexpected;
        var iterator = utf8View.iterator();
        while (iterator.nextCodepoint()) |codepoint| {
            std.debug.assert(i + 1 < self.cells.len);
            self.cells[i].content = codepoint;
            self.cells[i].style = style;
            i += 1;
        }
    }

    return self;
}

pub fn deinit(self: Self, gpa: std.mem.Allocator) void {
    gpa.free(self.cells);
}

pub fn width(self: Self) u16 {
    return self._width;
}

pub fn height(self: Self) u16 {
    return @intCast(self.cells.len / @as(usize, @intCast(self.width())));
}

pub fn copy(
    self: *Self,
    gpa: std.mem.Allocator,
    other: Self,
) error{OutOfMemory}!void {
    try self.resize(gpa, other.width(), other.height());
    @memcpy(self.cells, other.cells);
}

pub fn resize(
    self: *Self,
    gpa: std.mem.Allocator,
    w: u16,
    h: u16,
) std.mem.Allocator.Error!void {
    const old_buffer_length = self.cells.len;
    if (w * h != self.cells.len)
        self.cells = try gpa.realloc(self.cells, w * h);
    if (self.cells.len > old_buffer_length)
        @memset(self.cells[old_buffer_length..], Cell{});
    self._width = w;
    std.debug.assert(self.height() == h);
}

/// Computes the index of a cell based on its coordinates.
pub fn indexOf(self: Self, x: u16, y: u16) usize {
    return y * self.width() + x;
}

/// Computes the position of a cell based on its index in the underlying buffer.
pub fn posOf(self: Self, i: usize) Coordinate {
    return .{
        .x = @intCast(i % @as(usize, @intCast(self.width()))),
        .y = @intCast(i / @as(usize, @intCast(self.width()))),
    };
}

//
// Tests
//

test "initDimensions() should initialize buffer dimensions" {
    const gpa = std.testing.allocator;
    const buffer = try Self.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5, buffer.width());
    try std.testing.expectEqual(9, buffer.height());
}

test "initDimensions() should initialize the underlying cell array" {
    const gpa = std.testing.allocator;
    const buffer = try Self.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqual(5 * 9, buffer.cells.len);
}

test "copy() with matching buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Self.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.cells) |*cell| {
        cell.content = 59;
        cell.style = .{};
    }

    var dest = try Self.initDimensions(gpa, 5, 9);
    defer dest.deinit(gpa);
    for (dest.cells) |*cell| {
        cell.content = 15;
        cell.style = .{};
    }

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(gpa, src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with matching buffer dimensions should not reallocate the underlying destination buffer" {
    const gpa = std.testing.allocator;

    var src = try Self.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.cells) |*cell| {
        cell.content = 59;
        cell.style = .{};
    }

    var dest = try Self.initDimensions(gpa, 5, 9);
    defer dest.deinit(gpa);
    const dest_ptr = dest.cells.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr == dest.cells.ptr);
}

test "copy() with different buffer dimensions should copy the source buffer" {
    const gpa = std.testing.allocator;

    var src = try Self.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.cells) |*cell| {
        cell.content = 59;
        cell.style = .{};
    }

    var dest = try Self.initDimensions(gpa, 1, 5);
    defer dest.deinit(gpa);
    for (dest.cells) |*cell| {
        cell.content = 15;
        cell.style = .{};
    }

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(gpa, src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with different buffer dimensions should reallocate the underlying destination buffer" {
    const gpa = std.testing.allocator;

    var src = try Self.initDimensions(gpa, 5, 9);
    defer src.deinit(gpa);
    for (src.cells) |*cell| {
        cell.content = 59;
        cell.style = .{};
    }

    var dest = try Self.initDimensions(gpa, 1, 5);
    defer dest.deinit(gpa);
    const dest_ptr = dest.cells.ptr;

    try dest.copy(gpa, src);
    try std.testing.expect(dest_ptr != dest.cells.ptr);
}

test "posOf() should return the position of the cell" {
    const gpa = std.testing.allocator;
    var buffer = try Self.initDimensions(gpa, 5, 9);
    defer buffer.deinit(gpa);

    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 0 }, buffer.posOf(0));
    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 0 }, buffer.posOf(1));
    try std.testing.expectEqualDeep(Coordinate{ .x = 0, .y = 2 }, buffer.posOf(10));
    try std.testing.expectEqualDeep(Coordinate{ .x = 4, .y = 8 }, buffer.posOf(44));
}
