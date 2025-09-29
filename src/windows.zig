// zig fmt: off

const std = @import("std");
const windows = std.os.windows;
const terminal = @import("terminal.zig");
const Source = @import("source.zig").Source;
const Dimensions = @import("dimensions.zig").Dimensions;
const Input = @import("input.zig").Input;
const InputParser = @import("input_parser.zig").InputParser;

pub const ENABLE_PROCESSED_INPUT:             windows.DWORD = 0x0001;
pub const ENABLE_ECHO_INPUT:                  windows.DWORD = 0x0004;
pub const ENABLE_LINE_INPUT:                  windows.DWORD = 0x0002;
pub const ENABLE_WINDOW_INPUT:                windows.DWORD = 0x0008;
pub const ENABLE_MOUSE_INPUT:                 windows.DWORD = 0x0010;
pub const ENABLE_VIRTUAL_TERMINAL_INPUT:      windows.DWORD = 0x0200;

pub const ENABLE_PROCESSED_OUTPUT:            windows.DWORD = 0x0001;
pub const ENABLE_WRAP_AT_EOL_OUTPUT:          windows.DWORD = 0x0002;
pub const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;
pub const DISABLE_NEWLINE_AUTO_RETURN:        windows.DWORD = 0x0008;

pub const INVALID_HANDLE_VALUE = windows.INVALID_HANDLE_VALUE;

pub const FILE_TYPE_CHAR    = 0x0002;
pub const FILE_TYPE_DISK    = 0x0001;
pub const FILE_TYPE_PIPE    = 0x0003;
pub const FILE_TYPE_REMOTE  = 0x8000;
pub const FILE_TYPE_UNKNOWN = 0x0000;

pub const HANDLE     = windows.HANDLE;
pub const UINT       = windows.UINT;
pub const CHAR       = windows.CHAR;
pub const WCHAR      = windows.WCHAR;
pub const WORD       = windows.WORD;
pub const DWORD      = windows.DWORD;
pub const BOOL       = windows.BOOL;
pub const COORD      = windows.COORD;
pub const SMALL_RECT = windows.SMALL_RECT;
pub const CONSOLE_SCREEN_BUFFER_INFO = windows.CONSOLE_SCREEN_BUFFER_INFO;

pub const WAIT_ABANDONED = windows.WAIT_ABANDONED;
pub const WAIT_OBJECT_0  = windows.WAIT_OBJECT_0;
pub const WAIT_TIMEOUT   = windows.WAIT_TIMEOUT;
pub const WAIT_FAILED    = windows.WAIT_FAILED;

pub const INFINITE = windows.INFINITE;

pub const INPUT_RECORD = extern struct {
    EventType: windows.WORD,
    Event: extern union {
        KeyEvent:              KEY_EVENT_RECORD,
        MouseEvent:            MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent:             MENU_EVENT_RECORD,
        FocusEvent:            FOCUS_EVENT_RECORD,
    },
};

pub const FOCUS_EVENT              = 0x0010;
pub const KEY_EVENT                = 0x0001;
pub const MENU_EVENT               = 0x0008;
pub const MOUSE_EVENT              = 0x0002;
pub const WINDOW_BUFFER_SIZE_EVENT = 0x0004;

pub const KEY_EVENT_RECORD = extern struct {
    bKeyDown:          windows.BOOL,
    wRepeatCount:      windows.WORD,
    wVirtualKeyCode:   windows.WORD,
    wVirtualScanCode:  windows.WORD,
    uChar: extern union {
        UnicodeChar:   windows.WCHAR,
        AsciiChar:     windows.CHAR,
    },
    dwControlKeyState: windows.DWORD,
};

pub const MOUSE_EVENT_RECORD = extern struct {
    dwMousePosition:   windows.COORD,
    dwButtonState:     windows.DWORD,
    dwControlKeyState: windows.DWORD,
    dwEventFlags:      windows.DWORD,
};

pub const FROM_LEFT_1ST_BUTTON_PRESSED = 0x0001;
pub const FROM_LEFT_2ND_BUTTON_PRESSED = 0x0004;
pub const FROM_LEFT_3RD_BUTTON_PRESSED = 0x0008;
pub const FROM_LEFT_4TH_BUTTON_PRESSED = 0x0010;
pub const RIGHTMOST_BUTTON_PRESSED     = 0x0002;

pub const CAPSLOCK_ON                  = 0x0080;
pub const ENHANCED_KEY                 = 0x0100;
pub const LEFT_ALT_PRESSED             = 0x0002;
pub const LEFT_CTRL_PRESSED            = 0x0008;
pub const NUMLOCK_ON                   = 0x0020;
pub const RIGHT_ALT_PRESSED            = 0x0001;
pub const RIGHT_CTRL_PRESSED           = 0x0004;
pub const SCROLLLOCK_ON                = 0x0040;
pub const SHIFT_PRESSED                = 0x0010;

pub const DOUBLE_CLICK                 = 0x0002;
pub const MOUSE_HWHEELED               = 0x0008;
pub const MOUSE_MOVED                  = 0x0001;
pub const MOUSE_WHEELED                = 0x0004;

pub const WINDOW_BUFFER_SIZE_RECORD = extern struct {
    dwSize: windows.COORD,
};

pub const MENU_EVENT_RECORD = extern struct {
    dwCommandId: windows.UINT,
};

pub const FOCUS_EVENT_RECORD = extern struct {
    bSetFocus: windows.BOOL,
};

pub extern fn GetConsoleScreenBufferInfo(hConsoleOutput: windows.HANDLE, info: *windows.CONSOLE_SCREEN_BUFFER_INFO) windows.BOOL;
pub extern fn GetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: *windows.DWORD) windows.BOOL;
pub extern fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode:  windows.DWORD) windows.BOOL;
pub extern fn GetFileType(hConsoleHandle: windows.HANDLE) windows.DWORD;
pub extern fn WaitForSingleObject(hHandle: windows.HANDLE, dwMilliseconds: windows.DWORD) windows.DWORD;
pub extern fn ReadConsoleW(hConsoleInput: HANDLE, lpBuffer: ?*anyopaque, nNumberOfCharsToRead: DWORD, lpNumberOfCharsRead: *DWORD, pInputControl: ?*anyopaque) BOOL;
pub extern fn ReadConsoleInputW(hConsoleInput: windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: windows.DWORD, lpNumberOfEventsRead: *windows.DWORD) windows.BOOL;
pub extern fn PeekConsoleInputW(hConsoleInput: windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: windows.DWORD, lpNumberOfEventsRead: *windows.DWORD) windows.BOOL;
pub extern fn WriteConsoleW(hConsoleOutput: windows.HANDLE, lpBuffer: [*]const u16, nNumberOfCharsToWrite: DWORD, lpNumberOfCharsWritter: *DWORD, lpReserved: ?*anyopaque) BOOL;

//

/// Selects an input handle linked to the controlling terminal (if any)
fn selectInputHandle() ?HANDLE {
    var handle: HANDLE = undefined;

    handle = std.fs.File.stdin().handle;
    if (GetFileType(handle) == FILE_TYPE_CHAR)
        return handle;

    return null;
}

/// Selects an output handle linked to the controlling terminal (if any)
pub fn selectOutputHandle() ?HANDLE {
    var handle: HANDLE = undefined;

    handle = std.fs.File.stdout().handle;
    if (GetFileType(handle) == FILE_TYPE_CHAR)
        return handle;

    handle = std.fs.File.stderr().handle;
    if (GetFileType(handle) == FILE_TYPE_CHAR)
        return handle;

    return null;
}

var cookedInput:  ?DWORD = null;
var cookedOutput: ?DWORD = null;

pub fn enableRawMode() !void {
    var ret: BOOL = undefined;

    if (selectOutputHandle()) |handle| {
        var mode: DWORD = 0;
        ret = GetConsoleMode(handle, &mode);
        if (ret == 0)
            return error.Unexpected;

        const _cooked = mode;

        mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        mode |= ENABLE_PROCESSED_OUTPUT;
        mode |= ENABLE_WRAP_AT_EOL_OUTPUT;
        mode |= DISABLE_NEWLINE_AUTO_RETURN;

        ret = SetConsoleMode(handle, mode);
        if (ret == 0)
            return error.Unexpected;

        cookedOutput = _cooked;
    }

    if (selectInputHandle()) |handle| {
        var mode: DWORD = 0;
        ret = GetConsoleMode(handle, &mode);
        if (ret == 0)
            return error.Unexpected;

        const _cooked = mode;

        mode |=  ENABLE_VIRTUAL_TERMINAL_INPUT;
        mode |=  ENABLE_WINDOW_INPUT;
        mode &= ~ENABLE_PROCESSED_INPUT;
        mode &= ~ENABLE_ECHO_INPUT;
        mode &= ~ENABLE_LINE_INPUT;
        mode &= ~ENABLE_MOUSE_INPUT;

        ret = SetConsoleMode(handle, mode);
        if (1 != ret) return error.Unexpected;

        cookedOutput = _cooked;
    }
}

pub fn disableRawMode() !void {
    var ret: BOOL = undefined;

    if (selectOutputHandle()) |handle| output: {
        if (cookedOutput == null)
            break :output;

        ret = SetConsoleMode(handle, cookedOutput.?);
        if (ret == 0)
            return error.Unexpected;
    }

    if (selectInputHandle()) |handle| input: {
        if (cookedInput == null)
            break :input;

        ret = SetConsoleMode(handle, cookedInput.?);
        if (ret == 0)
            return error.Unexpected;
    }
}

pub fn getScreenSize() !Dimensions {
    const handle = selectOutputHandle() orelse @panic("Not A Terminal");

    var   info = @as(CONSOLE_SCREEN_BUFFER_INFO, undefined);
    const ret  = GetConsoleScreenBufferInfo(handle, &info);
    if (ret == 0)
        return error.Unexpected;

    return Dimensions.init(@intCast(info.dwSize.X), @intCast(info.dwSize.Y));
}

pub fn write(
    gpa: std.mem.Allocator,
    bytes: []const u8,
) error{OutOfMemory, WriteFailed}!void {
    const handle: HANDLE = selectOutputHandle() orelse return;

    const utf16 = std.unicode.utf8ToUtf16LeAlloc(gpa, bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidUtf8 => return error.WriteFailed,
    };
    defer gpa.free(utf16);

    var todo    = utf16.len;
    var done    = @as(usize, 0);
    var ret     = @as(BOOL,  undefined);
    var written = @as(DWORD, undefined);

    while (todo != 0) {
        ret = WriteConsoleW(handle, utf16[done..].ptr, @intCast(todo), &written, null);
        if (ret == 0) return error.WriteFailed;
        done += @intCast(written);
        todo -= @intCast(written);
    }
}

pub fn read(source: Source, maybe_timeout: ?u32) error{ReadFailed, PollFailed, Unexpected}!?Input {
    const handle = switch (source) {
        .file  => |f| tag: {
            // If the caller accidentally passes standard input as a file
            // source, we need to treat it as a console input instead.
            if (GetFileType(f.handle) == FILE_TYPE_CHAR)
                return read(.stdin, maybe_timeout);

            break :tag f.handle;
        },

        .stdin => tag: {
            if (selectInputHandle()) |h|
                break :tag h;

            // if stdin is not related to a controlling terminal,
            // then just treat it as if it was a file source.
            const file = std.fs.File.stdin();
            return read(.File(file), maybe_timeout);
        },
    };

    const timeout = if (maybe_timeout) |t| t else windows.INFINITE;
    var   ready   = @as(bool, undefined);

    ready = try poll(handle, timeout);
    if (!ready) return null;

    if (source == .stdin) {
        var  ret     = @as(BOOL, undefined);
        var  records = @as([1]INPUT_RECORD, undefined);
        var nrecords = @as(DWORD, undefined);

        ret = PeekConsoleInputW(handle, &records, 1, &nrecords);
        if (1 != ret)      return error.ReadFailed;
        if (nrecords != 1) return error.Unexpected;

        if (records[0].EventType == WINDOW_BUFFER_SIZE_EVENT) {
            ret = ReadConsoleInputW(handle, &records, 1, &nrecords);
            if (1 != ret)      return error.ReadFailed;
            if (nrecords != 1) return error.Unexpected;

            return .resize;
        }
    }

    ready = try poll(handle, timeout);
    if (!ready) return null;

    return switch (source) {
        .file  => readFromFile(handle),
        .stdin => readFromStdin(handle),
    };
}

fn readFromStdin(handle: HANDLE) error{ReadFailed, PollFailed, Unexpected}!?Input{
    var codepoint    = @as(u21, undefined);
    var codepointlen = @as(u3, undefined);
    var ready        = @as(bool, undefined);
    var parser       = @as(InputParser, .{});
    var result       = @as(InputParser.Result, .none);

    while (true) {
        codepoint = outer_loop: while (true) {
            var curr = @as(u16, undefined);
            var prev = @as(u16, undefined);

            curr = inner_loop: while (true) {
                var ret:   BOOL     = undefined;
                var chars: [1]WCHAR = undefined;
                var nread: DWORD    = 0;

                ret = ReadConsoleW(handle, @ptrCast(&chars), 1, &nread, null);
                if (ret == 0)   return error.ReadFailed;
                if (nread == 0) return .eof;

                break :inner_loop chars[0];
            };

            if (std.unicode.utf16IsHighSurrogate(curr))
                prev = curr
            else if (std.unicode.utf16IsLowSurrogate(curr))
                break :outer_loop std.unicode.utf16DecodeSurrogatePair(
                    &.{prev, curr},
                ) catch return error.Unexpected
            else
                break: outer_loop curr;

            ready = try poll(handle, 0);
            if (!ready) return error.Unexpected;
        };

        codepointlen = std.unicode.utf8CodepointSequenceLength(codepoint)
            catch return error.Unexpected;
        if (codepointlen == 1) result = try parser.step(@intCast(codepoint))
        else result = parser.unicode(codepoint);

        if (result == .final)
            return result.final;

        ready = try poll(handle, 0);

        if (!ready and result == .none)
            return error.Unexpected;

        if (!ready and result == .ambiguous)
            return result.ambiguous;
    }
}

fn readFromFile(handle: HANDLE) error{ReadFailed, PollFailed, Unexpected}!?Input {
    var bytes  = @as([1]u8, undefined);
    var nread  = @as(usize, undefined);
    var ready  = @as(bool, undefined);
    var parser = @as(InputParser, .{});
    var result = @as(InputParser.Result, .none);

    while (true) {
        nread = windows.ReadFile(handle, &bytes, null)
            catch return error.ReadFailed;
        if (nread == 0) return .eof;

        result = try parser.step(bytes[0]);

        if (result == .final)
            return result.final;

        ready = try poll(handle, 0);

        if (!ready and result == .none)
            return error.Unexpected;

        if (!ready and result == .ambiguous)
            return result.ambiguous;
    }
}

fn poll(handle: HANDLE, timeout: DWORD) error{PollFailed}!bool {
    const wait_ret = WaitForSingleObject(handle, timeout);

    if (wait_ret == WAIT_ABANDONED)
        return error.PollFailed;

    if (wait_ret == WAIT_FAILED)
        return error.PollFailed;

    if (wait_ret == WAIT_TIMEOUT)
        return false;

    return true;
}
