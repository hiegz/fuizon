const std = @import("std");
const mod = @import("../mod.zig");
const fuizon = @import("fuizon");

const GameScoreView = mod.GameScoreView;
const ApplePositionView = mod.ApplePositionView;
const MapSizeView = mod.MapSizeView;
const SnakePositionView = mod.SnakePositionView;
const GameStateView = mod.GameStateView;

const Game = mod.Game;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Text = fuizon.text.Text;
const Paragraph = fuizon.widgets.paragraph.Paragraph;
const StackLayout = fuizon.layout.Stack;
const StackLayoutConstraint = fuizon.layout.StackConstraint;

pub const DashboardView = struct {
    layout: StackLayout,

    // zig fmt: off
    game_score_view:     GameScoreView,
    apple_position_view: ApplePositionView,
    map_size_view:       MapSizeView,
    snake_position_view: SnakePositionView,
    game_state_view:     GameStateView,
    // zig fmt: on

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!DashboardView {
        var view: DashboardView = undefined;

        view.layout = try StackLayout.horizontal(allocator, &.{
            StackLayoutConstraint.fill(1),
            StackLayoutConstraint.fill(1),
            StackLayoutConstraint.fill(1),
            StackLayoutConstraint.fill(1),
            StackLayoutConstraint.fill(1),
        });
        errdefer view.layout.deinit();

        view.game_score_view = try GameScoreView.init(allocator);
        errdefer view.game_score_view.deinit();

        view.apple_position_view = try ApplePositionView.init(allocator);
        errdefer view.apple_position_view.deinit();

        view.map_size_view = try MapSizeView.init(allocator);
        errdefer view.map_size_view.deinit();

        view.snake_position_view = try SnakePositionView.init(allocator);
        errdefer view.snake_position_view.deinit();

        view.game_state_view = try GameStateView.init(allocator);
        errdefer view.game_state_view.deinit();

        return view;
    }

    pub fn deinit(self: DashboardView) void {
        self.layout.deinit();
        self.game_score_view.deinit();
        self.apple_position_view.deinit();
        self.map_size_view.deinit();
        self.snake_position_view.deinit();
        self.game_state_view.deinit();
    }

    pub fn load(self: *DashboardView, game: Game) std.mem.Allocator.Error!void {
        try self.game_score_view.load(game);
        try self.apple_position_view.load(game);
        try self.map_size_view.load(game);
        try self.snake_position_view.load(game);
        try self.game_state_view.load(game);
    }

    pub fn heightForWidth(self: *DashboardView, width: u16) std.mem.Allocator.Error!u16 {
        try self.layout.setWidth(width);

        try self.layout.items[0].suggestMinHeight(try self.game_score_view.heightForWidth(self.layout.items[0].width()));
        try self.layout.items[1].suggestMinHeight(try self.apple_position_view.heightForWidth(self.layout.items[1].width()));
        try self.layout.items[2].suggestMinHeight(try self.map_size_view.heightForWidth(self.layout.items[2].width()));
        try self.layout.items[3].suggestMinHeight(try self.snake_position_view.heightForWidth(self.layout.items[3].width()));
        try self.layout.items[4].suggestMinHeight(try self.game_state_view.heightForWidth(self.layout.items[4].width()));

        self.layout.optimizeHeight();
        return self.layout.height();
    }

    pub fn render(self: *DashboardView, frame: *Frame, area: Area) std.mem.Allocator.Error!void {
        try self.layout.fit(area);

        try self.game_score_view.render(frame, self.layout.items[0].area());
        try self.apple_position_view.render(frame, self.layout.items[1].area());
        try self.map_size_view.render(frame, self.layout.items[2].area());
        try self.snake_position_view.render(frame, self.layout.items[3].area());
        try self.game_state_view.render(frame, self.layout.items[4].area());
    }
};
