pub const Coordinate = struct {
    x: u16,
    y: u16,

    pub fn init(x: u16, y: u16) Coordinate {
        return .{ .x = x, .y = y };
    }

    pub const coord = init;
};
