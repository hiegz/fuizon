pub const Spacing = union(enum) {
    auto,
    fixed: u16,

    pub fn Auto() Spacing {
        return .auto;
    }

    pub fn Fixed(value: u16) Spacing {
        return .{ .fixed = value };
    }

    // zig fmt: off

    pub fn min(self: Spacing) u16 {
        return switch (self) {
            .auto  =>     0,
            .fixed => |v| v,
        };
    }

    // zig fmt: on
};
