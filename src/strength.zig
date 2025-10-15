const std = @import("std");

// zig fmt: off

pub const Strength = struct {
    pub fn init(s: f64, m: f64, w: f64) f64 {
        const lo = @as(f64, -1000.0);
        const hi = @as(f64,  1000.0);
        var   rt = @as(f64,     0.0);

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

