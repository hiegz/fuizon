const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = @import("posix.zig");
const Dimensions = @import("dimensions.zig").Dimensions;

pub fn getInputHandle() error{NotATerminal}!std.c.fd_t {
    return switch (builtin.os.tag) {
        .linux, .macos => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdin().handle;
            if (std.posix.isatty(handle)) break :tag handle;

            break :tag error.NotATerminal;
        },
        .windows => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdin().handle;
            // if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
            //    break :tag handle;

            // break :tag error.NotATerminal;
            break :tag handle;
        },

        else => unreachable,
    };
}

pub fn getOutputHandle() error{NotATerminal}!std.c.fd_t {
    return switch (builtin.os.tag) {
        .linux, .macos => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdout().handle;
            if (std.posix.isatty(handle)) break :tag handle;

            handle = std.fs.File.stderr().handle;
            if (std.posix.isatty(handle)) break :tag handle;

            break :tag error.NotATerminal;
        },
        .windows => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdout().handle;
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :tag handle;

            handle = std.fs.File.stderr().handle;
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :tag handle;

            break :tag error.NotATerminal;
        },

        else => unreachable,
    };
}

// zig fmt: off

/// Terminal mode that we save before entering the raw mode.
var cooked: switch (builtin.os.tag) {
    .macos, .linux => ?std.posix.termios,
    .windows => struct { output: ?windows.DWORD, input: ?windows.DWORD },
    else => unreachable,
} = undefined;

pub fn enableRawMode() error{Unexpected}!void {
    switch (builtin.os.tag) {
        .linux, .macos => posix.enableRawMode() catch return error.Unexpected,

        .windows => {
            var ret: windows.BOOL = undefined;

            const inputHandle: windows.HANDLE = try getInputHandle();
            if (inputHandle == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            var inputMode: windows.DWORD = 0;
            ret = windows.GetConsoleMode(inputHandle, &inputMode);
            if (1 != ret) return error.Unexpected;
            cooked.input = inputMode;
            inputMode |= windows.ENABLE_VIRTUAL_TERMINAL_INPUT;
            inputMode |= windows.ENABLE_WINDOW_INPUT;
            inputMode &= ~windows.ENABLE_PROCESSED_INPUT;
            inputMode &= ~windows.ENABLE_ECHO_INPUT;
            inputMode &= ~windows.ENABLE_LINE_INPUT;
            inputMode &= ~windows.ENABLE_MOUSE_INPUT;
            ret = windows.SetConsoleMode(inputHandle, inputMode);
            if (1 != ret) return error.Unexpected;

            const outputHandle: windows.HANDLE = try getOutputHandle();
            if (outputHandle == windows.INVALID_HANDLE_VALUE) return error.Unexpected;
            var outputMode: windows.DWORD = 0;
            ret = windows.GetConsoleMode(outputHandle, &outputMode);
            if (1 != ret) return error.Unexpected;
            cooked.output = outputMode;
            outputMode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            outputMode |= windows.ENABLE_PROCESSED_OUTPUT;
            outputMode |= windows.ENABLE_WRAP_AT_EOL_OUTPUT;
            outputMode |= windows.DISABLE_NEWLINE_AUTO_RETURN;
            ret = windows.SetConsoleMode(outputHandle, outputMode);
            if (1 != ret) return error.Unexpected;
        },

        else => unreachable,
    }
}

pub fn disableRawMode() error{ NotATerminal, Unexpected }!void {
    switch (builtin.os.tag) {
        .linux, .macos => posix.disableRawMode() catch return error.Unexpected,
        .windows => {
            if (cooked.input) |input| {
                const handle = try getInputHandle();
                const ret = windows.SetConsoleMode(handle, input);
                if (ret == 0) return error.Unexpected;
            }

            if (cooked.output) |output| {
                const handle = try getOutputHandle();
                const ret = windows.SetConsoleMode(handle, output);
                if (ret == 0) return error.Unexpected;
            }
        },

        else => unreachable,
    }
}

pub fn getScreenSize() error{ Unexpected }!Dimensions {
    return switch (builtin.os.tag) {
        .linux, .macos => posix.getScreenSize() catch return error.Unexpected,

        .windows => tag: {
            var ret: windows.BOOL = undefined;
            var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            const handle = try getOutputHandle();

            ret = windows.GetConsoleScreenBufferInfo(handle, &info);
            if (ret == 0) return error.Unexpected;

            break :tag Dimensions{
                .width = @intCast(info.dwSize.X),
                .height = @intCast(info.dwSize.Y),
            };
        },

        else => unreachable,
    };
}
