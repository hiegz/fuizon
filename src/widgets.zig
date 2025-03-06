pub const container = @import("widgets/container.zig");
pub const filler = @import("widgets/filler.zig");
pub const text = @import("widgets/text.zig");

test "widgets" {
    @import("std").testing.refAllDecls(@This());
}
