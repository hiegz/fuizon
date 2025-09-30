const std = @import("std");
const builtin = @import("builtin");

const PosixTerminal = @import("posix_terminal.zig").PosixTerminal;
const WindowsTerminal = @import("windows_terminal.zig").WindowsTerminal;

// zig fmt: off

pub const Terminal =
    switch (builtin.os.tag) {
        .linux, .macos =>   PosixTerminal,
        .windows       => WindowsTerminal,

        else => unreachable,
    };
