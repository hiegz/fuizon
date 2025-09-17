const std = @import("std");
const builtin = @import("builtin");
const posix = std.posix;
const windows = @import("windows.zig");
const EventQueue = @import("event_queue.zig");

pub var events: ?EventQueue = null;

pub var buffer: []u8 = &.{};
pub var writer: ?std.fs.File.Writer = null;

pub var original_mode: switch (builtin.os.tag) {
    .macos, .linux => posix.termios,
    .windows => struct { out: windows.DWORD, in: windows.DWORD },
    else => unreachable,
} = undefined;
