const std = @import("std");
const mod = @import("../mod.zig");

const Position = mod.Position;

pub const Apple = struct {
    position: Position,

    pub fn random(width: u16, height: u16) Apple {
        const x = randomEvenInRangeLessThan(i17, 0, @intCast(width));
        const y = randomEvenInRangeLessThan(i17, 0, @intCast(height));

        return .{ .position = .{ .x = x, .y = y } };
    }

    fn randomEvenInRangeLessThan(comptime T: type, at_least: T, less_than: T) T {
        const r = std.crypto.random.intRangeLessThan(T, at_least, less_than);
        if (@mod(r, 2) == 0) return r;
        if (r + 1 < less_than) return r + 1;
        if (r - 1 >= at_least) return r - 1;
        unreachable;
    }
};
