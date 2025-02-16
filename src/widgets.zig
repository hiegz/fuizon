pub const container = @import("widgets/container.zig");

test "widgets" {
    @import("std").testing.refAllDecls(@This());
}
