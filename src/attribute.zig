const std = @import("std");
const fuizon = @import("fuizon.zig");
const vt = @import("vt.zig");
const CSI = vt.CSI;

pub const Attribute = enum(u8) {
    // zig fmt: off
    bold       = 1 << 0,
    dim        = 1 << 1,
    underlined = 1 << 2,
    reverse    = 1 << 3,
    hidden     = 1 << 4,
    // zig fmt: on

    pub fn format(self: Attribute, writer: *std.io.Writer) !void {
        // zig fmt: off
        switch (self) {
            .bold       => _ = try writer.write("bold"),
            .dim        => _ = try writer.write("dim"),
            .underlined => _ = try writer.write("underlined"),
            .reverse    => _ = try writer.write("reverse"),
            .hidden     => _ = try writer.write("hidden"),
        }
        // zig fmt: on
    }

    pub fn bitset(attribute: Attribute) u8 {
        return @intFromEnum(attribute);
    }
};

pub const Attributes = struct {
    const Iterator = struct {
        attributes: Attributes,

        pub fn next(self: *Iterator) ?Attribute {
            const index: usize = @ctz(self.attributes.bitset);
            if (index == 8) return null;
            std.debug.assert(index <= 4);
            const attribute: Attribute =
                @enumFromInt(@as(u8, 1) << @as(u3, @intCast(index)));
            self.attributes.reset(&.{attribute});
            return attribute;
        }
    };

    // zig fmt: off
    pub const none = Attributes.join(&.{});
    pub const all  = Attributes.join(&.{ .bold, .dim, .underlined, .reverse, .hidden });
    // zig fmt: on

    bitset: u8,

    pub fn join(attributes: []const Attribute) Attributes {
        var target = Attributes{ .bitset = 0 };
        target.set(attributes);
        return target;
    }

    pub fn set(self: *Attributes, attributes: []const Attribute) void {
        for (attributes) |attribute| {
            self.bitset |= attribute.bitset();
        }
    }

    pub fn reset(self: *Attributes, attributes: []const Attribute) void {
        for (attributes) |attribute| {
            self.bitset &= ~attribute.bitset();
        }
    }

    pub fn contain(self: Attributes, attributes: []const Attribute) bool {
        for (attributes) |attribute| {
            if ((self.bitset & attribute.bitset()) == 0)
                return false;
        }
        return true;
    }

    pub fn iterator(self: Attributes) Attributes.Iterator {
        return Attributes.Iterator{ .attributes = self };
    }

    pub fn format(self: Attributes, writer: *std.io.Writer) !void {
        var attributes = [_]Attribute{.bold} ** 5;
        var nattributes: usize = 0;

        if (self.contain(&.{.bold})) {
            attributes[nattributes] = .bold;
            nattributes += 1;
        }
        if (self.contain(&.{.dim})) {
            attributes[nattributes] = .dim;
            nattributes += 1;
        }
        if (self.contain(&.{.underlined})) {
            attributes[nattributes] = .underlined;
            nattributes += 1;
        }
        if (self.contain(&.{.reverse})) {
            attributes[nattributes] = .reverse;
            nattributes += 1;
        }
        if (self.contain(&.{.hidden})) {
            attributes[nattributes] = .hidden;
            nattributes += 1;
        }

        _ = try writer.write("{");
        for (attributes[0..nattributes], 0..) |attribute, i| {
            try writer.print(" {f}", .{attribute});
            if (i + 1 < nattributes)
                _ = try writer.write(",");
        }
        _ = try writer.write(" }");
    }
};

pub fn setAttribute(attribute: Attribute) error{WriteFailed}!void {
    return switch (attribute) {
        // zig fmt: off
        .bold       => fuizon.getWriter().writeAll(CSI ++ "1m"),
        .dim        => fuizon.getWriter().writeAll(CSI ++ "2m"),
        .underlined => fuizon.getWriter().writeAll(CSI ++ "4m"),
        .reverse    => fuizon.getWriter().writeAll(CSI ++ "7m"),
        .hidden     => fuizon.getWriter().writeAll(CSI ++ "8m"),
        // zig fmt: on
    };
}

pub fn resetAttribute(attribute: Attribute) !void {
    return switch (attribute) {
        // zig fmt: off
        .bold       => fuizon.getWriter().writeAll(CSI ++ "21m"),
        .dim        => fuizon.getWriter().writeAll(CSI ++ "22m"),
        .underlined => fuizon.getWriter().writeAll(CSI ++ "24m"),
        .reverse    => fuizon.getWriter().writeAll(CSI ++ "27m"),
        .hidden     => fuizon.getWriter().writeAll(CSI ++ "28m"),
        // zig fmt: on
    };
}

test "no-attributes" {
    try std.testing.expectEqual(0, Attributes.none.bitset);
}

test "all-attributes" {
    try std.testing.expect(Attributes.all.contain(&.{
        .bold,
        .dim,
        .underlined,
        .reverse,
        .hidden,
    }));
}

test "attributes-contain" {
    var attributes = Attributes.all;
    attributes.reset(&.{ .bold, .reverse });

    try std.testing.expect(!attributes.contain(&.{.bold}));
    try std.testing.expect(!attributes.contain(&.{.reverse}));
    try std.testing.expect(!attributes.contain(&.{ .bold, .reverse }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .bold }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .reverse }));
    try std.testing.expect(!attributes.contain(&.{ .dim, .bold, .reverse }));
    try std.testing.expect(attributes.contain(&.{.dim}));
}

test "attributes-set-reset" {
    var left = Attributes.none;
    left.set(&.{ .dim, .hidden, .underlined });
    var right = Attributes.all;
    right.reset(&.{ .bold, .reverse });
    try std.testing.expectEqual(left.bitset, right.bitset);
}

test "no-attributes-iterator" {
    const attributes = Attributes.none;
    var iterator: Attributes.Iterator = undefined;
    var found: bool = undefined;

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .bold) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .dim) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .hidden) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .reverse) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .underlined) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    // make sure the original attribute set instance was not modified by the
    // iterator.
    try std.testing.expectEqual(Attributes.none.bitset, attributes.bitset);
}

test "some-attributes-iterator" {
    const attributes = Attributes.join(&.{ .bold, .dim, .hidden });
    var iterator: Attributes.Iterator = undefined;
    var found: bool = undefined;

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .bold) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .dim) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .hidden) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .reverse) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .underlined) continue;
        found = true;
        break;
    }

    try std.testing.expect(!found);

    // make sure the original attribute set instance was not modified by the
    // iterator.
    try std.testing.expectEqual(Attributes.join(&.{ .bold, .dim, .hidden }).bitset, attributes.bitset);
}

test "all-attributes-iterator" {
    const attributes = Attributes.all;
    var iterator: Attributes.Iterator = undefined;
    var found: bool = undefined;

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .bold) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .dim) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .hidden) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .reverse) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    found = false;
    iterator = attributes.iterator();
    while (iterator.next()) |attribute| {
        if (attribute != .underlined) continue;
        found = true;
        break;
    }

    try std.testing.expect(found);

    // make sure the original attribute set instance was not modified by the
    // iterator.
    try std.testing.expectEqual(Attributes.all.bitset, attributes.bitset);
}

test "format-bold-attribute" {
    try std.testing.expectFmt("bold", "{f}", .{Attribute.bold});
}

test "format-dim-attribute" {
    try std.testing.expectFmt("dim", "{f}", .{Attribute.dim});
}

test "format-underlined-attribute" {
    try std.testing.expectFmt("underlined", "{f}", .{Attribute.underlined});
}

test "format-reverse-attribute" {
    try std.testing.expectFmt("reverse", "{f}", .{Attribute.reverse});
}

test "format-hidden-attribute" {
    try std.testing.expectFmt("hidden", "{f}", .{Attribute.hidden});
}

test "format-empty-attribute-set" {
    try std.testing.expectFmt("{ }", "{f}", .{Attributes.none});
}

test "format-all-attributes" {
    try std.testing.expectFmt("{ bold, dim, underlined, reverse, hidden }", "{f}", .{Attributes.all});
}
