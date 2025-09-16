const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = std.posix;

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

var original_mode: switch (builtin.os.tag) {
    .macos, .linux => posix.termios,
    .windows => struct { out: windows.DWORD, in: windows.DWORD },
    else => unreachable,
} = undefined;

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
) error{ OutOfMemory, Unexpected }!void {
    writer.buffer = try allocator.alloc(u8, buflen);
    errdefer allocator.free(writer.buffer);
    writer.instance = switch (stream) {
        .stdout => std.fs.File.stdout().writerStreaming(writer.buffer),
        .stderr => std.fs.File.stderr().writerStreaming(writer.buffer),
    };

    switch (builtin.os.tag) {
        // zig fmt: off
        .linux, .macos => {
            var termios =
                posix.tcgetattr(writer.instance.?.file.handle) catch {
                    return error.Unexpected;
                };

            original_mode        = termios;
            termios.lflag.ECHO   = false;
            termios.lflag.ECHOE  = false;
            termios.lflag.ECHOK  = false;
            termios.lflag.ECHONL = false;
            termios.lflag.ICANON = false;
            termios.lflag.IEXTEN = false;
            termios.lflag.ISIG   = false;

            posix.tcsetattr(
                writer.instance.?.file.handle,
                posix.TCSA.NOW,
                termios,
            ) catch {
                return error.Unexpected;
            };
        },
        // zig fmt: on

        // zig fmt: off
        .windows => {
            var ret: windows.BOOL = undefined;

            const hIn: windows.HANDLE = std.fs.File.stdin().handle;
            if (hIn == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            var dwModeIn: windows.DWORD = 0;
            ret = windows.GetConsoleMode(hIn, &dwModeIn);
            if (1 != ret) return error.Unexpected;
            original_mode.in = dwModeIn;
            dwModeIn |=  windows.ENABLE_VIRTUAL_TERMINAL_INPUT;
            dwModeIn |=  windows.ENABLE_WINDOW_INPUT;
            dwModeIn &= ~windows.ENABLE_PROCESSED_INPUT;
            dwModeIn &= ~windows.ENABLE_ECHO_INPUT;
            dwModeIn &= ~windows.ENABLE_LINE_INPUT;
            dwModeIn &= ~windows.ENABLE_MOUSE_INPUT;
            ret = windows.SetConsoleMode(hIn, dwModeIn);
            if (1 != ret) return error.Unexpected;

            const hOut: windows.HANDLE = writer.instance.?.file.handle;
            if (hOut == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            var dwModeOut: windows.DWORD = 0;
            ret = windows.GetConsoleMode(hOut, &dwModeOut);
            if (1 != ret) return error.Unexpected;
            original_mode.out = dwModeOut;
            dwModeOut |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            dwModeOut |= windows.ENABLE_PROCESSED_OUTPUT;
            dwModeOut |= windows.ENABLE_WRAP_AT_EOL_OUTPUT;
            dwModeOut |= windows.DISABLE_NEWLINE_AUTO_RETURN;
            ret = windows.SetConsoleMode(hOut, dwModeOut);
            if (1 != ret) return error.Unexpected;
        },
        // zig fmt: on

        else => unreachable,
    }
}

/// ---
/// Release all allocated memory.
///
/// The allocator must match the one used in `init()`.
/// ---
pub fn deinit(allocator: std.mem.Allocator) error{Unexpected}!void {
    switch (builtin.os.tag) {
        .linux, .macos => {
            posix.tcsetattr(
                writer.instance.?.file.handle,
                posix.TCSA.NOW,
                original_mode,
            ) catch {
                return error.Unexpected;
            };
        },

        // zig fmt: off
        .windows => {
            var ret: windows.BOOL = undefined;

            const hIn:  windows.HANDLE = std.fs.File.stdin().handle;
            if (hIn  == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            ret = windows.SetConsoleMode(hIn, original_mode.in);
            if (1 != ret) return error.Unexpected;

            const hOut: windows.HANDLE = writer.instance.?.file.handle;
            if (hOut == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            ret = windows.SetConsoleMode(hOut, original_mode.out);
            if (1 != ret) return error.Unexpected;
        },
        // zig fmt: on

        else => unreachable,
    }

    allocator.free(writer.buffer);
    writer.buffer = &.{};
    writer.instance = null;
}

/// ---
/// Get the underlying terminal stream writer.
///
/// The returned pointer may become invalid in the future (e.g., when you
/// switch to a different stream using `useStdout()` or `useStderr()`)
/// ---
pub fn getWriter() *std.Io.Writer {
    if (writer.instance == null)
        @panic("use before init or after deinit");
    return &writer.instance.?.interface;
}

/// ---
/// Use the standard output stream.
///
/// If the standard output stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard output stream.
/// ---
pub fn useStdout() error{WriteFailed}!void {
    if (writer.instance == null)
        @panic("use before init or after deinit");

    if (writer.instance.?.file.handle == std.fs.File.stdout().handle)
        return;
    std.debug.assert(writer.instance.?.file.handle == std.fs.File.stderr().handle);
    try writer.instance.?.interface.flush();
    writer.instance = std.fs.File.stdout().writerStreaming(writer.buffer);
}

/// ---
/// Use the standard error stream.
///
/// If the standard error stream is already in use this function does nothing.
/// Otherwise it flushes any remaining buffered data from the previous stream
/// and replaces it with the standard error stream.
/// ---
pub fn useStderr() error{WriteFailed}!void {
    if (writer.instance == null)
        @panic("use before init or after deinit");

    if (writer.instance.?.file.handle == std.fs.File.stderr().handle)
        return;
    std.debug.assert(writer.instance.?.file.handle == std.fs.File.stdout().handle);
    try writer.instance.?.interface.flush();
    writer.instance = std.fs.File.stderr().writerStreaming(writer.buffer);
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
const writer = @import("writer.zig");

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}

// test "init(.stdout) should write to stdout" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stdout().handle, writer.instance.?.file.handle);
// }
//
// test "init(.stderr) should write to stderr" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stderr().handle, writer.instance.?.file.handle);
// }
//
// test "useStdout() should switch to stdout" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStdout();
//     try std.testing.expectEqual(std.fs.File.stdout().handle, writer.instance.?.file.handle);
// }
//
// test "useStderr() should switch to stderr" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStderr();
//     try std.testing.expectEqual(std.fs.File.stderr().handle, writer.instance.?.file.handle);
// }
