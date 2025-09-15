const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

pub fn scrollUp(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_scroll_up(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn scrollDown(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_scroll_down(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn getScreenSize() error{TerminalError}!struct { width: u16, height: u16 } {
    var ret: c_int = undefined;
    var sz: c.crossterm_size = undefined;
    ret = c.crossterm_get_size(&sz);
    if (0 != ret) return error.TerminalError;
    return .{ .width = sz.width, .height = sz.height };
}
