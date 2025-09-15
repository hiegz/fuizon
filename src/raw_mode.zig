//
// Interface for manipulating the terminal raw mode.
//
// By default, the terminal functions in a certain way. For example, it will
// move the cursor to the beginning of the next line when the input hits the
// end of a line. Or that the backspace is interpreted for character removal.
//
// Sometimes these default modes are irrelevant, and in this case, we can
// enable the raw mode.
//
// When enabling the raw mode:
//
//   - Input will not be forwarded to screen
//   - Input will not be processed on enter press
//   - Input will not be line buffered (input sent byte-by-byte to input buffer)
//   - Special keys like backspace and CTRL+C will not be processed by terminal driver
//   - New line character will not be processed
//

pub fn isRawModeEnabled() !bool {
    // Not implemented
    return false;
}

pub fn enableRawMode() !void {
    // Not implemented
}

pub fn disableRawMode() !void {
    // Not implemented
}
