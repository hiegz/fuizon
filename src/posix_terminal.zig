const std = @import("std");

const Dimensions = @import("dimensions.zig").Dimensions;
const InputParser = @import("input_parser.zig").InputParser;
const Input = @import("input.zig").Input;
const TerminalWriter = @import("terminal_writer.zig").TerminalWriter;

pub const PosixTerminal = struct {
    pub const Handle = std.posix.fd_t;

    // zig fmt: off
    out: Handle,
    in:  Handle,
    // zig fmt: on

    /// Terminal mode that we save before entering the raw mode.
    cooked: ?std.posix.termios,

    var _instance: ?PosixTerminal = null;

    pub fn instance() *PosixTerminal {
        if (_instance) |*ret| return ret;
        _instance = PosixTerminal.init();
        return &_instance.?;
    }

    fn init() PosixTerminal {
        // zig fmt: off
        var self: PosixTerminal = undefined;
        self.out = std.posix.open("/dev/tty",   .{ .ACCMODE = .WRONLY }, 0) catch @panic("could not open /dev/tty");
        self.in  = std.posix.open("/dev/stdin", .{ .ACCMODE = .RDONLY }, 0) catch @panic("could not open /dev/stdin");
        self.cooked = null;
        return self;
        // zig fmt: on
    }

    pub fn output(self: PosixTerminal) Handle {
        return self.out;
    }

    pub fn input(self: PosixTerminal) Handle {
        return self.in;
    }

    pub fn isTty(maybe_handle: ?std.posix.fd_t) bool {
        if (maybe_handle == null)
            return false;
        const handle = maybe_handle.?;
        return std.posix.isatty(handle);
    }

    pub fn getScreenSize(self: PosixTerminal) error{Unexpected}!Dimensions {
        // zig fmt: off
        var ret     = @as(c_int, undefined);
        var winsize = @as(std.posix.winsize, undefined);
        // zig fmt: on

        ret = std.c.ioctl(self.out, std.posix.T.IOCGWINSZ, &winsize);
        if (0 != ret)
            return error.Unexpected;

        return Dimensions.init(winsize.col, winsize.row);
    }

    pub fn enableRawMode(self: *PosixTerminal) error{Unexpected}!void {
        // zig fmt: off

        if (self.cooked != null)
            return;

        var   mode   = std.posix.tcgetattr(self.out) catch return error.Unexpected;
        const cooked = mode;

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

        std.posix.tcsetattr(self.out, std.posix.TCSA.NOW, mode)
            catch return error.Unexpected;

        self.cooked = cooked;

        // zig fmt: on
    }

    pub fn disableRawMode(self: *PosixTerminal) error{Unexpected}!void {
        if (self.cooked == null) return;
        std.posix.tcsetattr(
            self.out,
            std.posix.TCSA.NOW,
            self.cooked.?,
        ) catch return error.Unexpected;
        self.cooked = null;
    }

    pub fn writer(self: *PosixTerminal, gpa: std.mem.Allocator, buffer: []u8) TerminalWriter {
        return .init(gpa, self, buffer);
    }

    pub fn writeAll(
        self: PosixTerminal,
        gpa: std.mem.Allocator,
        bytes: []const u8,
    ) error{WriteFailed}!void {
        _ = gpa;
        (std.fs.File{ .handle = self.out }).writeAll(bytes) catch return error.WriteFailed;
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

    pub const ReadInputOptions = struct {
        timeout: ?u32 = null,
    };

    pub fn readInput(
        self: PosixTerminal,
        opts: ReadInputOptions,
    ) error{ ReadFailed, PollFailed, Interrupted, Unexpected }!?Input {
        const handle = self.in;
        var ret: usize = undefined;
        var byte: u8 = undefined;
        var parser: InputParser = .{};
        var result: InputParser.Result = .none;

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
        fds[0].fd = handle;
        fds[0].events = std.posix.POLL.IN;

        var timespec: std.posix.timespec = undefined;
        var timeout: ?*std.posix.timespec = null;

        if (opts.timeout) |to| {
            timeout = &timespec;
            timespec.sec = @intCast((to / 1000));
            timespec.nsec = @intCast((to % 1000) * std.time.ns_per_ms);
        }

        ret = std.posix.ppoll(&fds, timeout, &oldset) catch |err| switch (err) {
            error.SignalInterrupt => return {
                if (winch.load(.acquire) == false)
                    return error.Interrupted;
                winch.store(false, .release);
                return .resize;
            },
            else => return error.PollFailed,
        };

        // timeout expired
        if (ret == 0)
            return null;

        std.debug.assert(ret == 1);

        timeout = &timespec;
        timespec.sec = 0;
        timespec.nsec = 0;

        while (true) {
            if (fds[0].revents & std.posix.POLL.IN == 0)
                return error.ReadFailed;

            ret = std.posix.read(handle, @ptrCast(&byte)) catch return error.ReadFailed;
            if (ret == 0) return error.ReadFailed;

            result = try parser.step(byte);

            if (result == .final)
                return result.final;

            ret = std.posix.ppoll(&fds, timeout, null) catch |err| switch (err) {
                error.SignalInterrupt => return error.Interrupted,
                else => return error.PollFailed,
            };

            if (result == .ambiguous and ret == 0)
                return result.ambiguous;

            if (result == .none and ret == 0)
                return error.ReadFailed;
        }
    }
};
