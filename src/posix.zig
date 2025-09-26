const std = @import("std");

const Dimensions = @import("dimensions.zig").Dimensions;
const Input = @import("input.zig").Input;
const InputParser = @import("input_parser.zig").InputParser;
const Source = @import("source.zig").Source;
const terminal = @import("terminal.zig");

// zig fmt: off

/// Terminal mode that we save before entering the raw mode.
var cooked: ?std.posix.termios = null;

pub fn enableRawMode() !void {
    const flags   =     std.posix.O { .ACCMODE = .RDWR };
    const tty     = try std.posix.open("/dev/tty", flags, 0);
    var   mode    = try std.posix.tcgetattr(tty);
    const _cooked = mode;

    // cfmakeraw
    //
    // man page: https://www.man7.org/linux/man-pages/man3/termios.3.html

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

    try std.posix.tcsetattr(tty, std.posix.TCSA.NOW, mode);

    cooked = _cooked;
}

pub fn disableRawMode() !void {
    if (cooked == null) return;

    const flags =     std.posix.O { .ACCMODE = .RDWR };
    const tty   = try std.posix.open("/dev/tty", flags, 0);

    try std.posix.tcsetattr(tty, std.posix.TCSA.NOW, cooked.?);

    cooked = null;
}

pub fn getScreenSize() !Dimensions {
    var   ret   = @as(c_int, undefined);
    var   ws    = @as(std.posix.winsize, undefined);
    const flags =     std.posix.O { .ACCMODE = .RDWR };
    const tty   = try std.posix.open("/dev/tty", flags, 0);

    ret = std.c.ioctl(tty, std.posix.T.IOCGWINSZ, &ws);
    if (0 != ret) return error.Unexpected;

    return Dimensions.init(ws.col, ws.row);
}

/// Flag to indicate that a SIGWINCH signal interrupted.
///
/// Only relevant inside fuizon.read() (see below)
var winch: std.atomic.Value(bool) = .init(false);

fn sighandler(signo: c_int) callconv(.c) void {
    if (signo == std.posix.SIG.WINCH) {
        winch.store(true, .release);
    }
}

pub fn read(source: Source, maybe_timeout: ?u32) error{ NotATerminal, ReadFailed, Interrupted, Unexpected }!?Input {
    const input:  std.posix.fd_t     = switch (source) { .stdin => std.fs.File.stdin().handle, .file => |f| f.handle };
    var   ret:    usize              = undefined;
    var   byte:   u8                 = undefined;
    var   parser: InputParser        = .{};
    var   result: InputParser.Result = .none;

    // Install the SIGWINCH signal handler.
    var oldact: std.posix.Sigaction = undefined;
    var newact: std.posix.Sigaction = undefined;
    newact.handler = .{ .handler = sighandler };
    newact.mask = std.posix.sigemptyset();
    newact.flags = 0;
    std.posix.sigaction(std.posix.SIG.WINCH, &newact, &oldact);
    defer std.posix.sigaction(std.posix.SIG.WINCH, &oldact, null);

    // Block SIGWINCH from now on.
    //
    // Generally, we don’t want SIGWINCH to interrupt reading.
    //
    // The only exception is when we’re waiting for user input;
    // in that case, a window resize event is also relevant.
    var oldset: std.posix.sigset_t = undefined;
    var newset: std.posix.sigset_t = std.posix.sigemptyset();
    std.posix.sigaddset(&newset, std.posix.SIG.WINCH);
    std.posix.sigprocmask(std.posix.SIG.BLOCK, &newset, &oldset);
    defer std.posix.sigprocmask(std.posix.SIG.SETMASK, &oldset, null);

    var fds: [1]std.posix.pollfd = undefined;
    fds[0].fd = input;
    fds[0].events = std.posix.POLL.IN;

    var timespec:   std.posix.timespec = undefined;
    var timeout:  ?*std.posix.timespec = null;

    if (maybe_timeout) |to| {
        timeout       = &timespec;
        timespec.sec  = @intCast((to / 1000));
        timespec.nsec = @intCast((to % 1000) * std.time.ns_per_ms);
    }

    ret = std.posix.ppoll(&fds, timeout, &oldset) catch |err| switch (err) {
        error.SignalInterrupt => return {
            if (winch.load(.acquire) == false)
                return error.Interrupted;
            winch.store(false, .release);
            return .resize;
        },
        else => return error.ReadFailed,
    };

    // timeout expired
    if (ret == 0)
        return null;

    std.debug.assert(ret == 1);

    timeout = &timespec;
    timespec.sec  = 0;
    timespec.nsec = 0;

    while (true) {
        if (fds[0].revents & std.posix.POLL.IN == 0)
            return error.ReadFailed;

        ret = std.posix.read(input, @ptrCast(&byte)) catch return error.ReadFailed;
        if (ret == 0) return error.ReadFailed;

        result = try parser.step(byte);

        if (result == .final)
            return result.final;

        ret = std.posix.ppoll(&fds, timeout, null) catch |err| switch (err) {
            error.SignalInterrupt => return error.Interrupted,
            else                  => return error.ReadFailed,
        };

        if (result == .ambiguous and ret == 0)
            return result.ambiguous;

        if (result == .none and ret == 0)
            return error.ReadFailed;
    }
}
