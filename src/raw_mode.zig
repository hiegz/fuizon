const c = @import("headers.zig").c;

pub fn isRawModeEnabled() error{TerminalError}!bool {
    var ret: c_int = undefined;
    var is_enabled: bool = undefined;
    ret = c.crossterm_is_raw_mode_enabled(&is_enabled);
    if (0 != ret) return error.TerminalError;
    return is_enabled;
}

pub fn enableRawMode() error{TerminalError}!void {
    var ret: c_int = undefined;
    ret = c.crossterm_enable_raw_mode();
    if (0 != ret) return error.TerminalError;
}

pub fn disableRawMode() error{TerminalError}!void {
    var ret: c_int = undefined;
    ret = c.crossterm_disable_raw_mode();
    if (0 != ret) return error.TerminalError;
}
