const std = @import("std");

pub const Area = struct {
    width: u16,
    height: u16,
    x: u16,
    y: u16,

    pub fn top(self: Area) u16 {
        return self.y;
    }

    test "top() should return the topmost coordinate" {
        try std.testing.expectEqual(5, (Area{
            .width = 5,
            .height = 9,
            .x = 1,
            .y = 5,
        }).top());
    }

    pub fn bottom(self: Area) u16 {
        return self.height + self.y;
    }

    test "bottom() should return the bottommost coordinate" {
        try std.testing.expectEqual(14, (Area{
            .width = 5,
            .height = 9,
            .x = 1,
            .y = 5,
        }).bottom());
    }

    pub fn left(self: Area) u16 {
        return self.x;
    }

    test "left() should return the leftmost coordinate" {
        try std.testing.expectEqual(1, (Area{
            .width = 5,
            .height = 9,
            .x = 1,
            .y = 5,
        }).left());
    }

    pub fn right(self: Area) u16 {
        return self.width + self.x;
    }

    test "right() should return the rightmost coordinate" {
        try std.testing.expectEqual(6, (Area{
            .width = 5,
            .height = 9,
            .x = 1,
            .y = 5,
        }).right());
    }
};
