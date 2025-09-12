const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;
const Color = fuizon.style.Color;

pub fn setForeground(color: Color) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_stream_set_foreground_color(
        &s,
        &color.toCrosstermColor(),
    );
    if (0 != ret) return error.TerminalError;
}

pub fn setBackground(color: Color) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_stream_set_background_color(
        &s,
        &color.toCrosstermColor(),
    );
    if (0 != ret) return error.TerminalError;
}
