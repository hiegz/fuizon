const std = @import("std");
const mod = @import("../mod.zig");

const Apple = mod.Apple;
const Snake = mod.Snake;
const Direction = mod.Direction;
const GameState = mod.GameState;

pub const Game = struct {
    width: u16,
    height: u16,
    snake: Snake,
    apple: Apple,
    state: GameState,

    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) std.mem.Allocator.Error!Game {
        var game: Game = undefined;
        game.width = width;
        game.height = height;
        game.snake = try Snake.init(allocator, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 });
        errdefer game.snake.deinit();
        game.apple = .{ .position = .{ .x = 0, .y = 0 } };
        game.state = .game_paused;
        return game;
    }

    pub fn deinit(self: Game) void {
        self.snake.deinit();
    }

    pub fn run(self: *Game) void {
        self.state = .game_started;
    }

    pub fn running(self: Game) bool {
        return self.state == .game_started;
    }

    pub fn pause(self: *Game) void {
        self.state = .game_paused;
    }

    pub fn paused(self: Game) bool {
        return self.state == .game_paused;
    }

    pub fn over(self: Game) bool {
        return self.state == .game_over;
    }

    pub fn tick(self: *Game) !void {
        if (!self.running())
            return;

        var index: usize = undefined;

        index = self.snake.body.items.len - 1;
        while (index > 0) : (index -= 1)
            self.snake.body.items[index].position = self.snake.body.items[index - 1].position;
        self.snake.body.items[0].position.x += self.snake.body.items[0].direction.x * 2;
        self.snake.body.items[0].position.y += self.snake.body.items[0].direction.y;

        if (std.meta.eql(self.snake.body.items[0].position, self.apple.position)) {
            self.apple = Apple.random(self.width, self.height);

            const tail = self.snake.body.items[self.snake.body.items.len - 1];
            var new_direction = @as(?Direction, null);

            for ([_]Direction{
                // zig fmt: off
                .{ .x =  1, .y =  0 },
                .{ .x = -1, .y =  0 },
                .{ .x =  0, .y =  1 },
                .{ .x =  0, .y = -1 },
                // zig fmt: on
            }) |direction| {
                const x: i17 = tail.position.x - direction.x * 2;
                const y: i17 = tail.position.y - direction.y;

                // zig fmt: off
                if (x <  self.width  and
                    y <  self.height and
                    x >= 0           and
                    y >= 0)
                {
                    new_direction = direction;
                } else 
                    continue;
                // zig fmt: on

                if (direction.x == tail.direction.x and
                    direction.y == tail.direction.y)
                    break;
            }

            if (new_direction == null)
                unreachable;

            try self.snake.body.append(.{
                .direction = new_direction.?,
                .position = .{
                    .x = tail.position.x - new_direction.?.x * 2,
                    .y = tail.position.y - new_direction.?.y,
                },
            });
        }

        index = self.snake.body.items.len - 1;
        while (index > 0) : (index -= 1)
            self.snake.body.items[index].direction = self.snake.body.items[index - 1].direction;

        if (!self.validate())
            self.state = .game_over;
    }

    fn validate(self: Game) bool {
        if (self.snake.body.items.len == 0)
            return false;

        for (self.snake.body.items) |item| {
            // zig fmt: off
            if (item.position.x >= self.width  - 1 or
                item.position.y >= self.height     or
                item.position.x <  0               or
                item.position.y <  0) return false;
            // zig fmt: on
        }

        for (0..self.snake.body.items.len) |i| {
            for (i + 1..self.snake.body.items.len) |j| {
                const lhs = &self.snake.body.items[i];
                const rhs = &self.snake.body.items[j];

                if (lhs.position.x == rhs.position.x and
                    lhs.position.y == rhs.position.y)
                    return false;
            }
        }

        return true;
    }
};
