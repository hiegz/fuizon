pub const Viewport = union(enum) {
    fixed: u16,
    fullscreen,

    pub fn Fixed(height: u16) Viewport {
        return .{ .fixed = height };
    }

    pub fn Fullscreen() Viewport {
        return .fullscreen;
    }
};
