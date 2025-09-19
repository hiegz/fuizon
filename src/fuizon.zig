const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = std.posix;
const alignment = @import("alignment.zig");
const area = @import("area.zig");
const attribute = @import("attribute.zig");
const color = @import("color.zig");
const coordinate = @import("coordinate.zig");
const dimensions = @import("dimensions.zig");
const frame = @import("frame.zig");
const key = @import("key.zig");
const style = @import("style.zig");
const state = @import("state.zig");
const queue = @import("queue.zig");
const Queue = queue.Queue;
const terminal = @import("terminal.zig");
const input = @import("input.zig");

pub const Alignment = alignment.Alignment;
pub const Area = area.Area;
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const RgbColor = color.RgbColor;
pub const Coordinate = coordinate.Coordinate;
pub const Dimensions = dimensions.Dimensions;
pub const Input = input.Input;
pub const InputParser = @import("input_parser.zig");
pub const Key = key.Key;
pub const KeyCode = key.KeyCode;
pub const KeyModifier = key.KeyModifier;
pub const KeyModifiers = key.KeyModifiers;
pub const Style = style.Style;

/// ---
/// Initialize internal state and buffers.
///
/// Buffering defers terminal actions until the buffer is flushed manually or
/// fills up. This reduces the number of system calls and significantly
/// improves performance. A `buflen` of 0 disables buffering.
///
/// Make sure to call this function before any terminal actions.
///
/// Don't forget to call `deinit()` to release resources.
/// ---
pub fn init(
    allocator: std.mem.Allocator,
    buflen: usize,
    stream: enum { stdout, stderr },
) error{ OutOfMemory, NotATerminal, Unexpected }!void {
    state.buffer = try allocator.alloc(u8, buflen);
    errdefer allocator.free(state.buffer);
    state.writer = switch (stream) {
        .stdout => std.fs.File.stdout().writerStreaming(state.buffer),
        .stderr => std.fs.File.stderr().writerStreaming(state.buffer),
    };

    try terminal.enableRawMode();
}

/// ---
/// Release all allocated memory.
///
/// The allocator must match the one used in `init()`.
/// ---
pub fn deinit(allocator: std.mem.Allocator) error{ NotATerminal, Unexpected }!void {
    try terminal.disableRawMode();

    allocator.free(state.buffer);
    state.buffer = &.{};
    state.writer = null;
}

/// ---
/// Get the underlying terminal stream state.
///
/// The returned pointer may become invalid in the future (e.g., when you
/// switch to a different stream using `useStdout()` or `useStderr()`)
/// ---
pub fn getWriter() *std.Io.Writer {
    if (state.writer == null)
        @panic("use before init or after deinit");
    return &state.writer.?.interface;
}

/// ---
/// Use the standard output stream.
///
/// If the standard output stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard output stream.
/// ---
pub fn useStdout() error{WriteFailed}!void {
    if (state.writer == null)
        @panic("use before init or after deinit");

    if (state.writer.?.file.handle == std.fs.File.stdout().handle)
        return;
    std.debug.assert(state.writer.?.file.handle == std.fs.File.stderr().handle);
    try state.writer.?.interface.flush();
    state.writer = std.fs.File.stdout().writerStreaming(state.buffer);
}

/// ---
/// Use the standard error stream.
///
/// If the standard error stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard error stream.
/// ---
pub fn useStderr() error{WriteFailed}!void {
    if (state.writer == null)
        @panic("use before init or after deinit");

    if (state.writer.?.file.handle == std.fs.File.stderr().handle)
        return;
    std.debug.assert(state.writer.?.file.handle == std.fs.File.stdout().handle);
    try state.writer.?.interface.flush();
    state.writer = std.fs.File.stderr().writerStreaming(state.buffer);
}

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}

// test "init(.stdout) should write to stdout" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stdout().handle, state.instance.?.file.handle);
// }
//
// test "init(.stderr) should write to stderr" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stderr().handle, state.instance.?.file.handle);
// }
//
// test "useStdout() should switch to stdout" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStdout();
//     try std.testing.expectEqual(std.fs.File.stdout().handle, state.instance.?.file.handle);
// }
//
// test "useStderr() should switch to stderr" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStderr();
//     try std.testing.expectEqual(std.fs.File.stderr().handle, state.instance.?.file.handle);
// }
