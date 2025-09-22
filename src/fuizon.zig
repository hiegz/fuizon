const terminal = @import("terminal.zig");

pub const Alignment = @import("alignment.zig").Alignment;
pub const Area = @import("area.zig").Area;
pub const Attribute = @import("attribute.zig").Attribute;
pub const Attributes = @import("attributes.zig").Attributes;
pub const Color = @import("color.zig").Color;
pub const Ansi = @import("ansi.zig").Ansi;
pub const Rgb = @import("rgb.zig").Rgb;
pub const Coordinate = @import("coordinate.zig").Coordinate;
pub const Dimensions = @import("dimensions.zig").Dimensions;
pub const Input = @import("input.zig").Input;
pub const InputParser = @import("input_parser.zig").InputParser;
pub const Key = @import("key.zig").Key;
pub const KeyCode = @import("key_code.zig").KeyCode;
pub const KeyModifier = @import("key_modifier.zig").KeyModifier;
pub const KeyModifiers = @import("key_modifiers.zig").KeyModifiers;
pub const Style = @import("style.zig").Style;
pub const Span = @import("span.zig").Span;
pub const Text = @import("text.zig").Text;
pub const getScreenSize = terminal.getScreenSize;

pub fn init() error{ NotATerminal, Unexpected }!void {
    try terminal.enableRawMode();
}

pub fn deinit() error{ NotATerminal, Unexpected }!void {
    try terminal.disableRawMode();
}

test "fuizon" {
    _ = @import("alignment.zig");
    _ = @import("ansi.zig");
    _ = @import("area.zig");
    _ = @import("attribute.zig");
    _ = @import("attributes.zig");
    _ = @import("buffer.zig");
    _ = @import("character.zig");
    _ = @import("color.zig");
    _ = @import("coordinate.zig");
    _ = @import("dimensions.zig");
    _ = @import("fuizon.zig");
    _ = @import("input.zig");
    _ = @import("input_parser.zig");
    _ = @import("key.zig");
    _ = @import("key_code.zig");
    _ = @import("key_modifier.zig");
    _ = @import("key_modifiers.zig");
    _ = @import("queue.zig");
    _ = @import("rgb.zig");
    _ = @import("span.zig");
    _ = @import("style.zig");
    _ = @import("terminal.zig");
    _ = @import("text.zig");
    _ = @import("vt.zig");
    _ = @import("widget.zig");
    _ = @import("windows.zig");
}
