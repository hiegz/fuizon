const std = @import("std");
const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

const Color = fuizon.style.Color;
const Attributes = fuizon.style.Attributes;

/// ...
pub const raw_mode = struct {
    /// Checks whether the raw mode is enabled.
    pub fn isEnabled() error{BackendError}!bool {
        var ret: c_int = undefined;
        var is_enabled: bool = undefined;
        ret = c.crossterm_is_raw_mode_enabled(&is_enabled);
        if (0 != ret) return error.BackendError;
        return is_enabled;
    }

    /// Enables raw mode.
    pub fn enable() error{BackendError}!void {
        var ret: c_int = undefined;
        ret = c.crossterm_enable_raw_mode();
        if (0 != ret) return error.BackendError;
    }

    /// Disables raw mode.
    pub fn disable() error{BackendError}!void {
        var ret: c_int = undefined;
        ret = c.crossterm_disable_raw_mode();
        if (0 != ret) return error.BackendError;
    }
};

/// ...
pub const alternate_screen = struct {
    /// Switches to the alternate screen.
    pub fn enter(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_enter_alternate_screen(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Switches back to the main screen.
    pub fn leave(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_leave_alternate_screen(&stream);
        if (0 != ret) return error.BackendError;
    }
};

/// ...
pub const screen = struct {
    /// Clears all cells.
    pub fn clearAll(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_all(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Clears all cells and history.
    pub fn clearPurge(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_purge(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Clears all cells from the cursor position downwards.
    pub fn clearFromCursorDown(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_from_cursor_down(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Clears all cells from the cursor position upwards.
    pub fn clearFromCursorUp(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_from_cursor_up(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Clears all cells at the current row.
    pub fn clearCurrentLine(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_current_line(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Clears all cells from the cursor position until the new line.
    pub fn clearUntilNewLine(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_clear_until_new_line(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Scrolls the terminal screen a given number of rows up.
    pub fn scrollUp(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_scroll_up(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Scrolls the terminal screen a given number of rows down.
    pub fn scrollDown(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_scroll_down(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Returns the current size of the terminal screen.
    pub fn size() error{BackendError}!struct { width: u16, height: u16 } {
        var ret: c_int = undefined;
        var sz: c.crossterm_size = undefined;
        ret = c.crossterm_get_size(&sz);
        if (0 != ret) return error.BackendError;
        return .{ .width = sz.width, .height = sz.height };
    }
};

/// ...
pub const area = union(enum) {
    _fullscreen,
    _fixed: u16,

    pub fn fullscreen() area {
        return area._fullscreen;
    }

    pub fn fixed(height: u16) area {
        return area{ ._fixed = height };
    }

    /// Renders the specified `area` on the screen and returns an `Area` with
    /// the computed dimensions and origin.
    pub fn render(self: area, writer: *std.io.Writer) !Area {
        const scr = try screen.size();
        const cur = try cursor.position();

        const h = switch (self) {
            ._fullscreen => scr.height,
            ._fixed => |_| f: {
                if (self._fixed > scr.height)
                    @panic("Render height exceeds available screen height");
                break :f self._fixed;
            },
        };
        const diff = h -| (scr.height - cur.y);

        try screen.scrollUp(writer, diff);
        try cursor.moveUp(writer, diff);

        return Area{
            .width = scr.width,
            .height = h,
            .origin = .{ .x = 0, .y = cur.y - diff },
        };
    }
};

pub const frame = struct {
    /// ...
    pub fn render(writer: *std.io.Writer, curr: Frame, prev: Frame) anyerror!void {
        var foreground_color: Color = .default;
        var background_color: Color = .default;
        var attributes = Attributes.none;

        try fuizon.backend.text.foreground.set(writer, foreground_color);
        try fuizon.backend.text.background.set(writer, background_color);
        try fuizon.backend.text.attributes.reset(writer);

        var i: usize = 0;
        while (i < curr.buffer.len) {
            const pos = curr.posOf(i);
            const cell = &curr.buffer[i];

            std.debug.assert(curr.buffer[i].width > 0);

            if (i < prev.buffer.len and
                std.meta.eql(pos, prev.posOf(i)) and
                std.meta.eql(curr.buffer[i], prev.buffer[i]))
            {
                i += curr.buffer[i].width;
                continue;
            }

            try fuizon.backend.cursor.moveTo(writer, pos.x, pos.y);

            if (cell.style.foreground_color) |color| {
                if (!std.meta.eql(foreground_color, color)) {
                    foreground_color = color;
                    try fuizon.backend.text.foreground.set(writer, color);
                }
            }

            if (cell.style.background_color) |color| {
                if (!std.meta.eql(background_color, color)) {
                    background_color = color;
                    try fuizon.backend.text.background.set(writer, color);
                }
            }

            // zig fmt: off
            const on  = Attributes{ .bitset = ~attributes.bitset & cell.style.attributes.bitset };
            const off = Attributes{ .bitset = attributes.bitset  & ~cell.style.attributes.bitset };

            if (on.contain(&.{.bold}))        try fuizon.backend.text.attribute.bold.set(writer);
            if (on.contain(&.{.dim}))         try fuizon.backend.text.attribute.dim.set(writer);
            if (on.contain(&.{.underlined}))  try fuizon.backend.text.attribute.underline.set(writer);
            if (on.contain(&.{.reverse}))     try fuizon.backend.text.attribute.reverse.set(writer);
            if (on.contain(&.{.hidden}))      try fuizon.backend.text.attribute.hidden.set(writer);

            if (off.contain(&.{.bold}))       try fuizon.backend.text.attribute.bold.reset(writer);
            if (off.contain(&.{.dim}))        try fuizon.backend.text.attribute.dim.reset(writer);
            if (off.contain(&.{.underlined})) try fuizon.backend.text.attribute.underline.reset(writer);
            if (off.contain(&.{.reverse}))    try fuizon.backend.text.attribute.reverse.reset(writer);
            if (off.contain(&.{.hidden}))     try fuizon.backend.text.attribute.hidden.reset(writer);

            attributes = cell.style.attributes;
            // zig fmt: on

            try writer.print("{u}", .{cell.content});
            i += cell.width;
        }

        try fuizon.backend.text.foreground.set(writer, .default);
        try fuizon.backend.text.background.set(writer, .default);
        try fuizon.backend.text.attributes.reset(writer);
    }
};

/// ...
pub const cursor = struct {
    /// Shows cursor.
    pub fn show(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_show_cursor(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Hides cursor.
    pub fn hide(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_hide_cursor(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor up by `n` rows.
    pub fn moveUp(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_up(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor up by `n` rows.
    pub fn moveToPreviousLine(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_to_previous_line(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor down by `n` rows.
    pub fn moveDown(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_down(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor up by `n` rows.
    pub fn moveToNextLine(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_to_next_line(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor left by `n` columns.
    pub fn moveLeft(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_left(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor right by `n` columns.
    pub fn moveRight(writer: *std.io.Writer, n: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_right(&stream, n);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor to the specified row.
    pub fn moveToRow(writer: *std.io.Writer, y: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_to_row(&stream, y);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor to the specified row.
    pub fn moveToCol(writer: *std.io.Writer, x: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_to_col(&stream, x);
        if (0 != ret) return error.BackendError;
    }

    /// Moves the cursor to the specified position on the screen.
    pub fn moveTo(writer: *std.io.Writer, x: u16, y: u16) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_move_cursor_to(&stream, x, y);
        if (0 != ret) return error.BackendError;
    }

    /// Saves current cursor position.
    pub fn save(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_save_cursor_position(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Restores previously saved cursor position.
    pub fn restore(writer: *std.io.Writer) error{BackendError}!void {
        var stream: c.crossterm_stream = .{
            .context = @ptrCast(@constCast(writer)),
            .write_fn = _write(@TypeOf(writer)),
            .flush_fn = _flush(@TypeOf(writer)),
        };
        var ret: c_int = undefined;
        ret = c.crossterm_restore_cursor_position(&stream);
        if (0 != ret) return error.BackendError;
    }

    /// Get current cursor position.
    pub fn position() error{BackendError}!struct { x: u16, y: u16 } {
        var ret: c_int = undefined;
        var pos: c.crossterm_cursor_position = undefined;
        ret = c.crossterm_get_cursor_position(&pos);
        if (0 != ret) return error.BackendError;
        return .{ .x = pos.x, .y = pos.y };
    }
};

pub const text = struct {
    /// ...
    pub const foreground = struct {
        /// Updates the current foreground color.
        pub fn set(writer: *std.io.Writer, color: fuizon.style.Color) error{BackendError}!void {
            var stream: c.crossterm_stream = .{
                .context = @ptrCast(@constCast(writer)),
                .write_fn = _write(@TypeOf(writer)),
                .flush_fn = _flush(@TypeOf(writer)),
            };
            var ret: c_int = undefined;
            ret = c.crossterm_stream_set_foreground_color(
                &stream,
                &color.toCrosstermColor(),
            );
            if (0 != ret) return error.BackendError;
        }
    };

    /// ...
    pub const background = struct {
        /// Updates the current background color.
        pub fn set(writer: *std.io.Writer, color: fuizon.style.Color) error{BackendError}!void {
            var stream: c.crossterm_stream = .{
                .context = @ptrCast(@constCast(writer)),
                .write_fn = _write(@TypeOf(writer)),
                .flush_fn = _flush(@TypeOf(writer)),
            };
            var ret: c_int = undefined;
            ret = c.crossterm_stream_set_background_color(
                &stream,
                &color.toCrosstermColor(),
            );
            if (0 != ret) return error.BackendError;
        }
    };

    /// ...
    pub const attribute = struct {
        /// ...
        pub const bold = struct {
            /// Enables the text attribute 'bold.'
            pub fn set(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_set_bold_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }

            /// Disables the text attribute 'bold.'
            pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_reset_bold_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }
        };

        /// ...
        pub const dim = struct {
            /// Enables the text attribute 'dim.'
            pub fn set(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_set_dim_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }

            /// Disables the text attribute 'dim.'
            pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_reset_dim_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }
        };

        /// ...
        pub const underline = struct {
            /// Enables the text attribute 'underline.'
            pub fn set(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_set_underlined_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }

            /// Disables the text attribute 'underline.'
            pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_reset_underlined_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }
        };

        /// ...
        pub const reverse = struct {
            /// Enables the text attribute 'reverse.'
            pub fn set(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_set_reverse_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }

            /// Disables the text attribute 'reverse.'
            pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_reset_reverse_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }
        };

        /// ...
        pub const hidden = struct {
            /// Enables the text attribute 'hidden.'
            pub fn set(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_set_hidden_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }

            /// Disables the text attribute 'hidden.'
            pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
                var stream: c.crossterm_stream = .{
                    .context = @ptrCast(@constCast(writer)),
                    .write_fn = _write(@TypeOf(writer)),
                    .flush_fn = _flush(@TypeOf(writer)),
                };
                var ret: c_int = undefined;
                ret = c.crossterm_stream_reset_hidden_attribute(&stream);
                if (0 != ret) return error.BackendError;
            }
        };
    };

    /// ...
    pub const attributes = struct {
        /// Disables all text attributes.
        pub fn reset(writer: *std.io.Writer) error{BackendError}!void {
            var stream: c.crossterm_stream = .{
                .context = @ptrCast(@constCast(writer)),
                .write_fn = _write(@TypeOf(writer)),
                .flush_fn = _flush(@TypeOf(writer)),
            };
            var ret: c_int = undefined;
            ret = c.crossterm_stream_reset_attributes(&stream);
            if (0 != ret) return error.BackendError;
        }
    };
};

/// ...
pub const event = struct {
    /// Checks if events are available for reading.
    pub fn poll() error{BackendError}!bool {
        var ret: c_int = undefined;
        var is_available: c_int = undefined;
        ret = c.crossterm_event_poll(&is_available);
        if (0 != ret) return error.BackendError;

        if (is_available == 1) {
            return true;
        } else if (is_available == 0) {
            return false;
        } else {
            return error.BackendError;
        }
    }

    /// Reads a single event from standard input.
    pub fn read() error{BackendError}!fuizon.event.Event {
        var ret: c_int = undefined;
        var ev: c.crossterm_event = undefined;
        ret = c.crossterm_event_read(&ev);
        if (0 != ret) return error.BackendError;

        if (fuizon.event.Event.fromCrosstermEvent(ev)) |e| {
            return e;
        } else {
            return error.BackendError;
        }
    }
};

/// ...
fn _write(comptime WriterType: type) fn (buf: [*c]const u8, buflen: usize, context: ?*anyopaque) callconv(.c) c_long {
    _ = WriterType;
    return struct {
        fn w(buf: [*c]const u8, buflen: usize, context: ?*anyopaque) callconv(.c) c_long {
            const maxlen = @as(usize, std.math.maxInt(c_long));
            const len = if (buflen <= maxlen) buflen else maxlen;
            const ctx: *std.io.Writer = @ptrCast(@alignCast(context));

            // The write operation below may return 0. Although that’s not an error,
            // we can't let 0 be returned from this function since Rust would
            // misinterpret that as the object being unable to accept more bytes,
            // which triggers an error there.
            //
            // Therefore, we retry the write until we get a non-zero result.
            var ret: c_long = 0;
            while (ret == 0) {
                ret = @intCast(ctx.write(buf[0..len]) catch return -1);
            }
            return ret;
        }
    }.w;
}

/// ...
fn _flush(comptime WriterType: type) fn (contxet: ?*anyopaque) callconv(.c) c_int {
    _ = WriterType;
    return struct {
        fn f(context: ?*anyopaque) callconv(.c) c_int {
            const ctx: *std.io.Writer = @ptrCast(@alignCast(context));
            _ = ctx;
            return 0;
        }
    }.f;
}
