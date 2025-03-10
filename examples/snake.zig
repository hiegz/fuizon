const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.area.Area;

const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Style = fuizon.style.Style;
const Color = fuizon.style.Color;
const AnsiColor = fuizon.style.AnsiColor;
const RgbColor = fuizon.style.RgbColor;
const Attribute = fuizon.style.Attribute;
const Attributes = fuizon.style.Attributes;

const Direction = struct { x: i3, y: i3 };
const Position = struct { x: i17, y: i17 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //
    // Terminal Render Environment Setup
    //

    var buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = buffer.writer();
    defer buffer.flush() catch {};

    try fuizon.backend.raw_mode.enable();
    defer fuizon.backend.raw_mode.disable() catch {};
    try fuizon.backend.alternate_screen.enter(stdout);
    defer fuizon.backend.alternate_screen.leave(stdout) catch {};
    try fuizon.backend.cursor.hide(stdout);
    defer fuizon.backend.cursor.show(stdout) catch {};

    var renderer = try Renderer.initFullscreen(allocator, stdout);
    defer renderer.deinit();

    try buffer.flush();

    //
    // Game
    //

    var game = try Game.initRandom(allocator, renderer.frame().area, 20);
    defer game.deinit();

    //
    // Event Loop
    //

    while (true) {
        GameRenderer.render(game, renderer.frame());
        try renderer.render(stdout);
        try buffer.flush();

        if (try fuizon.backend.event.poll()) {
            const event = try fuizon.backend.event.read();
            switch (event) {
                .key => switch (event.key.code) {
                    .char => switch (event.key.code.char) {
                        'q' => break,
                        // zig fmt: off
                        'h' => game.snake.redirect(.{ .x = -1, .y =  0 }),
                        'j' => game.snake.redirect(.{ .x =  0, .y =  1 }),
                        'k' => game.snake.redirect(.{ .x =  0, .y = -1 }),
                        'l' => game.snake.redirect(.{ .x =  1, .y =  0 }),
                        // zig fmt: on
                        else => {},
                    },
                    else => {},
                },
                .resize => {
                    game.deinit();
                    try renderer.frame().resize(event.resize.width, event.resize.height);
                    game = try Game.initRandom(allocator, renderer.frame().area, 20);
                    continue;
                },
            }
        }

        try game.tick();
        if (!game.validate())
            break;

        std.time.sleep(16 * std.time.ns_per_ms / 1);
    }

    _ = try fuizon.backend.event.read();
}

const Renderer = struct {
    frames: [2]Frame,

    pub fn init(allocator: std.mem.Allocator) Renderer {
        var renderer: Renderer = undefined;
        renderer.frames[0] = Frame.init(allocator);
        renderer.frames[1] = Frame.init(allocator);
        return renderer;
    }

    pub fn initFullscreen(allocator: std.mem.Allocator, writer: anytype) !Renderer {
        var renderer = Renderer.init(allocator);
        errdefer renderer.deinit();

        const render_area = try fuizon.backend.area.fullscreen().render(writer);
        const render_frame: *Frame = renderer.frame();

        try render_frame.resize(render_area.width, render_area.height);
        render_frame.moveTo(render_area.origin.x, render_area.origin.y);

        return renderer;
    }

    pub fn deinit(self: Renderer) void {
        self.frames[0].deinit();
        self.frames[1].deinit();
    }

    pub fn frame(self: anytype) switch (@TypeOf(self)) {
        *const Renderer => *const Frame,
        *Renderer => *Frame,
        else => unreachable,
    } {
        return &self.frames[0];
    }

    pub fn save(self: *Renderer) std.mem.Allocator.Error!void {
        self.frames[1].copy(self.frames[0]);
    }

    pub fn render(self: Renderer, writer: anytype) !void {
        try fuizon.backend.frame.render(writer, self.frames[0], self.frames[1]);
    }
};

const GameRenderer = struct {
    pub fn render(game: Game, frame: *Frame) void {
        frame.fill(game.area, .{ .width = 1, .content = ' ', .style = .{} });
        for (game.snake.body.items) |item| {
            frame.index(@intCast(item.position.x + 0), @intCast(item.position.y)).style.background_color = .blue;
            frame.index(@intCast(item.position.x + 1), @intCast(item.position.y)).style.background_color = .blue;
        }
        for (game.apple_list.items) |item| {
            frame.index(@intCast(item.position.x + 0), @intCast(item.position.y)).style.background_color = .red;
            frame.index(@intCast(item.position.x + 1), @intCast(item.position.y)).style.background_color = .red;
        }
    }
};

//

const Game = struct {
    score: u64,
    area: Area,
    snake: Snake,
    apple_list: std.ArrayList(Apple),

    pub fn init(allocator: std.mem.Allocator, area: Area) std.mem.Allocator.Error!Game {
        var game: Game = undefined;
        game.score = 0;
        game.area = area;
        game.snake = try Snake.init(allocator, .{ .x = area.origin.x, .y = area.origin.y }, .{ .x = 1, .y = 0 });
        errdefer game.snake.deinit();
        game.apple_list = std.ArrayList(Apple).init(allocator);
        return game;
    }

    pub fn initRandom(
        allocator: std.mem.Allocator,
        area: Area,
        napples: usize,
    ) std.mem.Allocator.Error!Game {
        var game = try Game.init(allocator, area);
        errdefer game.deinit();
        game.area = area;
        for (0..napples) |_|
            try game.apple_list.append(Apple.random(area));
        return game;
    }

    pub fn deinit(self: Game) void {
        self.snake.deinit();
        self.apple_list.deinit();
    }

    //

    pub fn tick(self: *Game) !void {
        self.snake.tick();
        for (self.apple_list.items) |*apple| {
            if (self.snake.body.items[0].position.x == apple.position.x and
                self.snake.body.items[0].position.y == apple.position.y)
            {
                try self.snake.grow(self.*);
                self.score += 1;
                apple.* = Apple.random(self.area);
            }
        }
    }

    pub fn validate(self: Game) bool {
        return self.snake.validate(self);
    }
};

const Snake = struct {
    body: std.ArrayList(SnakeBodyPart),

    pub fn init(
        allocator: std.mem.Allocator,
        position: Position,
        direction: Direction,
    ) std.mem.Allocator.Error!Snake {
        var snake: Snake = undefined;
        snake.body = std.ArrayList(SnakeBodyPart).init(allocator);
        errdefer snake.body.deinit();
        try snake.body.insert(0, .{ .position = position, .direction = direction });
        return snake;
    }

    pub fn deinit(self: Snake) void {
        self.body.deinit();
    }

    //

    pub fn grow(self: *Snake, game: Game) std.mem.Allocator.Error!void {
        std.debug.assert(self.body.items.len > 0);

        const tail = &self.body.items[self.body.items.len - 1];
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
            if (x >= game.area.left()   and
                x <  game.area.right()  and
                y >= game.area.top()    and
                y <  game.area.bottom()) 
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

        try self.append(new_direction.?);
    }

    pub fn append(self: *Snake, direction: Direction) std.mem.Allocator.Error!void {
        std.debug.assert(self.body.items.len > 0);
        var position = self.body.items[self.body.items.len - 1].position;
        position.x -= direction.x * 2;
        position.y -= direction.y;
        try self.body.append(.{ .position = position, .direction = direction });
    }

    //

    pub fn redirect(self: *Snake, direction: Direction) void {
        std.debug.assert(self.body.items.len > 0);
        self.body.items[0].direction = direction;
    }

    //

    pub fn tick(self: *Snake) void {
        std.debug.assert(self.body.items.len > 0);
        var index = self.body.items.len - 1;
        while (index > 0) : (index -= 1)
            self.body.items[index] = self.body.items[index - 1];
        self.body.items[0].position.x += self.body.items[0].direction.x * 2;
        self.body.items[0].position.y += self.body.items[0].direction.y;
    }

    pub fn validate(self: Snake, game: Game) bool {
        if (self.body.items.len == 0)
            return false;

        for (self.body.items) |item| {
            // zig fmt: off
            if (item.position.x <  game.area.left()    or
                item.position.x >= game.area.right()   or
                item.position.y <  game.area.top()     or
                item.position.y >= game.area.bottom()) return false;
            // zig fmt: on
        }

        for (0..self.body.items.len) |i| {
            for (i + 1..self.body.items.len) |j| {
                const lhs = &self.body.items[i];
                const rhs = &self.body.items[j];

                if (lhs.position.x == rhs.position.x and
                    lhs.position.y == rhs.position.y)
                    return false;
            }
        }

        return true;
    }

    //
};

const SnakeBodyPart = struct {
    position: Position,
    direction: Direction,
};

const Apple = struct {
    position: Position,

    pub fn random(area: Area) Apple {
        const x = randomEvenInRangeLessThan(i17, 0, @intCast(area.width)) + area.left();
        const y = randomEvenInRangeLessThan(i17, 0, @intCast(area.height)) + area.top();

        return .{ .position = .{ .x = x, .y = y } };
    }

    fn randomEvenInRangeLessThan(comptime T: type, at_least: T, less_than: T) T {
        const r = std.crypto.random.intRangeLessThan(T, at_least, less_than);
        if (@mod(r, 2) == 0) return r;
        if (r + 1 < less_than) return r + 1;
        if (r - 1 >= at_least) return r - 1;
        unreachable;
    }
};
