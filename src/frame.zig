const std = @import("std");
const fuizon = @import("fuizon.zig");

const Area = fuizon.area.Area;
const Attributes = fuizon.style.Attributes;
const Style = fuizon.style.Style;
const Coordinate = fuizon.coordinate.Coordinate;

/// ...
pub const Frame = struct {
    pub const none = Frame.init(undefined);

    allocator: std.mem.Allocator,
    buffer: []FrameCell,
    area: Area,

    /// Creates and returns a new Frame instance.
    pub fn init(allocator: std.mem.Allocator) Frame {
        return .{
            .allocator = allocator,
            .buffer = &[_]FrameCell{},
            .area = .{
                .width = 0,
                .height = 0,
                .origin = .{ .x = 0, .y = 0 },
            },
        };
    }

    /// Initializes a new Frame with the specified area.
    pub fn initArea(
        allocator: std.mem.Allocator,
        area: Area,
    ) std.mem.Allocator.Error!Frame {
        var frame = Frame.init(allocator);
        try frame.resize(area.width, area.height);
        frame.moveTo(area.origin.x, area.origin.y);
        return frame;
    }

    /// Deinitializes the Frame and frees its dynamically allocated memory.
    pub fn deinit(self: Frame) void {
        self.allocator.free(self.buffer);
    }

    /// Copies the provided Frame.
    pub fn copy(self: *Frame, frame: Frame) std.mem.Allocator.Error!void {
        try self.resize(frame.area.width, frame.area.height);
        self.moveTo(frame.area.origin.x, frame.area.origin.y);
        @memcpy(self.buffer, frame.buffer);
    }

    /// Resizes the Frame to the specified width and height.
    pub fn resize(self: *Frame, width: u16, height: u16) std.mem.Allocator.Error!void {
        if (width * height != self.buffer.len) {
            const buffer = try self.allocator.alloc(FrameCell, width * height);
            errdefer self.allocator.free(buffer);
            self.allocator.free(self.buffer);
            self.buffer.ptr = buffer.ptr;
            self.buffer.len = buffer.len;
        }
        self.area.width = width;
        self.area.height = height;
    }

    /// Moves the frame's origin up by `n` rows.
    pub inline fn moveUp(self: *Frame, n: u16) void {
        self.area.origin.y -|= n;
    }

    /// Moves the frame's origin down by `n` rows.
    pub inline fn moveDown(self: *Frame, y: u16) void {
        self.area.origin.y +|= y;
    }

    /// Moves the frame's origin left by `n` columns.
    pub inline fn moveLeft(self: *Frame, n: u16) void {
        self.area.origin.x -|= n;
    }

    /// Moves the frame's origin right by `n` columns.
    pub inline fn moveRight(self: *Frame, n: u16) void {
        self.area.origin.x +|= n;
    }

    /// Moves the frame's origin to a specified row.
    pub inline fn moveToRow(self: *Frame, y: u16) void {
        self.area.origin.y = y;
    }

    /// Moves the frame's origin to a specified column.
    pub inline fn moveToCol(self: *Frame, x: u16) void {
        self.area.origin.x = x;
    }

    /// Moves the frame's origin to specified coordinates.
    pub inline fn moveTo(self: *Frame, x: u16, y: u16) void {
        self.area.origin.x = x;
        self.area.origin.y = y;
    }

    /// Returns a pointer to a frame cell at the given absolute coordinates.
    pub fn index(self: anytype, x: u16, y: u16) switch (@TypeOf(self)) {
        *const Frame => *const FrameCell,
        *Frame => *FrameCell,
        else => unreachable,
    } {
        return &self.buffer[self.indexOf(x, y)];
    }

    /// Computes an index into the underlying frame based on absolute coordinates.
    pub fn indexOf(self: Frame, x: u16, y: u16) usize {
        if (self.area.top() > y or
            self.area.bottom() < y or
            self.area.left() > x or
            self.area.right() < x)
            @panic("Out of Bounds");

        return (y - self.area.top()) * self.area.width + (x - self.area.left());
    }

    /// Computes the position of a cell based on its index in the underlying buffer.
    pub fn posOf(self: Frame, i: usize) Coordinate {
        return .{
            .x = @intCast(i % @as(usize, @intCast(self.area.width)) + @as(usize, @intCast(self.area.origin.x))),
            .y = @intCast(i / @as(usize, @intCast(self.area.width)) + @as(usize, @intCast(self.area.origin.y))),
        };
    }

    /// Fills every cell in the frame with the specified cell value.
    pub fn fill(self: *Frame, cell: FrameCell) void {
        for (self.buffer) |*c| {
            c.* = cell;
        }
    }

    /// Resets all cells in the frame to their default (empty) state.
    pub fn reset(self: *Frame) void {
        for (self.buffer) |*cell| {
            cell.reset();
        }
    }
};

/// ...
pub const FrameCell = struct {
    pub const empty = FrameCell{
        .width = 1,
        .content = ' ',
        .style = .{
            .foreground_color = .default,
            .background_color = .default,
            .attributes = Attributes.none,
        },
    };

    width: u2 = 1,
    content: u21,
    style: Style = .{},

    /// Resets the cell to the empty state.
    pub fn reset(self: *FrameCell) void {
        self.* = FrameCell.empty;
    }
};

//
// Tests
//

test "initArea() should init area" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    const frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    try std.testing.expectEqualDeep(area, frame.area);
}

test "init() should allocator the underlying buffer" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    const frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    try std.testing.expectEqual(5 * 9, frame.buffer.len);
}

test "copy() with matching frame dimensions should copy the source frame" {
    const src_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var src = try Frame.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(.{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var dest = try Frame.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(.{ .content = 15, .style = .{} });

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with matching frame dimensions should not reallocate the underlying destination buffer" {
    const src_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var src = try Frame.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(.{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var dest = try Frame.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(.{ .content = 15, .style = .{} });
    const dest_content = dest.buffer;

    try dest.copy(src);
    try std.testing.expect(dest_content.ptr == dest.buffer.ptr);
}

test "copy() with different frame dimensions should copy the source frame" {
    const src_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var src = try Frame.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(.{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 1, .height = 5, .origin = .{ .x = 5, .y = 9 } };
    var dest = try Frame.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(.{ .content = 15, .style = .{} });

    try std.testing.expect(!std.meta.eql(src, dest));
    try dest.copy(src);
    try std.testing.expectEqualDeep(src, dest);
}

test "copy() with different frame dimensions should reallocate the underlying destination buffer" {
    const src_area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var src = try Frame.initArea(std.testing.allocator, src_area);
    defer src.deinit();
    src.fill(.{ .content = 59, .style = .{} });

    const dest_area = Area{ .width = 1, .height = 5, .origin = .{ .x = 5, .y = 9 } };
    var dest = try Frame.initArea(std.testing.allocator, dest_area);
    defer dest.deinit();
    dest.fill(.{ .content = 15, .style = .{} });
    const dest_content = dest.buffer;

    try dest.copy(src);
    try std.testing.expect(dest_content.ptr != dest.buffer.ptr);
}

test "moveUp() should adjust y-origin upward" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveUp(5);

    try std.testing.expectEqual(0, frame.area.origin.y);
}

test "moveUp() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 0 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveUp(5);

    try std.testing.expectEqual(0, frame.area.origin.y);
}

test "moveDown() should adjust y-origin downward" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveDown(5);

    try std.testing.expectEqual(10, frame.area.origin.y);
}

test "moveDown() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = std.math.maxInt(u16) } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveDown(1);

    try std.testing.expectEqual(std.math.maxInt(u16), frame.area.origin.y);
}

test "moveLeft() should adjust x-origin to the left" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveLeft(1);

    try std.testing.expectEqual(0, frame.area.origin.x);
}

test "moveLeft() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 0, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveLeft(1);

    try std.testing.expectEqual(0, frame.area.origin.x);
}

test "moveRight() should adjust x-origin to the right" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveRight(5);

    try std.testing.expectEqual(6, frame.area.origin.x);
}

test "moveRight() should not overflow" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = std.math.maxInt(u16), .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveRight(1);

    try std.testing.expectEqual(std.math.maxInt(u16), frame.area.origin.x);
}

test "moveToRow() should set the y-origin to the specified row" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 0, .y = 0 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveToRow(5);

    try std.testing.expectEqual(5, frame.area.origin.y);
}

test "moveToCol() should set the x-origin to the specified column" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 0, .y = 0 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveToCol(1);

    try std.testing.expectEqual(1, frame.area.origin.x);
}

test "moveTo() should set the origin to the specified coordinates" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 0, .y = 0 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.moveTo(1, 5);

    try std.testing.expectEqual(1, frame.area.origin.x);
    try std.testing.expectEqual(5, frame.area.origin.y);
}

test "index() should return a pointer to the expected cell" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.index(frame.area.left(), frame.area.top()).content = 59;

    try std.testing.expectEqual(
        59,
        frame.index(
            frame.area.left(),
            frame.area.top(),
        ).content,
    );
}

test "index() should return the expected pointer type" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    try std.testing.expectEqual(
        *FrameCell,
        @TypeOf(frame.index(
            frame.area.left(),
            frame.area.top(),
        )),
    );
    try std.testing.expectEqual(
        *const FrameCell,
        @TypeOf(@as(*const Frame, &frame).index(
            frame.area.left(),
            frame.area.top(),
        )),
    );
}

test "posOf() should return the position of the cell" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 5 }, frame.posOf(0));
    try std.testing.expectEqualDeep(Coordinate{ .x = 2, .y = 5 }, frame.posOf(1));
    try std.testing.expectEqualDeep(Coordinate{ .x = 1, .y = 7 }, frame.posOf(10));
    try std.testing.expectEqualDeep(Coordinate{ .x = 5, .y = 13 }, frame.posOf(44));
}

test "fill() should fill every cell in the frame with the specified cell value" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.fill(FrameCell.empty);

    for (frame.buffer) |cell| {
        try std.testing.expectEqual(
            FrameCell.empty,
            cell,
        );
    }
}

test "reset() should reset every cell to the default (empty) state" {
    const area = Area{ .width = 5, .height = 9, .origin = .{ .x = 1, .y = 5 } };
    var frame = try Frame.initArea(std.testing.allocator, area);
    defer frame.deinit();

    frame.reset();

    for (frame.buffer) |cell| {
        try std.testing.expectEqual(
            FrameCell.empty,
            cell,
        );
    }
}
