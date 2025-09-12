const std = @import("std");
const c = @import("headers.zig").c;
const fuizon = @import("fuizon.zig");
const Attribute = fuizon.Attribute;
const Attributes = fuizon.Attributes;
const Alignment = fuizon.Alignment;
const Color = fuizon.Color;

pub const Style = struct {
    foreground_color: ?Color = .default,
    background_color: ?Color = .default,

    attributes: Attributes = Attributes.none,
};
