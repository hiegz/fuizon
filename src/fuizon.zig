const std = @import("std");
const builtin = @import("builtin");
const vt = @import("vt.zig");
const Terminal = @import("terminal.zig").Terminal;

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
pub const Void = @import("void.zig").Void;
pub const Widget = @import("widget.zig").Widget;

// zig fmt: off

/// Global allocator used by fuizon.
var gpa = std.heap.c_allocator;

var previous_buffer = Buffer.init();
var  current_buffer = Buffer.init();

// zig fmt: on

pub fn init() error{Unexpected}!void {
    // this makes the renderer hide the cursor in the first frame
    // (unless the user provides a render position)
    previous_buffer.cursor = .{ .x = 0, .y = 0 };

    try Terminal.instance().enableRawMode();
}

pub fn deinit() error{Unexpected}!void {
    // Cursor is hidden, restore it.
    if (previous_buffer.cursor == null) {
        var _buffer: [0]u8 = undefined;
        var writer = Terminal.instance().writer(gpa, &_buffer);

        vt.showCursor(&writer.interface) catch return error.Unexpected;
    }

    Terminal.instance().disableRawMode() catch return error.Unexpected;
}

pub const RenderOpts = struct {
    /// When enabled, the cursor advances to the next line after rendering
    /// instead of resetting to its initial position.
    advance: bool = false,

    /// Allow content height to exceed the screen height.
    ///
    /// Useful for one-time renders where the element does not need
    /// to be re-rendered.
    overflow: bool = false,
};

pub fn render(object: anytype, viewport: Viewport, opts: RenderOpts) anyerror!void {
    // zig fmt: off
    const terminal   = Terminal.instance();
    const screen     = try terminal.getScreenSize();
    const widget     = Widget.impl(object);
    const advance    = opts.advance;
    const overflow   = opts.overflow;
    const max_height = if (overflow) std.math.maxInt(u16) else screen.height;
    const width      = screen.width;
    const height     =
        switch (viewport) {
            .auto       => (try widget.measure(.opts(width, max_height))).height,
            .fixed      => |height| @min(height, max_height),
            .fullscreen => screen.height,
        };

    if (width != current_buffer.width() or height != current_buffer.height())
        try current_buffer.resize(gpa, .init(width, height));

    for (current_buffer.characters) |*char|
        char.* = .{};

    try widget.render(&current_buffer, current_buffer.getArea());

    var   allocating = std.Io.Writer.Allocating.init(gpa);
    defer allocating.deinit();
    const writer = &allocating.writer;

    // these define the cursor position relative to the current one.
    var px: i16 = 0;
    var py: u16 = 0;

    if (previous_buffer.cursor) |coordinate| {
        try vt.hideCursor(writer);
        try vt.moveCursorUp(writer, coordinate.y);
        try vt.moveCursorBackward(writer, coordinate.x);

        previous_buffer.cursor = null;
    }

    var last_foreground: Color      = .default;
    var last_background: Color      = .default;
    var last_attributes: Attributes = .none;

    for (0..current_buffer.characters.len) |index| {
        const character = current_buffer.characters[index];

        // reached the end of line
        if (index != 0 and index % current_buffer.width() == 0) {
            px -= @intCast(current_buffer.width());
            py += 1;
        }

        // Make sure the cursor is in the right position before printing
        for (0..py) |_| try writer.writeAll("\n");
        if  (px > 0)    try vt.moveCursorForward (writer, @abs(px));
        if  (px < 0)    try vt.moveCursorBackward(writer, @abs(px));
        px = 0;
        py = 0;

        if (index < previous_buffer.characters.len) {
            const previous_character = previous_buffer.characters[index];
            const previous_position  = previous_buffer.posOf(index);
            const current_position   = current_buffer.posOf(index);

            if (std.meta.eql(previous_position, current_position) and
                std.meta.eql(previous_character, character))
            {
                px += 1;
                continue;
            }
        }

        const foreground = character.style.foreground_color;
        const background = character.style.background_color;
        const attributes = character.style.attributes;

        if (!std.meta.eql(last_foreground, foreground)) {
            last_foreground = foreground;
            try vt.setForeground(writer, foreground);
        }

        if (!std.meta.eql(last_background, background)) {
            last_background = background;
            try vt.setBackground(writer, background);
        }

        var   it:  Attributes.Iterator = undefined;
        const on:  Attributes = .{ .bitset = ~last_attributes.bitset &  attributes.bitset };
        const off: Attributes = .{ .bitset =  last_attributes.bitset & ~attributes.bitset };

        it = on.iterator();
        while (it.next()) |attribute| {
            try vt.setAttribute(writer, attribute);
        }

        it = off.iterator();
        while (it.next()) |attribute| {
            try vt.resetAttribute(writer, attribute);
        }

        last_attributes = attributes;

        // finally
        try writer.print("{u}", .{character.value});
    }

    switch (advance) {
        true => {
            try writer.writeAll("\n\r");
            try vt.showCursor(writer);

            previous_buffer.deinit(gpa);
            previous_buffer = .init();
        },

        false => {
            try vt.moveCursorBackward(writer, current_buffer.width());
            try vt.moveCursorUp      (writer, current_buffer.height() - 1);

            if (current_buffer.cursor) |coordinate| {
                try vt.moveCursorForward(writer, coordinate.x);
                try vt.moveCursorDown(writer, coordinate.y);
                try vt.showCursor(writer);
            }

            try previous_buffer.copy(gpa, current_buffer);
        },
    }

    try terminal.writeAll(gpa, allocating.written());

    // zig fmt: on
}

pub fn print(object: anytype) anyerror!void {
    try render(object, .auto, .{ .advance = true, .overflow = true });
}

pub fn clear() anyerror!void {
    try render(&Void, .auto, .{});
}

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
    _ = @import("void.zig");
    _ = @import("vt.zig");
    _ = @import("widget.zig");
    _ = @import("windows.zig");
}
