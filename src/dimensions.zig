pub const Dimensions = struct {
    width: u16,
    height: u16,

    pub fn init(width: u16, height: u16) Dimensions {
        return .{ .width = width, .height = height };
    }
};
