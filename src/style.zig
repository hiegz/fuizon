const Attributes = @import("attributes.zig").Attributes;
const Color = @import("color.zig").Color;

// zig fmt: off

pub const Style = struct {
    foreground_color: Color = .default,
    background_color: Color = .default,
    attributes:  Attributes = Attributes.none,
};
