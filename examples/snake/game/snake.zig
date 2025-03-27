const std = @import("std");
const mod = @import("../mod.zig");

const Position = mod.Position;
const Direction = mod.Direction;

pub const Snake = struct {
    body: std.ArrayList(SnakePart),

    pub fn init(
        allocator: std.mem.Allocator,
        position: Position,
        direction: Direction,
    ) std.mem.Allocator.Error!Snake {
        var snake: Snake = undefined;
        snake.body = std.ArrayList(SnakePart).init(allocator);
        errdefer snake.body.deinit();
        try snake.body.insert(0, .{ .position = position, .direction = direction });
        return snake;
    }

    pub fn deinit(self: Snake) void {
        self.body.deinit();
    }

    pub fn redirect(self: *Snake, direction: Direction) void {
        self.body.items[0].direction = direction;
    }
};

pub const SnakePart = struct {
    position: Position,
    direction: Direction,
};
