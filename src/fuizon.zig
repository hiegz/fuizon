pub const writer = @import("writer.zig");
pub const getWriter = writer.getWriter;
pub const useStdout = writer.useStdout;
pub const useStderr = writer.useStderr;

/// ---
///
/// By default, you will be working on the main screen. There is also another
/// screen called the ‘alternative’ screen. This screen is slightly different
/// from the main screen. For example, it has the exact dimensions of the
/// terminal window, without any scroll-back area.
///
/// This interface offers the possibility to switch to the ‘alternative’
/// screen, make some modifications, and move back to the ‘main’ screen again.
/// The main screen will stay intact and will have the original data as we
/// performed all operations on the alternative screen.
///
/// ---
pub const alternate_screen = @import("alternate_screen.zig");
pub const enterAlternateScreen = alternate_screen.enterAlternateScreen;
pub const leaveAlternateScreen = alternate_screen.leaveAlternateScreen;

/// ---
///
/// Interface for manipulating the terminal raw mode.
///
/// By default, the terminal functions in a certain way. For example, it will
/// move the cursor to the beginning of the next line when the input hits the
/// end of a line. Or that the backspace is interpreted for character removal.
///
/// Sometimes these default modes are irrelevant, and in this case, we can
/// enable the raw mode.
///
/// When enabling the raw mode:
///
///   - Input will not be forwarded to screen
///   - Input will not be processed on enter press
///   - Input will not be line buffered (input sent byte-by-byte to input buffer)
///   - Special keys like backspace and CTRL+C will not be processed by terminal driver
///   - New line character will not be processed
///
/// ---
pub const raw_mode = @import("raw_mode.zig");
pub const enableRawMode = raw_mode.enableRawMode;
pub const disableRawMode = raw_mode.disableRawMode;
pub const isRawModeEnabled = raw_mode.isRawModeEnabled;

pub const alignment = @import("alignment.zig");
pub const Alignment = alignment.Alignment;

pub const attribute = @import("attribute.zig");
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const setAttribute = attribute.setAttribute;
pub const resetAttribute = attribute.resetAttribute;

pub const color = @import("color.zig");
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const RgbColor = color.RgbColor;
pub const setForeground = color.setForeground;
pub const setBackground = color.setBackground;

pub const style = @import("style.zig");
pub const Style = style.Style;

pub const screen = @import("screen.zig");
pub const clearScreen = screen.clearScreen;
pub const clearScreenFromCursorDown = screen.clearScreenFromCursorDown;
pub const clearScreenFromCursorUp = screen.clearScreenFromCursorUp;
pub const clearCurrentLine = screen.clearCurrentLine;
pub const clearUntilNewLine = screen.clearUntilNewLine;
pub const scrollUp = screen.scrollUp;
pub const scrollDown = screen.scrollDown;
pub const getScreenSize = screen.getScreenSize;

pub const cursor = @import("cursor.zig");
pub const showCursor = cursor.showCursor;
pub const hideCursor = cursor.hideCursor;
pub const moveCursorUp = cursor.moveCursorUp;
pub const moveCursorDown = cursor.moveCursorDown;
pub const moveCursorLeft = cursor.moveCursorLeft;
pub const moveCursorRight = cursor.moveCursorRight;
pub const moveCursorToRow = cursor.moveCursorToRow;
pub const moveCursorToColumn = cursor.moveCursorToColumn;
pub const moveCursorTo = cursor.moveCursorTo;
pub const saveCursorPosition = cursor.saveCursorPosition;
pub const restoreCursorPosition = cursor.restoreCursorPosition;
pub const getCursorPosition = cursor.getCursorPosition;

// zig fmt: off
pub const event    = @import("event.zig");
pub const keyboard = @import("keyboard.zig");
pub const frame    = @import("frame.zig");
pub const layout   = @import("layout.zig");
// zig fmt: on

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}
