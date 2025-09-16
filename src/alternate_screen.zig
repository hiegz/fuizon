//
// By default, you will be working on the main screen. There is also another
// screen called the ‘alternative’ screen. This screen is slightly different
// from the main screen. For example, it has the exact dimensions of the
// terminal window, without any scroll-back area.
//
// This interface offers the possibility to switch to the ‘alternative’
// screen, make some modifications, and move back to the ‘main’ screen again.
// The main screen will stay intact and will have the original data as we
// performed all operations on the alternative screen.
//

const fuizon = @import("fuizon.zig");
const vt = @import("vt.zig");

pub fn enterAlternateScreen() error{WriteFailed}!void {
    return fuizon.getWriter().writeAll(vt.CSI ++ "?1049h");
}

pub fn leaveAlternateScreen() error{WriteFailed}!void {
    return fuizon.getWriter().writeAll(vt.CSI ++ "?1049l");
}
