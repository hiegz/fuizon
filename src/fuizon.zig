const terminal = @import("terminal.zig");

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
pub const Stack = @import("stack.zig").Stack;
pub const StackConstraint = @import("stack_constraint.zig").StackConstraint;
pub const StackDirection = @import("stack_direction.zig").StackDirection;
pub const StackItem = @import("stack_item.zig").StackItem;
pub const Container = @import("container.zig").Container;
pub const ContainerTitle = @import("container_title.zig").ContainerTitle;
pub const Text = @import("text.zig").Text;
pub const TextAlignment = @import("text_alignment.zig").TextAlignment;
pub const TextOpts = @import("text_opts.zig").TextOpts;
pub const Border = @import("border.zig").Border;
pub const Borders = @import("borders.zig").Borders;
pub const BorderType = @import("border_type.zig").BorderType;
pub const Margin = @import("margin.zig").Margin;
pub const Padding = @import("padding.zig").Padding;
pub const getScreenSize = terminal.getScreenSize;

pub fn init() error{ NotATerminal, Unexpected }!void {
    try terminal.enableRawMode();
}

pub fn deinit() error{ NotATerminal, Unexpected }!void {
    try terminal.disableRawMode();
}

test "fuizon" {
    _ = @import("ansi.zig");
    _ = @import("area.zig");
    _ = @import("attribute.zig");
    _ = @import("attributes.zig");
    _ = @import("border.zig");
    _ = @import("border_set.zig");
    _ = @import("border_type.zig");
    _ = @import("borders.zig");
    _ = @import("buffer.zig");
    _ = @import("character.zig");
    _ = @import("color.zig");
    _ = @import("container.zig");
    _ = @import("container_title.zig");
    _ = @import("coordinate.zig");
    _ = @import("dimensions.zig");
    _ = @import("fuizon.zig");
    _ = @import("input.zig");
    _ = @import("input_parser.zig");
    _ = @import("key.zig");
    _ = @import("key_code.zig");
    _ = @import("key_modifier.zig");
    _ = @import("key_modifiers.zig");
    _ = @import("margin.zig");
    _ = @import("padding.zig");
    _ = @import("queue.zig");
    _ = @import("rgb.zig");
    _ = @import("span.zig");
    _ = @import("stack.zig");
    _ = @import("stack_constraint.zig");
    _ = @import("stack_direction.zig");
    _ = @import("stack_item.zig");
    _ = @import("style.zig");
    _ = @import("terminal.zig");
    _ = @import("text.zig");
    _ = @import("text_alignment.zig");
    _ = @import("text_opts.zig");
    _ = @import("vt.zig");
    _ = @import("widget.zig");
    _ = @import("windows.zig");
}
