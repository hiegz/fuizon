const std = @import("std");
const mod = @import("snake/mod.zig");
const xev = @import("xev");
const fuizon = @import("fuizon");

const Clock = mod.Clock;
const Screen = mod.Screen;
const Apple = mod.Apple;
const Game = mod.Game;
const GameView = mod.GameView;
const FallbackView = mod.FallbackView;

var loop: xev.Loop = undefined;
var game_clock: Clock = undefined;
var input_clock: Clock = undefined;

var screen: Screen = undefined;
var view: GameView = undefined;
var game: Game = undefined;

var fallback: FallbackView = undefined;

var direction: mod.Direction = undefined;

fn poll() !void {
    if (!try fuizon.backend.event.poll())
        return;

    switch (try fuizon.backend.event.read()) {
        .key => |kev| switch (kev.code) {
            .char => |char| switch (char) {
                'q' => loop.stop(),
                'h' => {
                    if (game.snake.body.items[0].direction.x == 0)
                        direction = .{ .x = -1, .y = 0 };
                },
                'j' => {
                    if (game.snake.body.items[0].direction.y == 0)
                        direction = .{ .x = 0, .y = 1 };
                },
                'k' => {
                    if (game.snake.body.items[0].direction.y == 0)
                        direction = .{ .x = 0, .y = -1 };
                },
                'l' => {
                    if (game.snake.body.items[0].direction.x == 0)
                        direction = .{ .x = 1, .y = 0 };
                },
                'r' => {
                    game.apple = Apple.random(game.width, game.height);
                    game.snake.body.shrinkAndFree(1);
                    game.snake.body.items[0].position.x = 0;
                    game.snake.body.items[0].position.y = 0;
                    direction.x = 1;
                    direction.y = 0;
                    game.run();
                    game_clock.run();
                    try redraw();
                },
                'p' => {
                    if (game.paused()) {
                        game.run();
                        game_clock.run();
                    } else if (game.running()) {
                        game.pause();
                        game_clock.pause();
                    }
                    try redraw();
                },
                else => {},
            },
            else => {},
        },
        .resize => |d| {
            try resize(d.width, d.height);
            try redraw();
        },
    }
}

fn resize(width: u16, height: u16) !void {
    try screen.frame().resize(width, height);
    try screen.clear();

    if (!game.over()) {
        if (!view.within(screen.frame().area)) {
            game.pause();
            game_clock.pause();
        }
    }
}

fn redraw() !void {
    screen.frame().reset();

    try view.load(game);
    if (view.within(screen.frame().area)) {
        const render_area =
            mod.utils.center(screen.frame().area, view.width(), view.height());

        try view.render(
            screen.frame(),
            render_area.origin.x,
            render_area.origin.y,
        );
    } else {
        const render_area =
            mod.utils.center(
                screen.frame().area,
                screen.frame().area.width,
                try fallback.heightForWidth(screen.frame().area.width),
            );

        try fallback.render(screen.frame(), render_area);
    }

    try screen.render();
    try screen.flush();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    screen = try Screen.init(allocator);
    defer screen.deinit();

    try fuizon.backend.raw_mode.enable();
    defer fuizon.backend.raw_mode.disable() catch {};

    game = try Game.init(allocator, 120, 30);
    defer game.deinit();
    game.apple = Apple.random(game.width, game.height);
    direction = game.snake.body.items[0].direction;

    view = try GameView.init(allocator);
    defer view.deinit();

    fallback = try FallbackView.init(allocator);
    defer fallback.deinit();

    loop = try xev.Loop.init(.{});
    defer loop.deinit();

    game_clock = try Clock.init(&loop, 150, (struct {
        fn callback() void {
            game.snake.redirect(direction);
            // zig fmt: off
            game.tick() catch @panic("Ooops...");
            redraw()    catch @panic("Ooops...");
            // zig fmt: on
        }
    }).callback);
    defer game_clock.deinit();
    game_clock.run();
    game.run();

    input_clock = try Clock.init(&loop, 20, (struct {
        fn callback() void {
            poll() catch @panic("Ooops...");
        }
    }).callback);
    defer input_clock.deinit();
    input_clock.run();

    try resize(screen.frame().area.width, screen.frame().area.height);
    try redraw();

    try loop.run(.until_done);
}
