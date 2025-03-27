const std = @import("std");
const mod = @import("../mod.zig");
const fuizon = @import("fuizon");

const Game = mod.Game;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Text = fuizon.text.Text;
const Paragraph = fuizon.widgets.paragraph.Paragraph;
const Attributes = fuizon.style.Attributes;

pub const GameStateView = struct {
    allocator: std.mem.Allocator,
    paragraph: Paragraph,
    text: Text,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!GameStateView {
        var view = @as(GameStateView, undefined);
        view.allocator = allocator;
        view.paragraph = Paragraph{};

        view.text = Text.init(allocator);
        errdefer view.text.deinit();

        try view.text.addLine();
        view.text.lines()[0].alignment = .center;
        try view.text.lines()[0].appendSpan("", .{ .attributes = Attributes.join(&.{.bold}) });

        return view;
    }

    pub fn deinit(self: GameStateView) void {
        self.text.deinit();
    }

    pub fn load(self: *GameStateView, game: Game) std.mem.Allocator.Error!void {
        const span = &self.text.lines()[0].spans()[0];

        switch (game.state) {
            .game_started => {
                span.style.foreground_color = .black;
                span.style.background_color = .green;
                try span.setContent(" Game Started ");
            },
            .game_paused => {
                span.style.foreground_color = .black;
                span.style.background_color = .{ .ansi = .{ .value = 229 } };
                try span.setContent(" Game Paused ");
            },
            .game_over => {
                span.style.foreground_color = .white;
                span.style.background_color = .red;
                try span.setContent(" Game Over ");
            },
        }
    }

    pub fn heightForWidth(self: GameStateView, width: u16) std.mem.Allocator.Error!u16 {
        return self.paragraph.heightForWidth(self.allocator, self.text, width);
    }

    pub fn render(
        self: GameStateView,
        frame: *Frame,
        area: Area,
    ) std.mem.Allocator.Error!void {
        frame.fill(area, .{ .width = 1, .content = ' ', .style = .{} });
        return self.paragraph.render(self.allocator, self.text, frame, area);
    }
};
