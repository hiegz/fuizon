pub const container = @import("widgets/container.zig");
pub const filler = @import("widgets/filler.zig");

test "widgets" {
    @import("std").testing.refAllDecls(@This());
}
