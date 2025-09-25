pub const Viewport = union(enum) {
    auto,
    fixed: u16,
    fullscreen,

    pub fn Auto() Viewport {
        return .auto;
    }

    pub fn Fixed(height: u16) Viewport {
        return .{ .fixed = height };
    }

    pub fn Fullscreen() Viewport {
        return .fullscreen;
    }
};
