const std = @import("std");
const mod = @import("../mod.zig");
const fuizon = @import("fuizon");

const DashboardView = mod.DashboardView;
const MapView = mod.MapView;
const GuideView = mod.GuideView;

const Game = mod.Game;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const StackLayout = fuizon.layout.Stack;
const StackLayoutConstraint = fuizon.layout.StackConstraint;

pub const GameView = struct {
    layout: StackLayout,

    // zig fmt: off
    dashboard_view: DashboardView,
    map_view:       MapView,
    guide_view:     GuideView,
    // zig fmt: on

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!GameView {
        var view: GameView = undefined;

        view.layout = try StackLayout.vertical(allocator, &.{
            StackLayoutConstraint.auto(),
            StackLayoutConstraint.auto(),
            StackLayoutConstraint.auto(),
        });
        errdefer view.layout.deinit();

        view.dashboard_view = try DashboardView.init(allocator);
        errdefer view.dashboard_view.deinit();

        view.map_view = try MapView.init(allocator);
        errdefer view.map_view.deinit();

        view.guide_view = try GuideView.init(allocator);
        errdefer view.guide_view.deinit();

        return view;
    }

    pub fn deinit(self: GameView) void {
        self.layout.deinit();
        self.dashboard_view.deinit();
        self.map_view.deinit();
        self.guide_view.deinit();
    }

    pub fn load(self: *GameView, game: Game) std.mem.Allocator.Error!void {
        try self.dashboard_view.load(game);
        try self.map_view.load(game);

        self.layout.optimizeWidth();
        self.layout.optimizeHeight();

        try self.layout.items[1].suggestWidth(self.map_view.width());
        try self.layout.items[1].suggestHeight(self.map_view.height());

        try self.layout.items[0].suggestHeight(try self.dashboard_view.heightForWidth(self.layout.items[0].width()));
        try self.layout.items[2].suggestHeight(try self.guide_view.heightForWidth(self.layout.items[2].width()));
    }

    pub fn width(self: GameView) u16 {
        return self.layout.width();
    }

    pub fn height(self: GameView) u16 {
        return self.layout.height();
    }

    pub fn within(self: GameView, area: Area) bool {
        return self.width() <= area.width and self.height() <= area.height;
    }

    pub fn render(
        self: *GameView,
        frame: *Frame,
        x: u16,
        y: u16,
    ) std.mem.Allocator.Error!void {
        try self.layout.setOrigin(x, y);

        try self.dashboard_view.render(frame, self.layout.items[0].area());
        self.map_view.render(frame, self.layout.items[1].left(), self.layout.items[1].top());
        try self.guide_view.render(frame, self.layout.items[2].area());
    }
};
