const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Text = fuizon.text.Text;
const Paragraph = fuizon.widgets.paragraph.Paragraph;

pub const FallbackView = struct {
    allocator: std.mem.Allocator,
    paragraph: Paragraph,
    text: Text,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!FallbackView {
        var view = @as(FallbackView, undefined);

        view.allocator = allocator;
        view.paragraph = Paragraph{};
        view.text = Text.init(allocator);
        errdefer view.text.deinit();
        try view.text.addLine();
        try view.text.addLine();
        try view.text.addLine();
        try view.text.addLine();

        try view.text.lines()[0].appendSpan(" Ooops... ", .{ .background_color = .red, .foreground_color = .white });
        view.text.lines()[0].alignment = .center;

        try view.text.lines()[2].appendSpan("Seems like the screen is too small to render the game!", .{});
        view.text.lines()[2].alignment = .center;

        try view.text.lines()[3].appendSpan("Try resizing the terminal or decreasing the font size", .{});
        view.text.lines()[3].alignment = .center;

        return view;
    }

    pub fn deinit(self: FallbackView) void {
        self.text.deinit();
    }

    pub fn heightForWidth(self: FallbackView, width: u16) std.mem.Allocator.Error!u16 {
        return self.paragraph.heightForWidth(self.allocator, self.text, width);
    }

    pub fn render(self: FallbackView, frame: *Frame, area: Area) std.mem.Allocator.Error!void {
        return self.paragraph.render(self.allocator, self.text, frame, area);
    }
};
