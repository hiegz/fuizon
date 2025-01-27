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
