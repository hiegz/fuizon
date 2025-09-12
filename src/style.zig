const fuizon = @import("fuizon.zig");
const Color = fuizon.Color;
const Attributes = fuizon.Attributes;

// zig fmt: off

pub const Style = struct {
    foreground_color: Color = .default,
    background_color: Color = .default,
    attributes:  Attributes = Attributes.none,
};
