// zig fmt: off
pub const event      = @import("event.zig");
pub const keyboard   = @import("keyboard.zig");
pub const style      = @import("style.zig");
pub const backend    = @import("backend.zig");
pub const area       = @import("area.zig");
pub const frame      = @import("frame.zig");
pub const layout     = @import("layout.zig");
pub const coordinate = @import("coordinate.zig");
// zig fmt: on

test "fuizon" {
    @import("std").testing.refAllDecls(@This());
}
