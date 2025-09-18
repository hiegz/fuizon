// zig fmt: off

const std = @import("std");
const windows = std.os.windows;

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

pub const HANDLE = windows.HANDLE;
pub const DWORD  = windows.DWORD;
pub const BOOL   = windows.BOOL;

pub extern fn GetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: *windows.DWORD) windows.BOOL;
pub extern fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode:  windows.DWORD) windows.BOOL;
pub extern fn GetFileType(hConsoleHandle: windows.HANDLE) windows.DWORD;
