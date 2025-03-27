const std = @import("std");
const mod = @import("../mod.zig");
const fuizon = @import("fuizon");

const Game = mod.Game;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Text = fuizon.text.Text;
const Paragraph = fuizon.widgets.paragraph.Paragraph;

pub const MapSizeView = struct {
    allocator: std.mem.Allocator,
    paragraph: Paragraph,
    text: Text,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!MapSizeView {
        var view = @as(MapSizeView, undefined);
        view.allocator = allocator;
        view.paragraph = Paragraph{};

        view.text = Text.init(allocator);
        errdefer view.text.deinit();

        try view.text.addLine();
        view.text.lines()[0].alignment = .center;
        try view.text.lines()[0].appendSpan("Map Size", .{});
        try view.text.lines()[0].appendSpan(": ", .{});
        try view.text.lines()[0].appendSpan("", .{});

        return view;
    }

    pub fn deinit(self: MapSizeView) void {
        self.text.deinit();
    }

    pub fn load(self: *MapSizeView, game: Game) std.mem.Allocator.Error!void {
        const data = try std.fmt.allocPrint(self.allocator, "{d}x{d}", .{ game.width, game.height });
        defer self.allocator.free(data);

        try self.text.lines()[0].spans()[2].setContent(data);
    }

    pub fn heightForWidth(self: MapSizeView, width: u16) std.mem.Allocator.Error!u16 {
        return self.paragraph.heightForWidth(self.allocator, self.text, width);
    }

    pub fn render(
        self: MapSizeView,
        frame: *Frame,
        area: Area,
    ) std.mem.Allocator.Error!void {
        frame.fill(area, .{ .width = 1, .content = ' ', .style = .{} });
        return self.paragraph.render(self.allocator, self.text, frame, area);
    }
};
