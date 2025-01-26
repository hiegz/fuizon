pub const c = @cImport({
    @cInclude("crossterm_ffi/attributes.h");
    @cInclude("crossterm_ffi/color.h");
    @cInclude("crossterm_ffi/cursor.h");
    @cInclude("crossterm_ffi/error.h");
    @cInclude("crossterm_ffi/event.h");
    @cInclude("crossterm_ffi/stream.h");
    @cInclude("crossterm_ffi/style.h");
    @cInclude("crossterm_ffi/terminal.h");
    @cInclude("crossterm_ffi/uint21_t.h");
});
