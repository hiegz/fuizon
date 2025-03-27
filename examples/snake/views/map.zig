const std = @import("std");
const mod = @import("../mod.zig");
const fuizon = @import("fuizon");

const Apple = mod.Apple;
const Snake = mod.Snake;
const SnakePart = mod.SnakePart;
const Game = mod.Game;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Borders = fuizon.widgets.container.Borders;
const Container = fuizon.widgets.container.Container;

pub const MapView = struct {
    // zig fmt: off
    allocator:   std.mem.Allocator,
    container:   Container,
    game_width:  u16,
    game_height: u16,
    snake:       Snake,
    apple:       Apple,
    // zig fmt: on

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!MapView {
        var view = @as(MapView, undefined);

        view.allocator = allocator;

        view.container = Container{};
        view.container.borders = Borders.all;
        view.container.border_type = .thick;

        view.game_width = 0;
        view.game_height = 0;

        view.snake = try Snake.init(allocator, .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 });
        errdefer view.snake.deinit();

        view.apple = .{ .position = .{ .x = 0, .y = 0 } };

        return view;
    }

    pub fn deinit(self: MapView) void {
        self.snake.deinit();
    }

    pub fn load(self: *MapView, game: Game) std.mem.Allocator.Error!void {
        if (game.state == .game_over)
            return;

        var body = std.ArrayList(SnakePart).init(self.allocator);
        errdefer body.deinit();
        try body.ensureTotalCapacity(game.snake.body.items.len);
        for (game.snake.body.items) |body_part|
            try body.append(body_part);

        errdefer comptime unreachable;

        self.snake.body.deinit();
        self.snake.body = body;
        self.apple = game.apple;
        self.game_width = game.width;
        self.game_height = game.height;
    }

    pub fn width(self: MapView) u16 {
        // zig fmt: off
        return self.game_width
            + self.container.margin_left + self.container.margin_right
            + (if (self.container.borders.contain(&.{.left}))  @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.right})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    pub fn height(self: MapView) u16 {
        // zig fmt: off
        return self.game_height
            + self.container.margin_top + self.container.margin_bottom
            + (if (self.container.borders.contain(&.{.top}))    @as(u16, 1) else @as(u16, 0))
            + (if (self.container.borders.contain(&.{.bottom})) @as(u16, 1) else @as(u16, 0));
        // zig fmt: on
    }

    pub fn render(self: MapView, frame: *Frame, x: u16, y: u16) void {
        const view_area = Area{ .width = self.width(), .height = self.height(), .origin = .{ .x = x, .y = y } };
        const game_area = self.container.inner(view_area);

        self.container.render(frame, view_area);
        frame.fill(game_area, .{ .width = 1, .content = ' ', .style = .{} });

        SnakeRenderer.render(self.snake, frame, game_area.left(), game_area.top());
        AppleRenderer.render(self.apple, frame, game_area.left(), game_area.top());
    }
};

const SnakeRenderer = struct {
    fn render(snake: Snake, frame: *Frame, offset_x: u16, offset_y: u16) void {
        for (snake.body.items) |item| {
            const x = offset_x + item.position.x;
            const y = offset_y + item.position.y;

            frame.index(@intCast(x + 0), @intCast(y)).style.background_color = .blue;
            frame.index(@intCast(x + 1), @intCast(y)).style.background_color = .blue;
        }
    }
};

const AppleRenderer = struct {
    fn render(apple: Apple, frame: *Frame, offset_x: u16, offset_y: u16) void {
        const x = offset_x + apple.position.x;
        const y = offset_y + apple.position.y;

        frame.index(@intCast(x + 0), @intCast(y)).style.background_color = .red;
        frame.index(@intCast(x + 1), @intCast(y)).style.background_color = .red;
    }
};
