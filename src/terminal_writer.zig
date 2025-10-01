const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;

pub const TerminalWriter = struct {
    gpa: std.mem.Allocator,
    terminal: *Terminal,
    interface: std.Io.Writer,

    pub fn init(gpa: std.mem.Allocator, terminal: *Terminal, buffer: []u8) TerminalWriter {
        return .{
            .gpa = gpa,
            .terminal = terminal,
            .interface = .{
                .buffer = buffer,
                .vtable = &.{ .drain = drain },
            },
        };
    }

    /// Sends bytes to the logical sink. A write will only be sent here if it
    /// could not fit into `buffer`, or during a `flush` operation.
    ///
    /// `buffer[0..end]` is consumed first, followed by each slice of `data` in
    /// order. Elements of `data` may alias each other but may not alias
    /// `buffer`.
    ///
    /// This function modifies `Writer.end` and `Writer.buffer` in an
    /// implementation-defined manner.
    ///
    /// `data.len` must be nonzero.
    ///
    /// The last element of `data` is repeated as necessary so that it is
    /// written `splat` number of times, which may be zero.
    ///
    /// This function may not be called if the data to be written could have
    /// been stored in `buffer` instead, including when the amount of data to
    /// be written is zero and the buffer capacity is zero.
    ///
    /// Number of bytes consumed from `data` is returned, excluding bytes from
    /// `buffer`.
    ///
    /// Number of bytes returned may be zero, which does not indicate stream
    /// end. A subsequent call may return nonzero, or signal end of stream via
    /// `error.WriteFailed`.
    fn drain(io_writer: *std.Io.Writer, data: []const []const u8, splat: usize) error{WriteFailed}!usize {
        const w: *TerminalWriter =
            @alignCast(@fieldParentPtr("interface", io_writer));

        // zig fmt: off

        const gpa      = w.gpa;
        const terminal = w.terminal;
        const buffered = io_writer.buffered();
        var   consumed = @as(usize, 0);

        // zig fmt: on

        try terminal.write(gpa, buffered);
        _ = io_writer.consumeAll();

        for (data[0 .. data.len - 1]) |slice| {
            try terminal.write(gpa, slice);
            consumed += slice.len;
        }

        for (0..splat) |_| {
            try terminal.write(gpa, data[data.len - 1]);
            consumed += data[data.len - 1].len;
        }

        return consumed;
    }
};
