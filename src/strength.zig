const std = @import("std");

// zig fmt: off

pub const Strength = struct {
    pub fn init(s: f32, m: f32, w: f32) f32 {
        const lo = @as(f32, -1000.0);
        const hi = @as(f32,  1000.0);
        var   rt = @as(f32,     0.0);

        rt += std.math.clamp(s, lo, hi) * 1000000.0;
        rt += std.math.clamp(m, lo, hi) * 1000.0;
        rt += std.math.clamp(w, lo, hi);

        return rt;
    }

    pub const required = init(1000.0, 1000.0, 1000.0);
    pub const strong   = init(1.0, 0.0, 0.0);
    pub const medium   = init(0.0, 1.0, 0.0);
    pub const weak     = init(0.0, 0.0, 1.0);
};

