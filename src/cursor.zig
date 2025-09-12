const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

pub fn showCursor() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_show_cursor(&s);
    if (0 != ret) return error.TerminalError;
}

pub fn hideCursor() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_hide_cursor(&s);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorUp(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_up(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorDown(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_down(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorLeft(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_left(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorRight(n: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_right(&s, n);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorToRow(y: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_to_row(&s, y);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorToColumn(x: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_to_col(&s, x);
    if (0 != ret) return error.TerminalError;
}

pub fn moveCursorTo(x: u16, y: u16) error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_move_cursor_to(&s, x, y);
    if (0 != ret) return error.TerminalError;
}

pub fn saveCursorPosition() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_save_cursor_position(&s);
    if (0 != ret) return error.TerminalError;
}

pub fn restoreCursorPosition() error{TerminalError}!void {
    var s = fuizon.writer.getCrosstermStream();
    var ret: c_int = undefined;
    ret = c.crossterm_restore_cursor_position(&s);
    if (0 != ret) return error.TerminalError;
}

pub fn getCursorPosition() error{TerminalError}!struct { x: u16, y: u16 } {
    var ret: c_int = undefined;
    var pos: c.crossterm_cursor_position = undefined;
    ret = c.crossterm_get_cursor_position(&pos);
    if (0 != ret) return error.TerminalError;
    return .{ .x = pos.x, .y = pos.y };
}
