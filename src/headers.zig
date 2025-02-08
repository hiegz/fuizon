pub const c = @cImport({
    @cInclude("fuiwi.h");
    @cInclude("crossterm_ffi/color.h");
    @cInclude("crossterm_ffi/cursor.h");
    @cInclude("crossterm_ffi/error.h");
    @cInclude("crossterm_ffi/event.h");
    @cInclude("crossterm_ffi/stream.h");
    @cInclude("crossterm_ffi/terminal.h");
});
