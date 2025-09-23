const std = @import("std");
const Border = @import("border.zig").Border;

pub const Borders = struct {
    pub const none = Borders.join(&.{});
    pub const all = Borders.join(&.{ .top, .bottom, .left, .right });

    bitset: u8,

    pub fn join(borders: []const Border) Borders {
        var target: Borders = .{ .bitset = 0 };
        target.set(borders);
        return target;
    }

    pub fn set(self: *Borders, borders: []const Border) void {
        for (borders) |border| {
            self.bitset |= border.bitset();
        }
    }

    pub fn reset(self: *Borders, borders: []const Border) void {
        for (borders) |border| {
            self.bitset &= ~border.bitset();
        }
    }

    pub fn contain(self: Borders, borders: []const Border) bool {
        for (borders) |border|
            if ((self.bitset & border.bitset()) == 0)
                return false;
        return true;
    }

    pub fn format(self: Borders, writer: *std.Io.Writer) !void {
        var borders: [4]Border = undefined;
        var nborders: usize = 0;

        if (self.contain(&.{.top})) {
            borders[nborders] = .top;
            nborders += 1;
        }
        if (self.contain(&.{.bottom})) {
            borders[nborders] = .bottom;
            nborders += 1;
        }
        if (self.contain(&.{.left})) {
            borders[nborders] = .left;
            nborders += 1;
        }
        if (self.contain(&.{.right})) {
            borders[nborders] = .right;
            nborders += 1;
        }

        try writer.writeAll("{");
        for (borders[0..nborders], 0..) |border, i| {
            try writer.print(" {f}", .{border});
            if (i + 1 < nborders)
                try writer.writeAll(",");
        }
        try writer.writeAll(" }");
    }
};

test "Borders.format() with no borders" {
    try std.testing.expectFmt("{ }", "{f}", .{Borders.none});
}

test "Borders.format() with the top borders" {
    try std.testing.expectFmt("{ top }", "{f}", .{Borders.join(&.{.top})});
}

test "Borders.format() with the bottom borders" {
    try std.testing.expectFmt("{ bottom }", "{f}", .{Borders.join(&.{.bottom})});
}

test "Borders.format() with the left borders" {
    try std.testing.expectFmt("{ left }", "{f}", .{Borders.join(&.{.left})});
}

test "Borders.format() with the right borders" {
    try std.testing.expectFmt("{ right }", "{f}", .{Borders.join(&.{.right})});
}

test "Borders.format() with all borders" {
    try std.testing.expectFmt("{ top, bottom, left, right }", "{f}", .{Borders.all});
}

test "Borders.set() should add and Borders.reset() should remove the specified borders" {
    var left = Borders.none;
    left.set(&.{ .top, .bottom });
    var right = Borders.all;
    right.reset(&.{ .left, .right });

    try std.testing.expectEqual(left.bitset, right.bitset);
}
