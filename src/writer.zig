const std = @import("std");

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

test "useStdout() should switch to stdout" {
    try useStdout();
    try std.testing.expectEqual(std.fs.File.stdout().handle, writer.file.handle);
}

test "useStderr() should switch to stderr" {
    try useStderr();
    try std.testing.expectEqual(std.fs.File.stderr().handle, writer.file.handle);
}
