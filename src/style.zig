const Attributes = @import("attributes.zig").Attributes;
const Color = @import("color.zig").Color;

// zig fmt: off

pub const Style = struct {
    foreground_color: Color = .default,
    background_color: Color = .default,
    attributes:  Attributes = Attributes.none,

    pub fn init(foreground: Color, background: Color, attributes: Attributes) Style {
        return .{ .foreground_color = foreground, .background_color = background, .attributes = attributes };
    }
};
