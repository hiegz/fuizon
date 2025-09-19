const attribute = @import("attribute.zig");
const color = @import("color.zig");
const key = @import("key.zig");
const terminal = @import("terminal.zig");

pub const Alignment = @import("alignment.zig").Alignment;
pub const Area = @import("area.zig").Area;
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const RgbColor = color.RgbColor;
pub const Coordinate = @import("coordinate.zig").Coordinate;
pub const Dimensions = @import("dimensions.zig").Dimensions;
pub const Input = @import("input.zig").Input;
pub const InputParser = @import("input_parser.zig");
pub const Key = key.Key;
pub const KeyCode = key.KeyCode;
pub const KeyModifier = key.KeyModifier;
pub const KeyModifiers = key.KeyModifiers;
pub const Style = @import("style.zig").Style;

pub fn init() error{ NotATerminal, Unexpected }!void {
    try terminal.enableRawMode();
}

pub fn deinit() error{ NotATerminal, Unexpected }!void {
    try terminal.disableRawMode();
}

test "fuizon" {
    _ = @import("alignment.zig");
    _ = @import("area.zig");
    _ = @import("attribute.zig");
    _ = @import("buffer.zig");
    _ = @import("color.zig");
    _ = @import("coordinate.zig");
    _ = @import("dimensions.zig");
    _ = @import("fuizon.zig");
    _ = @import("input.zig");
    _ = @import("input_parser.zig");
    _ = @import("key.zig");
    _ = @import("queue.zig");
    _ = @import("style.zig");
    _ = @import("terminal.zig");
    _ = @import("vt.zig");
    _ = @import("windows.zig");
}
