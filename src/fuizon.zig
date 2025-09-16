const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;
const windows = std.os.windows;

pub const Alignment = alignment.Alignment;
pub const enterAlternateScreen = alternate_screen.enterAlternateScreen;
pub const leaveAlternateScreen = alternate_screen.leaveAlternateScreen;
pub const Area = area.Area;
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const setAttribute = attribute.setAttribute;
pub const resetAttribute = attribute.resetAttribute;
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const Ansi = color.Ansi;
pub const RgbColor = color.RgbColor;
pub const Rgb = color.Rgb;
pub const setForeground = color.setForeground;
pub const setBackground = color.setBackground;
pub const Coordinate = coordinate.Coordinate;
pub const showCursor = cursor.showCursor;
pub const hideCursor = cursor.hideCursor;
pub const moveCursorTo = cursor.moveCursorTo;
pub const getCursorPosition = cursor.getCursorPosition;
pub const Dimensions = dimensions.Dimensions;
pub const event = @import("event.zig");
pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyCode = keyboard.KeyCode;
pub const KeyModifier = keyboard.KeyModifier;
pub const KeyModifiers = keyboard.KeyModifiers;
pub const enableRawMode = raw_mode.enableRawMode;
pub const disableRawMode = raw_mode.disableRawMode;
pub const isRawModeEnabled = raw_mode.isRawModeEnabled;
pub const scrollUp = screen.scrollUp;
pub const scrollDown = screen.scrollDown;
pub const getScreenSize = screen.getScreenSize;
pub const Style = style.Style;

var write_buffer: []u8 = &.{};
var console_writer: ?std.fs.File.Writer = null;

extern fn GetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: *windows.DWORD) windows.BOOL;
extern fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: windows.DWORD) windows.BOOL;

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
pub fn init(allocator: std.mem.Allocator, buflen: usize, stream: enum { stdout, stderr }) error{OutOfMemory}!void {
    write_buffer = try allocator.alloc(u8, buflen);
    errdefer allocator.free(write_buffer);
    console_writer = switch (stream) {
        .stdout => std.fs.File.stdout().writerStreaming(write_buffer),
        .stderr => std.fs.File.stderr().writerStreaming(write_buffer),
    };

    if (is_windows) {
        var ret: windows.BOOL = undefined;
        const hOut: windows.HANDLE = console_writer.?.file.handle;
        std.debug.assert(hOut != windows.INVALID_HANDLE_VALUE);
        var dwMode: windows.DWORD = 0;
        ret = GetConsoleMode(hOut, &dwMode);
        std.debug.assert(1 == ret);
        dwMode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        ret = SetConsoleMode(hOut, dwMode);
        std.debug.assert(1 == ret);
    }
}

/// ---
/// Release all allocated memory.
///
/// The allocator must match the one used in `init()`.
/// ---
pub fn deinit(allocator: std.mem.Allocator) void {
    allocator.free(write_buffer);
    write_buffer = &.{};
    console_writer = null;
}

/// ---
/// Get the underlying terminal stream writer.
///
/// The returned pointer may become invalid in the future (e.g., when you
/// switch to a different stream using `useStdout()` or `useStderr()`)
/// ---
pub fn getWriter() *std.Io.Writer {
    if (console_writer == null)
        @panic("use before init or after deinit");
    return &console_writer.?.interface;
}

/// ---
/// Use the standard output stream.
///
/// If the standard output stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard output stream.
/// ---
pub fn useStdout() error{WriteFailed}!void {
    if (console_writer == null)
        @panic("use before init or after deinit");

    if (console_writer.?.file.handle == std.fs.File.stdout().handle)
        return;
    std.debug.assert(console_writer.?.file.handle == std.fs.File.stderr().handle);
    try console_writer.?.interface.flush();
    console_writer = std.fs.File.stdout().writerStreaming(write_buffer);
}

/// ---
/// Use the standard error stream.
///
/// If the standard error stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard error stream.
/// ---
pub fn useStderr() error{WriteFailed}!void {
    if (console_writer == null)
        @panic("use before init or after deinit");

    if (console_writer.?.file.handle == std.fs.File.stderr().handle)
        return;
    std.debug.assert(console_writer.?.file.handle == std.fs.File.stdout().handle);
    try console_writer.?.interface.flush();
    console_writer = std.fs.File.stderr().writerStreaming(write_buffer);
}

const alignment = @import("alignment.zig");
const alternate_screen = @import("alternate_screen.zig");
const area = @import("area.zig");
const attribute = @import("attribute.zig");
const color = @import("color.zig");
const coordinate = @import("coordinate.zig");
const cursor = @import("cursor.zig");
const dimensions = @import("dimensions.zig");
const frame = @import("frame.zig");
const keyboard = @import("keyboard.zig");
const raw_mode = @import("raw_mode.zig");
const screen = @import("screen.zig");
const style = @import("style.zig");

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}

test "init(.stdout) should write to stdout" {
    try init(std.testing.allocator, 1024, .stdout);
    defer deinit(std.testing.allocator);
    try std.testing.expectEqual(std.fs.File.stdout().handle, console_writer.?.file.handle);
}

test "init(.stderr) should write to stderr" {
    try init(std.testing.allocator, 1024, .stderr);
    defer deinit(std.testing.allocator);
    try std.testing.expectEqual(std.fs.File.stderr().handle, console_writer.?.file.handle);
}

test "useStdout() should switch to stdout" {
    try init(std.testing.allocator, 1024, .stderr);
    defer deinit(std.testing.allocator);
    try useStdout();
    try std.testing.expectEqual(std.fs.File.stdout().handle, console_writer.?.file.handle);
}

test "useStderr() should switch to stderr" {
    try init(std.testing.allocator, 1024, .stdout);
    defer deinit(std.testing.allocator);
    try useStderr();
    try std.testing.expectEqual(std.fs.File.stderr().handle, console_writer.?.file.handle);
}
