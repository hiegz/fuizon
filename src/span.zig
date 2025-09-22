const Style = @import("style.zig").Style;

pub const Span = struct {
    content: []const u8 = "",
    style: Style = .{},

    pub fn init(content: []const u8, style: Style) Span {
        return .{ .content = content, .style = style };
    }
};
