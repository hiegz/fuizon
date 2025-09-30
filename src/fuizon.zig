const std = @import("std");
const builtin = @import("builtin");
const vt = @import("vt.zig");
const Terminal = @import("terminal.zig").Terminal;
const Renderer = @import("renderer.zig").Renderer;

pub const Area = @import("area.zig").Area;
pub const Attribute = @import("attribute.zig").Attribute;
pub const Attributes = @import("attributes.zig").Attributes;
pub const Color = @import("color.zig").Color;
pub const Ansi = @import("ansi.zig").Ansi;
pub const Rgb = @import("rgb.zig").Rgb;
pub const Coordinate = @import("coordinate.zig").Coordinate;
pub const Source = @import("source.zig").Source;
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

var gpa: std.mem.Allocator = undefined;
var buffer: Buffer = undefined;
var renderer: Renderer = undefined;
var in_frame: bool = undefined;

// do not exceed the screen height while rendering
var limit_height: bool = undefined;

pub fn init() error{ NotATerminal, Unexpected }!void {
    gpa = std.heap.c_allocator;
    buffer = .init();
    renderer = .init();
    in_frame = false;
    limit_height = true;

    // hide the cursor in the first frame
    // (unless the user provides a render position)
    renderer.last_buffer.cursor = .{ .x = 0, .y = 0 };

    try Terminal.instance().enableRawMode();
}

pub fn deinit() error{Unexpected}!void {
    buffer.deinit(gpa);
    renderer.deinit(gpa);

    // Cursor is hidden, restore it.
    if (renderer.last_buffer.cursor == null) {
        var out_buffer: [0]u8 = undefined; // disable buffering
        const out = std.fs.File.stdout();
        var out_writer = out.writer(&out_buffer);

        vt.showCursor(&out_writer.interface) catch return error.Unexpected;
    }

    Terminal.instance().disableRawMode() catch return error.Unexpected;
}

pub fn render(object: anytype, viewport: Viewport) anyerror!void {
    const widget: Widget = object.widget();

    // zig fmt: off
    const screen     = try Terminal.instance().getScreenSize();
    const max_height = if (limit_height) screen.height else std.math.maxInt(u16);
    const width      = screen.width;
    const height     = switch (viewport) {
        .auto => (try widget.measure(.opts(width, max_height))).height,
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

    try widget.render(&buffer, buffer.getArea());
    try renderer.render(gpa, &buffer);

    in_frame = true;
}

pub fn print(object: anytype) anyerror!void {
    const old_value = limit_height;
    limit_height = false;
    try render(object, .Auto());
    try advance();
    limit_height = old_value;
}

pub fn advance() !void {
    if (!in_frame) return;

    var out_buffer: [1024]u8 = undefined; // disable buffering
    const out = std.fs.File.stdout();
    var out_writer = out.writer(&out_buffer);
    const writer = &out_writer.interface;

    for (0..renderer.last_buffer.height()) |_|
        try writer.writeAll("\n");

    if (renderer.last_buffer.cursor == null)
        try vt.showCursor(writer);

    try writer.flush();

    renderer.last_buffer.deinit(gpa);
    renderer.last_buffer = .init();
    renderer.last_buffer.cursor = .{ .x = 0, .y = 0 };

    in_frame = false;
}

pub fn clear() !void {
    if (!in_frame) return;

    buffer.cursor = .{ .x = 0, .y = 0 };
    for (buffer.characters) |*char| {
        char.* = .{};
    }
    try renderer.render(gpa, &buffer);

    in_frame = false;
}

pub const ReadOpts = struct {
    // provided in milliseconds
    timeout: ?u32 = null,
};

pub const ReadInputOptions = Terminal.ReadInputOptions;

pub fn readInput(opts: ReadInputOptions) error{ ReadFailed, PollFailed, Interrupted, Unexpected }!?Input {
    return Terminal.instance().readInput(opts);
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
    _ = @import("source.zig");
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
