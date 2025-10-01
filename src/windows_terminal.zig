const std = @import("std");
const windows = @import("windows.zig");

const Dimensions = @import("dimensions.zig").Dimensions;
const Input = @import("input.zig").Input;
const InputParser = @import("input_parser.zig").InputParser;
const TerminalWriter = @import("terminal_writer.zig").TerminalWriter;

pub const WindowsTerminal = struct {
    pub const Handle = windows.HANDLE;

    // zig fmt: off

    out: ?Handle,
    in:   Handle,

    cookedInput:  ?windows.DWORD,
    cookedOutput: ?windows.DWORD,

    // zig fmt: on

    var _instance: ?WindowsTerminal = null;

    pub fn instance() *WindowsTerminal {
        if (_instance) |*ret| return ret;
        _instance = WindowsTerminal.init();
        return &_instance.?;
    }

    fn init() WindowsTerminal {
        var self: WindowsTerminal = undefined;

        self.out = null;
        self.cookedOutput = null;
        self.cookedInput = null;

        self.out = out: {
            var handle: Handle = undefined;

            handle = windows.GetStdHandle(windows.STD_OUTPUT_HANDLE);
            if (handle == windows.INVALID_HANDLE_VALUE)
                @panic("Could not open stdout");
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :out handle;

            handle = windows.GetStdHandle(windows.STD_ERROR_HANDLE);
            if (handle == windows.INVALID_HANDLE_VALUE)
                @panic("Could not open stderr");
            if (windows.GetFileType(handle) == windows.FILE_TYPE_CHAR)
                break :out handle;

            break :out null;
        };

        self.in = windows.GetStdHandle(windows.STD_INPUT_HANDLE);
        if (self.in == windows.INVALID_HANDLE_VALUE)
            @panic("Could not open stdin");

        return self;
    }

    pub fn output(self: WindowsTerminal) ?Handle {
        return self.out;
    }

    pub fn input(self: WindowsTerminal) Handle {
        return self.in;
    }

    pub fn isTty(maybe_handle: ?Handle) bool {
        if (maybe_handle == null)
            return false;
        const handle = maybe_handle.?;
        return windows.GetFileType(handle) == windows.FILE_TYPE_CHAR;
    }

    pub fn getScreenSize(self: WindowsTerminal) error{Unexpected}!Dimensions {
        std.debug.assert(isTty(self.out));

        // zig fmt: off
        var   info = @as(windows.CONSOLE_SCREEN_BUFFER_INFO, undefined);
        const ret  = windows.GetConsoleScreenBufferInfo(self.out.?, &info);
        if (ret == 0)
            return error.Unexpected;
        // zig fmt: on

        return Dimensions.init(
            @intCast(info.dwSize.X),
            @intCast(info.dwSize.Y),
        );
    }

    pub fn enableRawMode(self: *WindowsTerminal) error{Unexpected}!void {
        // zig fmt: off

        if (isTty(self.out)) out: {
            if (self.cookedOutput != null)
                break :out;

            const handle = self.out.?;
            var   mode   = @as(windows.DWORD, undefined);
            var   ret    = @as(windows.BOOL,  undefined);

            ret = windows.GetConsoleMode(handle, &mode);
            if (ret == 0) return error.Unexpected;

            const cooked = mode;

            mode |= windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            mode |= windows.ENABLE_PROCESSED_OUTPUT;
            mode |= windows.ENABLE_WRAP_AT_EOL_OUTPUT;
            mode |= windows.DISABLE_NEWLINE_AUTO_RETURN;

            ret = windows.SetConsoleMode(handle, mode);
            if (ret == 0)
                return error.Unexpected;

            self.cookedOutput = cooked;
        }

        if (isTty(self.in)) in: {
            if (self.cookedInput != null)
                break :in;

            const handle = self.in;
            var   mode   = @as(windows.DWORD, undefined);
            var   ret    = @as(windows.BOOL,  undefined);

            ret = windows.GetConsoleMode(handle, &mode);
            if (ret == 0) return error.Unexpected;

            const cooked = mode;

            mode |=  windows.ENABLE_VIRTUAL_TERMINAL_INPUT;
            mode |=  windows.ENABLE_WINDOW_INPUT;
            mode &= ~windows.ENABLE_PROCESSED_INPUT;
            mode &= ~windows.ENABLE_ECHO_INPUT;
            mode &= ~windows.ENABLE_LINE_INPUT;
            mode &= ~windows.ENABLE_MOUSE_INPUT;

            ret = windows.SetConsoleMode(handle, mode);
            if (1 != ret) return error.Unexpected;

            self.cookedInput = cooked;
        }

        // zig fmt: on
    }

    pub fn disableRawMode(self: *WindowsTerminal) error{Unexpected}!void {
        if (isTty(self.out)) out: {
            if (self.cookedOutput == null)
                break :out;

            const handle = self.out.?;
            const ret = windows.SetConsoleMode(handle, self.cookedOutput.?);
            if (ret == 0) return error.Unexpected;

            self.cookedOutput = null;
        }

        if (isTty(self.in)) in: {
            if (self.cookedInput == null)
                break :in;

            const handle = self.in;
            const ret = windows.SetConsoleMode(handle, self.cookedInput.?);
            if (ret == 0) return error.Unexpected;

            self.cookedInput = null;
        }
    }

    pub fn writer(self: *WindowsTerminal, gpa: std.mem.Allocator, buffer: []u8) TerminalWriter {
        return .init(gpa, self, buffer);
    }

    // zig fmt: off

    pub fn writeAll(
        self: WindowsTerminal,
        gpa: std.mem.Allocator,
        bytes: []const u8,
    ) error{ OutOfMemory, WriteFailed }!void {
        std.debug.assert(isTty(self.out));

        const handle = self.out.?;

        const utf16 = std.unicode.utf8ToUtf16LeAlloc(gpa, bytes) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidUtf8 => return error.WriteFailed,
        };
        defer gpa.free(utf16);

        var todo    = utf16.len;
        var done    = @as(usize, 0);
        var ret     = @as(windows.BOOL,  undefined);
        var written = @as(windows.DWORD, undefined);

        while (todo != 0) {
            ret = windows.WriteConsoleW(handle, utf16[done..].ptr, @intCast(todo), &written, null);
            if (ret == 0) return error.WriteFailed;
            done += @intCast(written);
            todo -= @intCast(written);
        }
    }

    pub const ReadInputOptions = struct {
        timeout: ?u32 = null,
    };

    pub fn readInput(
        self: WindowsTerminal,
        opts: ReadInputOptions,
    ) error{ ReadFailed, PollFailed, Unexpected }!?Input {
        const timeout = if (opts.timeout) |t| t else windows.INFINITE;

        while (true) {
            return self.readInputOnce(timeout) catch |err| switch (err) {
                error.InvalidEvent => continue,
                else => |e| e,
            };
        }
    }

    fn readInputOnce(
        self: WindowsTerminal,
        timeout: windows.DWORD,
    ) error{ReadFailed, PollFailed, InvalidEvent, Unexpected}!?Input {
        return switch (isTty(self.in)) {
            true  => self.readInputFromTty(timeout),
            false => self.readInputFromFile(timeout),
        };
    }

    fn readInputFromTty(self: WindowsTerminal, timeout: windows.DWORD) error{ReadFailed, PollFailed, InvalidEvent, Unexpected}!?Input {
        std.debug.assert(isTty(self.in));

        var ready        = @as(bool, undefined);
        var parser       = @as(InputParser, .{});
        var result       = @as(InputParser.Result, .none);

        ready = try self.poll(timeout);
        if (!ready) return null;

        const record = try self.peekConsoleInput();

        switch (record.EventType) {
            windows.WINDOW_BUFFER_SIZE_EVENT => {
                try self.discardConsoleInput();
                return .resize;
            },

            windows.KEY_EVENT => tag: {
                if (record.Event.KeyEvent.bKeyDown == 1)
                    break :tag;

                try self.discardConsoleInput();
                return error.InvalidEvent;
            },

            windows.FOCUS_EVENT,
            windows.MENU_EVENT => {
                try self.discardConsoleInput();
                return error.InvalidEvent;
            },

            // mouse events are disabled at the moment
            windows.MOUSE_EVENT
                => return error.Unexpected,

            else => unreachable,
        }

        while (true) {
            const codepoint =
                self.readConsoleCodepoint() catch |err| switch (err) {
                    error.EndOfFile =>     return .eof,
                    else            => |e| return e,
                };

            const length = std.unicode.utf8CodepointSequenceLength(codepoint) catch return error.Unexpected;

            if (length == 1)
                result = try parser.step(@intCast(codepoint))
            else
                result = parser.unicode(codepoint);

            if (result == .final)
                return result.final;

            ready = try self.poll(0);

            if (!ready and result == .none)
                return error.Unexpected;

            if (!ready and result == .ambiguous)
                return result.ambiguous;
        }
    }

    /// Reads the next console input record without removing it from the
    /// buffer. To discard that record, call `discardConsoleInput`.
    fn peekConsoleInput(self: WindowsTerminal) error{ReadFailed, Unexpected}!windows.INPUT_RECORD {
        std.debug.assert(isTty(self.in));

        var records = @as([1]windows.INPUT_RECORD, undefined);
        var read    = @as(windows.DWORD, undefined);

        const ret = windows.PeekConsoleInputW(self.in, &records, 1, &read);
        if (ret  == 0) return error.ReadFailed;
        if (read != 1) return error.Unexpected;

        return records[0];
    }

    /// Discards the next console input record.
    fn discardConsoleInput(self: WindowsTerminal) error{ReadFailed, Unexpected}!void {
        std.debug.assert(isTty(self.in));

        var records = @as([1]windows.INPUT_RECORD, undefined);
        var read    = @as(windows.DWORD, undefined);

        const ret = windows.ReadConsoleInputW(self.in, &records, 1, &read);
        if (ret  == 0) return error.ReadFailed;
        if (read != 1) return error.Unexpected;
    }

    fn readConsoleCharacter(self: WindowsTerminal) error{ReadFailed, EndOfFile, Unexpected}!windows.WCHAR {
        var chars = @as([1]windows.WCHAR, undefined);
        var read  = @as(windows.DWORD, undefined);

        const ret = windows.ReadConsoleW(self.in, @ptrCast(&chars), 1, &read, null);
        if (ret  == 0) return error.ReadFailed;
        if (read == 0) return error.EndOfFile;

        return chars[0];
    }

    fn readConsoleCodepoint(self: WindowsTerminal) error{ReadFailed, PollFailed, EndOfFile, Unexpected}!u21 {
        var ready = @as(bool, undefined);
        var curr  = @as(u16,  undefined);
        var prev  = @as(u16,  undefined);

        while (true) {
            curr = try self.readConsoleCharacter();

            if (std.unicode.utf16IsHighSurrogate(curr)) {
                prev = curr;

                ready = try self.poll(0);
                if (!ready) return error.Unexpected;

                continue;
            }

            if (std.unicode.utf16IsLowSurrogate(curr)) {
                const pair: []const u16 = &.{prev, curr};
                return std.unicode.utf16DecodeSurrogatePair(pair) catch error.Unexpected;
            }

            return curr;
        }
    }

    fn readInputFromFile(self: WindowsTerminal, timeout: windows.DWORD) error{ReadFailed, PollFailed, Unexpected}!?Input {
        std.debug.assert(!isTty(self.in));

        var bytes  = @as([1]u8, undefined);
        var ret    = @as(windows.BOOL, undefined);
        var nread  = @as(windows.DWORD , undefined);
        var ready  = @as(bool, undefined);
        var parser = @as(InputParser, .{});
        var result = @as(InputParser.Result, .none);

        ready = try self.poll(timeout);
        if (!ready) return null;

        while (true) {
            ret = windows.ReadFile(self.in, &bytes, 1, &nread, null);
            if (ret != 0) return error.ReadFailed;
            if (nread == 0) return .eof;

            result = try parser.step(bytes[0]);

            if (result == .final)
                return result.final;

            ready = try self.poll(0);

            if (!ready and result == .none)
                return error.Unexpected;

            if (!ready and result == .ambiguous)
                return result.ambiguous;
        }

    }

    // zig fmt: on

    fn poll(
        self: WindowsTerminal,
        timeout: windows.DWORD,
    ) error{PollFailed}!bool {
        const wait_ret = windows.WaitForSingleObject(self.in, timeout);

        if (wait_ret == windows.WAIT_ABANDONED)
            return error.PollFailed;

        if (wait_ret == windows.WAIT_FAILED)
            return error.PollFailed;

        if (wait_ret == windows.WAIT_TIMEOUT)
            return false;

        return true;
    }
};
