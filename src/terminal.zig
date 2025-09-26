const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = @import("posix.zig");
const Dimensions = @import("dimensions.zig").Dimensions;

// zig fmt: off

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
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :tag handle;

            break :tag error.NotATerminal;
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

/// Terminal mode that we save before entering the raw mode.
var cooked: switch (builtin.os.tag) {
    .macos, .linux => ?std.posix.termios,
    .windows => struct { output: ?windows.DWORD, input: ?windows.DWORD },
    else => unreachable,
} = undefined;

pub fn enableRawMode() error{Unexpected}!void {
    const err =
        switch (builtin.os.tag) {
            .linux, .macos => posix.enableRawMode(),
            .windows       => windows.enableRawMode(),

            else => unreachable,
        };

    err catch return error.Unexpected;
}

pub fn disableRawMode() error{Unexpected}!void {
    const err =
        switch (builtin.os.tag) {
            .linux, .macos => posix.disableRawMode(),
            .windows       => windows.disableRawMode(),

            else => unreachable,
        };

    err catch return error.Unexpected;
}

pub fn getScreenSize() error{ Unexpected }!Dimensions {
    const maybe_dimensions =
        switch (builtin.os.tag) {
            .linux, .macos => posix.getScreenSize(),
            .windows       => windows.getScreenSize(),

            else => unreachable,
        };

    return maybe_dimensions catch return error.Unexpected;
}
