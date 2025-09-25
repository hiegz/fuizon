const std = @import("std");
const terminal = @import("terminal.zig");
const Renderer = @import("renderer.zig").Renderer;

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
pub const Buffer = @import("buffer.zig").Buffer;
pub const Character = @import("character.zig").Character;
pub const Viewport = @import("viewport.zig").Viewport;
pub const Span = @import("span.zig").Span;
pub const Stack = @import("stack.zig").Stack;
pub const StackConstraint = @import("stack_constraint.zig").StackConstraint;
pub const StackDirection = @import("stack_direction.zig").StackDirection;
pub const StackItem = @import("stack_item.zig").StackItem;
pub const Container = @import("container.zig").Container;
pub const Text = @import("text.zig").Text;
pub const TextAlignment = @import("text_alignment.zig").TextAlignment;
pub const Border = @import("border.zig").Border;
pub const Borders = @import("borders.zig").Borders;
pub const BorderType = @import("border_type.zig").BorderType;
pub const Spacing = @import("spacing.zig").Spacing;
pub const Widget = @import("widget.zig").Widget;
pub const getScreenSize = terminal.getScreenSize;

pub var viewport: Viewport = .fullscreen;

var gpa: std.mem.Allocator = undefined;
var buffer: Buffer = undefined;
var renderer: Renderer = undefined;
var rendering: bool = undefined;

pub fn init() error{ NotATerminal, Unexpected }!void {
    gpa = std.heap.c_allocator;
    buffer = .init();
    renderer = .init();
    rendering = false;

    // hide the cursor in the first frame
    // (unless the user provides a render position)
    renderer.last_buffer.cursor = .{ .x = 0, .y = 0 };

    try terminal.enableRawMode();
}

pub fn deinit() error{ OutOfMemory, NotATerminal, RenderFailed, Unexpected }!void {
    _ = try nextFrame();
    buffer.cursor = .{ .x = 0, .y = 0 };
    try render();

    buffer.deinit(gpa);
    renderer.deinit(gpa);

    try terminal.disableRawMode();
}

pub fn nextFrame() error{ NotATerminal, OutOfMemory, Unexpected }!*Buffer {
    // zig fmt: off
    const screen = try terminal.getScreenSize();
    const width  = screen.width;
    const height = switch (viewport) {
        .fixed => |h| @min(h, screen.height),
        .fullscreen => screen.height,
    };
    // zig fmt: on

    if (width != buffer.width() or height != buffer.height())
        try buffer.resize(gpa, .init(width, height));

    // clear the buffer
    for (buffer.characters) |*char| {
        char.* = .{};
    }

    return &buffer;
}

pub fn render() Renderer.Error!void {
    try renderer.render(gpa, &buffer);
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
    _ = @import("renderer.zig");
    _ = @import("rgb.zig");
    _ = @import("spacing.zig");
    _ = @import("span.zig");
    _ = @import("stack.zig");
    _ = @import("stack_constraint.zig");
    _ = @import("stack_direction.zig");
    _ = @import("stack_item.zig");
    _ = @import("style.zig");
    _ = @import("terminal.zig");
    _ = @import("text.zig");
    _ = @import("text_alignment.zig");
    _ = @import("viewport.zig");
    _ = @import("vt.zig");
    _ = @import("widget.zig");
    _ = @import("windows.zig");
}
