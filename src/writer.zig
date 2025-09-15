const std = @import("std");
const c = @import("headers.zig").c;

// zig fmt: off

var buffer = @as([4096]u8, undefined);
var writer = @as(std.fs.File.Writer, std.fs.File.stdout().writerStreaming(&buffer));

/// ---
/// Get the underlying terminal stream writer.
///
/// By default it writes to standard output, but this can be changed with
/// `useStdout()` or `useStderr()`. The returned pointer may become invalid in
/// the future (e.g., when you switch to a different stream using `useStdout()`
/// or `useStderr()`)
/// ---
pub fn getWriter() *std.Io.Writer {
    return &writer.interface;
}

/// ---
/// Use the standard output stream.
///
/// If the standard output stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard output stream.
/// ---
pub fn useStdout() error{WriteFailed}!void {
    if (writer.file.handle == std.fs.File.stdout().handle)
        return;
    std.debug.assert(writer.file.handle == std.fs.File.stderr().handle);
    try writer.interface.flush();
    writer = std.fs.File.stdout().writerStreaming(&buffer);
}

/// ---
/// Use the standard error stream.
///
/// If the standard error stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard error stream.
/// ---
pub fn useStderr() error{WriteFailed}!void {
    if (writer.file.handle == std.fs.File.stderr().handle)
        return;
    std.debug.assert(writer.file.handle == std.fs.File.stdout().handle);
    try writer.interface.flush();
    writer = std.fs.File.stderr().writerStreaming(&buffer);
}

pub fn getCrosstermStream() c.crossterm_stream {
    return .{
        .context = @ptrCast(@constCast(getWriter())),
        .write_fn = write,
        .flush_fn = flush,
    };
}

fn write(buf: [*c]const u8, buflen: usize, context: ?*anyopaque) callconv(.c) c_long {
    const maxlen = @as(usize, std.math.maxInt(c_long));
    const len = if (buflen <= maxlen) buflen else maxlen;
    const w: *std.Io.Writer = @ptrCast(@alignCast(context));
    const ret: c_long = @intCast(w.write(buf[0..len]) catch return -1);

    // Long story short:
    //
    // (ret == 0) should never happen on writers in *streaming* mode
    // unless (buflen == 0) is also true.
    //
    // If this somehow happens, we want to catch it here so it doesn't
    // reach the Rust code where (ret == 0 && buflen != 0) causes an
    // error that's hard to trace.
    std.debug.assert(ret != 0 or buflen == 0);

    return ret;
}

fn flush(context: ?*anyopaque) callconv(.c) c_int {
    const w: *std.Io.Writer = @ptrCast(@alignCast(context));
    w.flush() catch return -1;
    return 0;
}

test "useStdout() should switch to stdout" {
    try useStdout();
    try std.testing.expectEqual(std.fs.File.stdout().handle, writer.file.handle);
}

test "useStderr() should switch to stderr" {
    try useStderr();
    try std.testing.expectEqual(std.fs.File.stderr().handle, writer.file.handle);
}
