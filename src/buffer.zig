const std = @import("std");
const fuizon = @import("fuizon.zig");

const Area = fuizon.Area;
const Attributes = fuizon.Attributes;
const Style = fuizon.style.Style;
const Coordinate = fuizon.Coordinate;

/// ...
pub const Buffer = struct {
    pub const none = Buffer.init(undefined);

    allocator: std.mem.Allocator,
    buffer: []BufferCell,
    area: Area,

    /// Creates and returns a new Buffer instance.
    pub fn init(allocator: std.mem.Allocator) Buffer {
        return .{
            .allocator = allocator,
            .buffer = &[_]BufferCell{},
            .area = .{
                .width = 0,
                .height = 0,
                .x = 0,
                .y = 0,
            },
        };
    }

    /// Initializes a new Buffer with the specified area.
    pub fn initArea(
        allocator: std.mem.Allocator,
        area: Area,
    ) std.mem.Allocator.Error!Buffer {
        var buffer = Buffer.init(allocator);
        try buffer.resize(area.width, area.height);
        buffer.moveTo(area.x, area.y);
        return buffer;
    }

    /// Initializes a new Buffer with the provided contents and style.
    ///
    /// This functions expects the content to be provided as a rectangular
    /// (W x H) string matrix. Rows with varying widths may cause undefined
    /// behavior.
    ///
    /// UTF-8 sequences with character widths greater than one cell are not
    /// supported at the moment.
    pub fn initContent(
        allocator: std.mem.Allocator,
        content: []const []const u8,
        style: Style,
    ) std.mem.Allocator.Error!Buffer {
        if (content.len == 0)
            return init(allocator);

        // Construct a grid of unicode codepoints from the provided list of
        // UTF-8 sequences.

        var grid = try std.ArrayList(std.ArrayList(u21)).initCapacity(allocator, content.len);
        defer {
            for (grid.items) |*content_list|
                content_list.deinit(allocator);
            grid.deinit(allocator);
        }
        for (0..content.len) |i| {
            const content_list = try grid.addOne(allocator);
            content_list.* = std.ArrayList(u21).empty;
            var content_iterator = (std.unicode.Utf8View.init(content[i]) catch unreachable).iterator();
            while (content_iterator.nextCodepoint()) |code_point| {
                try content_list.append(allocator, code_point);
            }
        }

        //

        var buffer = try Buffer.initArea(allocator, .{
            .width = @intCast(grid.items[0].items.len),
            .height = @intCast(grid.items.len),
            .x = 0,
            .y = 0,
        });
        errdefer buffer.deinit();

        for (0..grid.items.len) |y| {
            for (0..grid.items[y].items.len) |x| {
                const cell = buffer.index(@intCast(x), @intCast(y));
                cell.content = grid.items[y].items[x];
                cell.width = 1;
                cell.style = style;
            }
        }

        return buffer;
    }

    /// Deinitializes the Buffer and frees its dynamically allocated memory.
    pub fn deinit(self: Buffer) void {
        self.allocator.free(self.buffer);
    }

    /// Copies the provided Buffer.
    pub fn copy(self: *Buffer, buffer: Buffer) std.mem.Allocator.Error!void {
        try self.resize(buffer.area.width, buffer.area.height);
        self.moveTo(buffer.area.x, buffer.area.y);
        @memcpy(self.buffer, buffer.buffer);
    }

    /// Resizes the Buffer to the specified width and height.
    pub fn resize(self: *Buffer, width: u16, height: u16) std.mem.Allocator.Error!void {
        const old_buffer_length = self.buffer.len;
        if (width * height != self.buffer.len)
            self.buffer = try self.allocator.realloc(self.buffer, width * height);
        if (self.buffer.len > old_buffer_length)
            @memset(self.buffer[old_buffer_length..], BufferCell.empty);
        self.area.width = width;
        self.area.height = height;
    }

    /// Moves the buffer's origin up by `n` rows.
    pub inline fn moveUp(self: *Buffer, n: u16) void {
        self.area.y -|= n;
    }

    /// Moves the buffer's origin down by `n` rows.
    pub inline fn moveDown(self: *Buffer, y: u16) void {
        self.area.y +|= y;
    }

    /// Moves the buffer's origin left by `n` columns.
    pub inline fn moveLeft(self: *Buffer, n: u16) void {
        self.area.x -|= n;
    }

    /// Moves the buffer's origin right by `n` columns.
    pub inline fn moveRight(self: *Buffer, n: u16) void {
        self.area.x +|= n;
    }

    /// Moves the buffer's origin to a specified row.
    pub inline fn moveToRow(self: *Buffer, y: u16) void {
        self.area.y = y;
    }

    /// Moves the buffer's origin to a specified column.
    pub inline fn moveToCol(self: *Buffer, x: u16) void {
        self.area.x = x;
    }

    /// Moves the buffer's origin to specified coordinates.
    pub inline fn moveTo(self: *Buffer, x: u16, y: u16) void {
        self.area.x = x;
        self.area.y = y;
    }

    /// Returns a pointer to a buffer cell at the given absolute coordinates.
    pub fn index(self: anytype, x: u16, y: u16) switch (@TypeOf(self)) {
        *const Buffer => *const BufferCell,
        *Buffer => *BufferCell,
        else => unreachable,
    } {
        return &self.buffer[self.indexOf(x, y)];
    }

    /// Computes an index into the underlying buffer based on absolute coordinates.
    pub fn indexOf(self: Buffer, x: u16, y: u16) usize {
        if (self.area.top() > y or
            self.area.bottom() <= y or
            self.area.left() > x or
            self.area.right() <= x)
            @panic("Out of Bounds");

        return (y - self.area.top()) * self.area.width + (x - self.area.left());
    }

    /// Computes the position of a cell based on its index in the underlying buffer.
    pub fn posOf(self: Buffer, i: usize) Coordinate {
        return .{
            .x = @intCast(i % @as(usize, @intCast(self.area.width)) + @as(usize, @intCast(self.area.x))),
            .y = @intCast(i / @as(usize, @intCast(self.area.width)) + @as(usize, @intCast(self.area.y))),
        };
    }

    /// Fills every cell in the given area of the buffer with the specified
    /// cell value.
    pub fn fill(self: *Buffer, area: Area, cell: BufferCell) void {
        for (area.top()..area.bottom()) |y| {
            for (area.left()..area.right()) |x| {
                self.index(@intCast(x), @intCast(y)).* = cell;
            }
        }
    }

    /// Resets all cells in the buffer to their default (empty) state.
    pub fn reset(self: *Buffer) void {
        for (self.buffer) |*cell| {
            cell.reset();
        }
    }
};

/// ...
pub const BufferCell = struct {
    pub const empty = BufferCell{
        .width = 1,
        .content = ' ',
        .style = .{
            .foreground_color = .default,
            .background_color = .default,
            .attributes = Attributes.none,
        },
    };

    width: u2 = 1,
    content: u21 = ' ',
    style: Style = .{
        .foreground_color = .default,
        .background_color = .default,
        .attributes = Attributes.none,
    },

    /// Resets the cell to the empty state.
    pub fn reset(self: *BufferCell) void {
        self.* = BufferCell.empty;
    }
};

//
// Tests
//

test "initArea() should init area" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    const buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    try std.testing.expectEqualDeep(area, buffer.area);
}

test "init() should allocator the underlying buffer" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    const buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    try std.testing.expectEqual(5 * 9, buffer.buffer.len);
}

test "copy() with matching buffer dimensions should copy the source buffer" {
    const src_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var src = try Buffer.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(src.area, .{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var dest = try Buffer.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(dest.area, .{ .content = 15, .style = .{} });

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with matching buffer dimensions should not reallocate the underlying destination buffer" {
    const src_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var src = try Buffer.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(src.area, .{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var dest = try Buffer.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(dest.area, .{ .content = 15, .style = .{} });
    const dest_content = dest.buffer;

    try dest.copy(src);
    try std.testing.expect(dest_content.ptr == dest.buffer.ptr);
}

test "copy() with different buffer dimensions should copy the source buffer" {
    const src_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var src = try Buffer.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(src.area, .{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 1, .height = 5, .x = 5, .y = 9 };
    var dest = try Buffer.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(dest.area, .{ .content = 15, .style = .{} });

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with different buffer dimensions should reallocate the underlying destination buffer" {
    const src_area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var src = try Buffer.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(src.area, .{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 1, .height = 5, .x = 5, .y = 9 };
    var dest = try Buffer.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(dest.area, .{ .content = 15, .style = .{} });
    const dest_content = dest.buffer;

    try dest.copy(src);
    try std.testing.expect(dest_content.ptr != dest.buffer.ptr);
}

test "moveUp() should adjust y-origin upward" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveUp(5);

    try std.testing.expectEqual(0, buffer.area.y);
}

test "moveUp() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 0 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveUp(5);

    try std.testing.expectEqual(0, buffer.area.y);
}

test "moveDown() should adjust y-origin downward" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveDown(5);

    try std.testing.expectEqual(10, buffer.area.y);
}

test "moveDown() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = std.math.maxInt(u16) };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveDown(1);

    try std.testing.expectEqual(std.math.maxInt(u16), buffer.area.y);
}

test "moveLeft() should adjust x-origin to the left" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveLeft(1);

    try std.testing.expectEqual(0, buffer.area.x);
}

test "moveLeft() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .x = 0, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveLeft(1);

    try std.testing.expectEqual(0, buffer.area.x);
}

test "moveRight() should adjust x-origin to the right" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveRight(5);

    try std.testing.expectEqual(6, buffer.area.x);
}

test "moveRight() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .x = std.math.maxInt(u16), .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveRight(1);

    try std.testing.expectEqual(std.math.maxInt(u16), buffer.area.x);
}

test "moveToRow() should set the y-origin to the specified row" {
    const area = Area{ .width = 5, .height = 9, .x = 0, .y = 0 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveToRow(5);

    try std.testing.expectEqual(5, buffer.area.y);
}

test "moveToCol() should set the x-origin to the specified column" {
    const area = Area{ .width = 5, .height = 9, .x = 0, .y = 0 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveToCol(1);

    try std.testing.expectEqual(1, buffer.area.x);
}

test "moveTo() should set the origin to the specified coordinates" {
    const area = Area{ .width = 5, .height = 9, .x = 0, .y = 0 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.moveTo(1, 5);

    try std.testing.expectEqual(1, buffer.area.x);
    try std.testing.expectEqual(5, buffer.area.y);
}

test "index() should return a pointer to the expected cell" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.index(buffer.area.left(), buffer.area.top()).content = 59;

    try std.testing.expectEqual(
        59,
        buffer.index(
            buffer.area.left(),
            buffer.area.top(),
        ).content,
    );
}

test "index() should return the expected pointer type" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    try std.testing.expectEqual(
        *BufferCell,
        @TypeOf(buffer.index(
            buffer.area.left(),
            buffer.area.top(),
        )),
    );
    try std.testing.expectEqual(
        *const BufferCell,
        @TypeOf(@as(*const Buffer, &buffer).index(
            buffer.area.left(),
            buffer.area.top(),
        )),
    );
}

test "posOf() should return the position of the cell" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 5 }, buffer.posOf(0));
    try std.testing.expectEqualDeep(Coordinate{ .x = 2, .y = 5 }, buffer.posOf(1));
    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 7 }, buffer.posOf(10));
    try std.testing.expectEqualDeep(Coordinate{ .x = 5, .y = 13 }, buffer.posOf(44));
}

test "fill() should fill every cell in the buffer with the specified cell value" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.fill(buffer.area, BufferCell.empty);

    for (buffer.buffer) |cell| {
        try std.testing.expectEqual(
            BufferCell.empty,
            cell,
        );
    }
}

test "reset() should reset every cell to the default (empty) state" {
    const area = Area{ .width = 5, .height = 9, .x = 1, .y = 5 };
    var buffer = try Buffer.initArea(std.testing.allocator, area);
    defer buffer.deinit();

    buffer.reset();

    for (buffer.buffer) |cell| {
        try std.testing.expectEqual(
            BufferCell.empty,
            cell,
        );
    }
}
