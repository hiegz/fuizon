pub const Alignment = alignment.Alignment;
pub const enterAlternateScreen = alternate_screen.enterAlternateScreen;
pub const leaveAlternateScreen = alternate_screen.leaveAlternateScreen;
pub const Area = area.Area;
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const setAttribute = attribute.setAttribute;
pub const resetAttribute = attribute.resetAttribute;
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const Ansi = color.Ansi;
pub const RgbColor = color.RgbColor;
pub const Rgb = color.Rgb;
pub const setForeground = color.setForeground;
pub const setBackground = color.setBackground;
pub const Coordinate = coordinate.Coordinate;
pub const showCursor = cursor.showCursor;
pub const hideCursor = cursor.hideCursor;
pub const moveCursorTo = cursor.moveCursorTo;
pub const getCursorPosition = cursor.getCursorPosition;
pub const Dimensions = dimensions.Dimensions;
pub const event = @import("event.zig");
pub const Event = event.Event;
pub const KeyEvent = event.KeyEvent;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyCode = keyboard.KeyCode;
pub const KeyModifier = keyboard.KeyModifier;
pub const KeyModifiers = keyboard.KeyModifiers;
pub const enableRawMode = raw_mode.enableRawMode;
pub const disableRawMode = raw_mode.disableRawMode;
pub const isRawModeEnabled = raw_mode.isRawModeEnabled;
pub const scrollUp = screen.scrollUp;
pub const scrollDown = screen.scrollDown;
pub const getScreenSize = screen.getScreenSize;
pub const Style = style.Style;
pub const getWriter = writer.getWriter;
pub const useStdout = writer.useStdout;
pub const useStderr = writer.useStderr;

const alignment = @import("alignment.zig");

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
const alternate_screen = @import("alternate_screen.zig");
const area = @import("area.zig");
const attribute = @import("attribute.zig");
const color = @import("color.zig");
const coordinate = @import("coordinate.zig");
const cursor = @import("cursor.zig");
const dimensions = @import("dimensions.zig");
const frame = @import("frame.zig");
const keyboard = @import("keyboard.zig");

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
const raw_mode = @import("raw_mode.zig");
const screen = @import("screen.zig");
const style = @import("style.zig");
const writer = @import("writer.zig");

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}
