const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.area.Area;
const Coordinate = fuizon.coordinate.Coordinate;

const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Style = fuizon.style.Style;
const Color = fuizon.style.Color;
const AnsiColor = fuizon.style.AnsiColor;
const RgbColor = fuizon.style.RgbColor;
const Attribute = fuizon.style.Attribute;
const Attributes = fuizon.style.Attributes;

const Direction = struct {
    x: i3,
    y: i3,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = buffer.writer();
    defer buffer.flush() catch {};

    try fuizon.backend.raw_mode.enable();
    defer fuizon.backend.raw_mode.disable() catch {};
    try fuizon.backend.alternate_screen.enter(stdout);
    defer fuizon.backend.alternate_screen.leave(stdout) catch {};
    try fuizon.backend.cursor.hide(stdout);
    defer fuizon.backend.cursor.show(stdout) catch {};

    var game: Game = undefined;
    var area: Area = undefined;
    var frame: [2]Frame = undefined;

    area = try fuizon.backend.area.fullscreen().render(stdout);

    frame[0] = try Frame.initArea(allocator, area);
    defer frame[0].deinit();
    frame[1] = Frame.init(allocator);
    defer frame[1].deinit();
    game = try Game.init(allocator, area);
    defer game.deinit();

    while (true) {
        game.render(&frame[0]);
        try fuizon.backend.frame.render(
            stdout,
            frame[0],
            frame[1],
        );
        try buffer.flush();
        try frame[1].copy(frame[0]);
        try game.tick();
        if (try fuizon.backend.event.poll()) {
            const event = try fuizon.backend.event.read();
            switch (event) {
                .key => {
                    if (event.key.code == .char) {
                        switch (event.key.code.char) {
                            'q' => break,
                            'h' => game.snake.parts.items[0].direction = .{ .x = -2, .y = 0 },
                            'j' => game.snake.parts.items[0].direction = .{ .x = 0, .y = 1 },
                            'k' => game.snake.parts.items[0].direction = .{ .x = 0, .y = -1 },
                            'l' => game.snake.parts.items[0].direction = .{ .x = 2, .y = 0 },
                            else => {},
                        }
                    }
                },
                .resize => {
                    area.width = event.resize.width;
                    area.height = event.resize.height;

                    try frame[0].resize(area.width, area.height);
                    game.deinit();
                    game = try Game.init(allocator, area);
                },
            }
        }

        std.time.sleep(16 * std.time.ns_per_ms / 1);
    }
}

const Game = struct {
    area: Area,
    snake: Snake,
    apples: [20]Apple,

    pub fn init(allocator: std.mem.Allocator, area: Area) !Game {
        var game: Game = undefined;
        game.area = area;
        game.snake = try Snake.init(allocator, area, .{ .x = 2, .y = 0 });
        for (&game.apples) |*apple| {
            apple.position.x = std.crypto.random.intRangeLessThan(u16, game.area.left(), game.area.right());
            if (apple.position.x % 2 != 0) apple.position.x -= 1;
            apple.position.y = std.crypto.random.intRangeLessThan(u16, game.area.top(), game.area.bottom());
            if (apple.position.y % 2 != 0) apple.position.y -= 1;
        }
        return game;
    }

    pub fn deinit(self: Game) void {
        self.snake.deinit();
    }

    pub fn tick(self: *Game) !void {
        self.snake.tick();
        for (&self.apples) |*apple| {
            if (!std.meta.eql(apple.position, self.snake.parts.items[0].position)) continue;
            apple.position.x = std.crypto.random.intRangeLessThan(u16, self.area.left(), self.area.right());
            if (apple.position.x % 2 != 0) apple.position.x -= 1;
            apple.position.y = std.crypto.random.intRangeLessThan(u16, self.area.top(), self.area.bottom());
            if (apple.position.y % 2 != 0) apple.position.y -= 1;
            try self.snake.append();
        }
    }

    pub fn render(self: Game, frame: *Frame) void {
        std.debug.assert(std.meta.eql(frame.area, self.area));
        frame.reset();
        self.snake.render(frame);
        for (self.apples) |apple| {
            apple.render(frame);
        }
    }
};

const Snake = struct {
    area: Area = .{ .width = 0, .height = 0, .origin = .{ .x = 0, .y = 0 } },
    parts: std.ArrayList(SnakePart),

    pub fn init(allocator: std.mem.Allocator, area: Area, direction: Direction) !Snake {
        var snake: Snake = undefined;
        snake.area = area;
        snake.parts = std.ArrayList(SnakePart).init(allocator);
        try snake.parts.append(SnakePart{
            .direction = direction,
            .position = .{
                .x = area.left(),
                .y = area.bottom() / 2 + 1,
            },
        });
        return snake;
    }

    pub fn deinit(self: Snake) void {
        self.parts.deinit();
    }

    ///
    pub fn append(self: *Snake) !void {
        std.debug.assert(self.parts.items.len > 0);

        const tail = &self.parts.items[self.parts.items.len - 1];

        // zig fmt: off
        const bottom = @as(i16, @intCast(self.area.bottom() + 1));
        const right  = @as(i16, @intCast(self.area.right() + 1));
        const x      = @as(i16, @intCast(tail.position.x));
        const y      = @as(i16, @intCast(tail.position.y));

        try self.parts.append(.{
            .direction = tail.direction,
            .position = .{
                .x = @intCast(@as(u16, @intCast(right  - tail.direction.x + x)) % @as(u16, @intCast(right))),
                .y = @intCast(@as(u16, @intCast(bottom - tail.direction.y + y)) % @as(u16, @intCast(bottom))),
            },
        });
        // zig fmt: on
    }

    pub fn tick(self: *Snake) void {
        std.debug.assert(self.parts.items.len > 0);

        var i = self.parts.items.len - 1;
        while (i > 0) : (i -= 1) {
            self.parts.items[i] = self.parts.items[i - 1];
        }

        var head = &self.parts.items[0];

        // zig fmt: off
        const bottom = @as(i16, @intCast(self.area.bottom() + 1));
        const right  = @as(i16, @intCast(self.area.right() + 1));
        const x      = @as(i16, @intCast(head.position.x));
        const y      = @as(i16, @intCast(head.position.y));

        head.position = .{
            .x = @intCast(@as(u16, @intCast(right  + head.direction.x + x)) % @as(u16, @intCast(right))),
            .y = @intCast(@as(u16, @intCast(bottom + head.direction.y + y)) % @as(u16, @intCast(bottom))),
        };
        // zig fmt: on
    }

    pub fn render(self: Snake, frame: *Frame) void {
        var cell: *FrameCell = undefined;
        for (self.parts.items) |part| {
            cell = frame.index(part.position.x, part.position.y);
            cell.content = ' ';
            cell.style.background_color = .blue;
            cell = frame.index((part.position.x + 1) % self.area.width, part.position.y);
            cell.content = ' ';
            cell.style.background_color = .blue;
        }
    }
};

const SnakePart = struct {
    position: Coordinate = .{ .x = 0, .y = 0 },
    direction: Direction,
};

const Apple = struct {
    position: Coordinate,

    pub fn render(self: Apple, frame: *Frame) void {
        var cell: *FrameCell = undefined;
        cell = frame.index(self.position.x, self.position.y);
        cell.content = ' ';
        cell.style.background_color = .red;
        cell = frame.index(self.position.x + 1, self.position.y);
        cell.content = ' ';
        cell.style.background_color = .red;
    }
};
