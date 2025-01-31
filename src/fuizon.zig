// zig fmt: off
pub const event    = @import("event.zig");
pub const keyboard = @import("keyboard.zig");
pub const style    = @import("style.zig");
pub const backend  = @import("backend.zig");
// zig fmt: on

test "fuizon" {
    @import("std").testing.refAllDecls(@This());
}
