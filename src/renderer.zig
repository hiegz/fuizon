const std = @import("std");
const builtin = @import("builtin");
const vt = @import("vt.zig");
const Terminal = @import("terminal.zig").Terminal;
const windows = @import("windows.zig");
const Attributes = @import("attributes.zig").Attributes;
const Buffer = @import("buffer.zig").Buffer;
const Color = @import("color.zig").Color;

// zig fmt: off

pub const Renderer = struct {
    pub const Error  = error{ OutOfMemory, RenderFailed, Unexpected };
    const WriteError = error{ OutOfMemory, WriteFailed,  Unexpected };

    last_buffer: Buffer,

    pub fn init() Renderer {
        var self: Renderer = undefined;
        self.last_buffer = .init();
        return self;
    }

    pub fn deinit(self: Renderer, gpa: std.mem.Allocator) void {
        self.last_buffer.deinit(gpa);
    }

    pub fn render(self: *Renderer, gpa: std.mem.Allocator, buffer: *Buffer) Error!void {
        return self.write(gpa, buffer) catch |err| switch (err) {
            error.WriteFailed => error.RenderFailed,
            else => |e| e,
        };
    }

    fn write(self: *Renderer, gpa: std.mem.Allocator, buffer: *Buffer) WriteError!void {
        // these define the cursor position relative to the current one.
        var   px: i16 = 0;
        var   py: u16 = 0;

        var allocating_writer = std.Io.Writer.Allocating.init(gpa);
        defer allocating_writer.deinit();
        const writer = &allocating_writer.writer;

        if (self.last_buffer.cursor) |coordinate| {
            try vt.hideCursor(writer);
            try vt.moveCursorUp(writer, coordinate.y);
            try vt.moveCursorBackward(writer, coordinate.x);

            self.last_buffer.cursor = null;
        }

        var last_foreground: Color      = .default;
        var last_background: Color      = .default;
        var last_attributes: Attributes = .none;

        for (0..buffer.characters.len) |index| {
            const character = buffer.characters[index];

            // reached the end of line
            if (index != 0 and index % buffer.width() == 0) {
                px -= @intCast(buffer.width());
                py += 1;
            }

            // Make sure the cursor is in the right position before printing
            for (0..py) |_| try writer.writeAll("\n");
            if  (px > 0)    try vt.moveCursorForward (writer, @abs(px));
            if  (px < 0)    try vt.moveCursorBackward(writer, @abs(px));
            px = 0;
            py = 0;

            if (index < self.last_buffer.characters.len) {
                const previous_character = self.last_buffer.characters[index];
                const previous_position  = self.last_buffer.posOf(index);
                const current_position   = buffer.posOf(index);

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

        // restore the cursor position
        try vt.moveCursorBackward(writer, buffer.width());
        try vt.moveCursorUp      (writer, buffer.height() - 1);

        if (buffer.cursor) |coordinate| {
            try vt.moveCursorForward(writer, coordinate.x);
            try vt.moveCursorDown(writer, coordinate.y);
            try vt.showCursor(writer);
        }

        // save this buffer
        try self.last_buffer.copy(gpa, buffer.*);

        try Terminal.instance().write(gpa, allocating_writer.written());
    }
};
