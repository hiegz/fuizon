const std = @import("std");

// ---

pub const Coordinate = struct { x: u16, y: u16 };

// ---

/// Represents a rectangular area.
pub const Area = struct {
    width: u16,
    height: u16,
    origin: Coordinate,

    /// Returns the topmost coordinate of the area.
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

    /// Returns the bottommost coordinate of the area.
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

    /// Returns the leftmost coordinate of the area.
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

    /// Returns the rightmost coordinate of the area.
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
