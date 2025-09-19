const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = std.posix;

fn getInputHandle() error{NotATerminal}!std.c.fd_t {
    return switch (builtin.os.tag) {
        .linux, .macos => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdin().handle;
            if (posix.isatty(handle)) break :tag handle;

            break :tag error.NotATerminal;
        },
        .windows => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdin().handle;
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :tag handle;

            break :tag error.NotATerminal;
        },

        else => unreachable,
    };
}

fn getOutputHandle() error{NotATerminal}!std.c.fd_t {
    return switch (builtin.os.tag) {
        .linux, .macos => tag: {
            var handle: std.c.fd_t = undefined;

            handle = std.fs.File.stdout().handle;
            if (posix.isatty(handle)) break :tag handle;

            handle = std.fs.File.stderr().handle;
            if (posix.isatty(handle)) break :tag handle;

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

/// Terminal mode that we save before entering the raw mode.
var cooked: switch (builtin.os.tag) {
    .macos, .linux => ?posix.termios,
    .windows => struct { output: ?windows.DWORD, input: ?windows.DWORD },
    else => unreachable,
} = undefined;

pub fn enableRawMode() error{ NotATerminal, Unexpected }!void {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const handle = try getOutputHandle();
            var mode = posix.tcgetattr(handle) catch return error.Unexpected;

            cooked = mode;

            // cfmakeraw
            //
            // man page: https://www.man7.org/linux/man-pages/man3/termios.3.html

            // zig fmt: off
            mode.iflag.IGNBRK = false;
            mode.iflag.BRKINT = false;
            mode.iflag.PARMRK = false;
            mode.iflag.ISTRIP = false;
            mode.iflag.INLCR  = false;
            mode.iflag.IGNCR  = false;
            mode.iflag.ICRNL  = false;
            mode.iflag.IXON   = false;
            mode.oflag.OPOST  = false;
            mode.lflag.ECHO   = false;
            mode.lflag.ECHONL = false;
            mode.lflag.ICANON = false;
            mode.lflag.IEXTEN = false;
            mode.lflag.ISIG   = false;
            mode.cflag.CSIZE  = .CS8;
            mode.cflag.PARENB = false;
            // zig fmt: on

            posix.tcsetattr(handle, posix.TCSA.NOW, mode) catch return error.Unexpected;
        },
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
        .linux, .macos => {
            if (cooked == null) return;
            const handle = try getOutputHandle();
            posix.tcsetattr(handle, posix.TCSA.NOW, cooked.?) catch return error.Unexpected;
        },
        .windows => {
            const handle = try getOutputHandle();
            const ret = windows.SetConsoleMode(handle, cooked);
            if (ret == 0) return error.Unexpected;
        },

        else => unreachable,
    }
}
