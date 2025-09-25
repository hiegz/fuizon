// zig fmt: off

const std = @import("std");
const windows = std.os.windows;
const terminal = @import("terminal.zig");
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
pub extern fn ReadConsoleInputW(hConsoleInput: windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: windows.DWORD, lpNumberOfEventsRead: *windows.DWORD) windows.BOOL;
pub extern fn PeekConsoleInputW(hConsoleInput: windows.HANDLE, lpBuffer: [*]INPUT_RECORD, nLength: windows.DWORD, lpNumberOfEventsRead: *windows.DWORD) windows.BOOL;

//

pub fn read(maybe_timeout: ?u32) error{NotATerminal, ReadFailed, Unexpected}!?Input {
    while (true) {
        const timeout = if (maybe_timeout) |t| t else windows.INFINITE;
        const input   = try terminal.getInputHandle();

        var ret:      windows.BOOL  = undefined;
        var wait_ret: windows.DWORD = undefined;

        wait_ret = WaitForSingleObject(input, timeout);

        if (wait_ret == WAIT_ABANDONED)
            return error.ReadFailed;

        if (wait_ret == WAIT_FAILED)
            return error.ReadFailed;

        if (wait_ret == WAIT_TIMEOUT)
            return null;

        var records: [1]INPUT_RECORD  = undefined;
        var nrecord: windows.DWORD = 0;
        ret = PeekConsoleInputW(input, &records, 1, &nrecord);
        if (1 != ret)     return error.ReadFailed;
        if (nrecord != 1) return error.Unexpected;

        if (records[0].EventType == WINDOW_BUFFER_SIZE_EVENT) {
            ret = ReadConsoleInputW(input, &records, 1, &nrecord);
            if (1 != ret)     return error.ReadFailed;
            if (nrecord != 1) return error.Unexpected;

            return .resize;
        }

        wait_ret = WaitForSingleObject(input, 0);

        if (wait_ret == WAIT_ABANDONED)
            return error.ReadFailed;

        if (wait_ret == WAIT_FAILED)
            return error.ReadFailed;

        if (wait_ret == WAIT_TIMEOUT)
            return null;

        var parser: InputParser        = .{};
        var result: InputParser.Result = .none;

        while (true) {
            var byte: u8 = undefined;
            const nbytes = windows.ReadFile(input, @ptrCast(&byte), null) catch |err| switch (err) {
                error.Unexpected => return error.Unexpected,
                else             => return error.ReadFailed,
            };
            if (nbytes == 0)
                return .eof;
            std.debug.assert(nbytes == 1);

            result = try parser.step(byte);

            if (result == .final)
                return result.final;

            wait_ret = WaitForSingleObject(input, 0);

            if (wait_ret == WAIT_ABANDONED)
                return error.ReadFailed;

            if (wait_ret == WAIT_FAILED)
                return error.ReadFailed;

            if (wait_ret == WAIT_TIMEOUT and result == .none)
                return error.Unexpected;

            if (wait_ret == WAIT_TIMEOUT and result == .ambiguous)
                return result.ambiguous;
        }
    }
}

pub fn key(record: KEY_EVENT_RECORD) ?Input {
    var input: Input = .{ .key = .{ .code = undefined, .modifiers = .none } };

    if (record.bKeyDown == 0)
        return null;

    if (record.dwControlKeyState & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED) != 0)
        input.key.modifiers.set(&.{.control});

    if (record.dwControlKeyState & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED) != 0)
        input.key.modifiers.set(&.{.alt});

    if (record.dwControlKeyState & (SHIFT_PRESSED) != 0)
        input.key.modifiers.set(&.{.shift});

    switch (record.wVirtualKeyCode) {
        0x08 => input.key.code = .backspace,
        0x09 => input.key.code = .tab,
        0x0d => input.key.code = .enter,
        0x13 => input.key.code = .pause,
        0x1b => input.key.code = .escape,
        0x20 => input.key.code = .space,
        0x21 => input.key.code = .page_up,
        0x22 => input.key.code = .page_down,
        0x23 => input.key.code = .end,
        0x24 => input.key.code = .home,
        0x25 => input.key.code = .left_arrow,
        0x26 => input.key.code = .up_arrow,
        0x27 => input.key.code = .right_arrow,
        0x28 => input.key.code = .down_arrow,
        0x2d => input.key.code = .insert,
        0x2e => input.key.code = .delete,
        0x70 => input.key.code = .f1,
        0x71 => input.key.code = .f2,
        0x72 => input.key.code = .f3,
        0x73 => input.key.code = .f4,
        0x74 => input.key.code = .f5,
        0x75 => input.key.code = .f6,
        0x76 => input.key.code = .f7,
        0x77 => input.key.code = .f8,
        0x78 => input.key.code = .f9,
        0x79 => input.key.code = .f10,
        0x7a => input.key.code = .f11,
        0x7b => input.key.code = .f12,

        0xe7,
        '0'...'9',
        'A'...'Z' => {
            var char: u21 = @intCast(record.uChar.UnicodeChar);

            if (char >= 0x0b and char <= 0x1a)
                char = char - 0x01 + 'a'
            else if (char >= 0x1c and char <= 0x1f)
                char = char - 0x1c + '4';

            input.key.code = .{ .char = char };
        },

        else => return null,
    }

    return input;
}
