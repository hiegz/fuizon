const TextAlignment = @import("text_alignment.zig").TextAlignment;

pub const TextOpts = struct {
    alignment: TextAlignment = .left,
    wrap: bool = false,
};
