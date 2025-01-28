const std = @import("std");
const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

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
    pub fn read() error{BackendError}!fuizon.Event {
        var ret: c_int = undefined;
        var ev: c.crossterm_event = undefined;
        ret = c.crossterm_event_read(&ev);
        if (0 != ret) return error.BackendError;

        if (fuizon.Event.fromCrosstermEvent(ev)) |e| {
            return e;
        } else {
            return error.BackendError;
        }
    }
};

/// Checks whether the raw mode is enabled.
pub fn isRawModeEnabled() error{BackendError}!bool {
    var ret: c_int = undefined;
    var is_enabled: bool = undefined;
    ret = c.crossterm_is_raw_mode_enabled(&is_enabled);
    if (0 != ret) return error.BackendError;
    return is_enabled;
}

/// Enables raw mode.
pub fn enableRawMode() error{BackendError}!void {
    var ret: c_int = undefined;
    ret = c.crossterm_enable_raw_mode();
    if (0 != ret) return error.BackendError;
}

/// Disables raw mode.
pub fn disableRawMode() error{BackendError}!void {
    var ret: c_int = undefined;
    ret = c.crossterm_disable_raw_mode();
    if (0 != ret) return error.BackendError;
}

/// Get current cursor position.
pub fn getCursorPosition() error{BackendError}!struct { x: u16, y: u16 } {
    var ret: c_int = undefined;
    var pos: c.crossterm_cursor_position = undefined;
    ret = c.crossterm_get_cursor_position(&pos);
    if (0 != ret) return error.BackendError;
    return .{ .x = pos.x, .y = pos.y };
}

/// Returns the current size of the terminal screen.
pub fn getTerminalSize() error{BackendError}!struct { width: u16, height: u16 } {
    var ret: c_int = undefined;
    var size: c.crossterm_size = undefined;
    ret = c.crossterm_get_size(&size);
    if (0 != ret) return error.BackendError;
    return .{ .width = size.width, .height = size.height };
}

/// A backend implementation that uses crossterm to render to the terminal.
pub fn Backend(WriterType: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        writer: *WriterType,
        stream: c.crossterm_stream,

        /// Creates a new `CrosstermBackend` instance attached to the specified writer.
        pub fn init(allocator: std.mem.Allocator, writer: WriterType) std.mem.Allocator.Error!Self {
            var backend: Self = undefined;
            backend.allocator = allocator;
            backend.writer = try allocator.create(WriterType);
            backend.writer.* = writer;
            backend.stream = .{
                .context = @ptrCast(backend.writer),
                .write_fn = Self._write,
                .flush_fn = Self._flush,
            };
            return backend;
        }

        /// Releases all allocated memory.
        pub fn deinit(self: Self) void {
            self.allocator.destroy(self.writer);
        }

        /// Switches to the alternate screen.
        pub fn enterAlternateScreen(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_enter_alternate_screen(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Switches back to the main screen.
        pub fn leaveAlternateScreen(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_leave_alternate_screen(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Shows cursor.
        pub fn showCursor(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_show_cursor(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Hides cursor.
        pub fn hideCursor(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_hide_cursor(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Saves current cursor position.
        pub fn saveCursorPosition(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_save_cursor_position(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Restores previously saved cursor position.
        pub fn restoreCursorPosition(self: *Self) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_restore_cursor_position(&self.stream);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor up by `n` rows.
        pub fn moveCursorUp(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_up(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor up by `n` rows.
        pub fn moveCursorToPreviousLine(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_to_previous_line(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor down by `n` rows.
        pub fn moveCursorDown(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_down(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor up by `n` rows.
        pub fn moveCursorToNextLine(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_to_next_line(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor left by `n` columns.
        pub fn moveCursorLeft(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_left(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor right by `n` columns.
        pub fn moveCursorRight(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_right(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor to the specified row.
        pub fn moveCursorToRow(self: *Self, y: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_to_row(&self.stream, y);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor to the specified row.
        pub fn moveCursorToCol(self: *Self, x: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_to_col(&self.stream, x);
            if (0 != ret) return error.BackendError;
        }

        /// Moves the cursor to the specified position on the screen.
        pub fn moveCursorTo(self: *Self, x: u16, y: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_move_cursor_to(&self.stream, x, y);
            if (0 != ret) return error.BackendError;
        }

        /// Scrolls the terminal screen a given number of rows up.
        pub fn scrollUp(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_scroll_up(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// Scrolls the terminal screen a given number of rows down.
        pub fn scrollDown(self: *Self, n: u16) error{BackendError}!void {
            var ret: c_int = undefined;
            ret = c.crossterm_scroll_down(&self.stream, n);
            if (0 != ret) return error.BackendError;
        }

        /// ...
        fn _write(buf: [*c]const u8, buflen: usize, context: ?*anyopaque) callconv(.C) c_long {
            const maxlen = @as(usize, std.math.maxInt(c_long));
            const len = if (buflen <= maxlen) buflen else maxlen;
            const ctx: *WriterType = @ptrCast(@alignCast(context));
            return @intCast(ctx.write(buf[0..len]) catch return -1);
        }

        /// ...
        fn _flush(context: ?*anyopaque) callconv(.C) c_int {
            _ = context;
            return 0;
        }
    };
}
