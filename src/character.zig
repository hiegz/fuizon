const Style = @import("style.zig").Style;

pub const Character = struct {
    value: u21 = ' ',
    style: Style = .{},

    pub fn init(value: u21, style: Style) Character {
        return .{ .value = value, .style = style };
    }
};
