const Style = @import("style.zig").Style;

pub const Span = struct {
    content: []const u8 = "",
    style: Style = .{},

    pub fn raw(content: []const u8) Span {
        return .{ .content = content, .style = .{} };
    }

    pub fn styled(content: []const u8, style: Style) Span {
        return .{ .content = content, .style = style };
    }
};
