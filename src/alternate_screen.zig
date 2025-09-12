const c = @import("headers.zig").c;
const fuizon = @import("fuizon.zig");

pub fn enterAlternateScreen() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_enter_alternate_screen(&s);
    if (0 != ret) return error.TerminalError;
}

pub fn leaveAlternateScreen() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_leave_alternate_screen(&s);
    if (0 != ret) return error.TerminalError;
}
