const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Text = fuizon.text.Text;
const Paragraph = fuizon.widgets.paragraph.Paragraph;

const GUIDE = "h - move left, j - move down, k - move up, l - move right, r - restart, p - toggle pause, q - quit";

pub const GuideView = struct {
    allocator: std.mem.Allocator,
    paragraph: Paragraph,
    text: Text,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!GuideView {
        var view = @as(GuideView, undefined);
        view.allocator = allocator;
        view.paragraph = Paragraph{};
        view.text = Text.init(allocator);
        errdefer view.text.deinit();
        try view.text.addLine();
        try view.text.lines()[0].appendSpan(GUIDE, .{});
        view.text.lines()[0].alignment = .center;
        return view;
    }

    pub fn deinit(self: GuideView) void {
        self.text.deinit();
    }

    pub fn heightForWidth(self: GuideView, width: u16) std.mem.Allocator.Error!u16 {
        return self.paragraph.heightForWidth(self.allocator, self.text, width);
    }

    pub fn render(self: GuideView, frame: *Frame, area: Area) std.mem.Allocator.Error!void {
        return self.paragraph.render(self.allocator, self.text, frame, area);
    }
};
