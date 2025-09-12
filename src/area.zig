const std = @import("std");
const fuizon = @import("fuizon.zig");
const Coordinate = fuizon.Coordinate;

pub const Area = struct {
    width: u16,
    height: u16,
    origin: Coordinate,

    pub fn top(self: Area) u16 {
        return self.origin.y;
    }

    test "top() should return the topmost coordinate" {
        try std.testing.expectEqual(5, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).top());
    }

    pub fn bottom(self: Area) u16 {
        return self.height + self.origin.y;
    }

    test "bottom() should return the bottommost coordinate" {
        try std.testing.expectEqual(14, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).bottom());
    }

    pub fn left(self: Area) u16 {
        return self.origin.x;
    }

    test "left() should return the leftmost coordinate" {
        try std.testing.expectEqual(1, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).left());
    }

    pub fn right(self: Area) u16 {
        return self.width + self.origin.x;
    }

    test "right() should return the rightmost coordinate" {
        try std.testing.expectEqual(6, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).right());
    }
};
