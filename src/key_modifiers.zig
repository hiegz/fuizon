const std = @import("std");
const KeyModifier = @import("key_modifier.zig").KeyModifier;

pub const KeyModifiers = struct {
    // zig fmt: off
    pub const none = KeyModifiers.join(&.{});
    pub const all  = KeyModifiers.join(&.{ .shift, .control, .alt });
    // zig fmt: on

    bitset: u16,

    pub fn join(modifiers: []const KeyModifier) KeyModifiers {
        var target = KeyModifiers{ .bitset = 0 };
        target.set(modifiers);
        return target;
    }

    pub fn set(self: *KeyModifiers, modifiers: []const KeyModifier) void {
        for (modifiers) |modifier| {
            self.bitset |= modifier.bitset();
        }
    }

    pub fn reset(self: *KeyModifiers, modifiers: []const KeyModifier) void {
        for (modifiers) |modifier| {
            self.bitset &= ~modifier.bitset();
        }
    }

    pub fn contain(self: KeyModifiers, modifiers: []const KeyModifier) bool {
        for (modifiers) |modifier| {
            if ((self.bitset & modifier.bitset()) == 0)
                return false;
        }
        return true;
    }

    pub fn format(self: KeyModifiers, writer: *std.io.Writer) !void {
        var modifiers = [_]KeyModifier{.shift} ** 9;
        var nmodifiers: usize = 0;

        if (self.contain(&.{.shift})) {
            modifiers[nmodifiers] = .shift;
            nmodifiers += 1;
        }
        if (self.contain(&.{.control})) {
            modifiers[nmodifiers] = .control;
            nmodifiers += 1;
        }
        if (self.contain(&.{.alt})) {
            modifiers[nmodifiers] = .alt;
            nmodifiers += 1;
        }

        _ = try writer.write("{");
        for (modifiers[0..nmodifiers], 0..) |modifier, i| {
            try writer.print(" {f}", .{modifier});
            if (i + 1 < nmodifiers)
                _ = try writer.write(",");
        }
        _ = try writer.write(" }");
    }
};

test "no-key-modifiers" {
    try std.testing.expectEqual(0, KeyModifiers.none.bitset);
}

test "all-key-modifiers" {
    try std.testing.expect(KeyModifiers.all.contain(&.{ .shift, .control, .alt }));
}

test "key-modifiers-contain" {
    var modifiers = KeyModifiers.all;
    modifiers.reset(&.{.alt});

    try std.testing.expect(!modifiers.contain(&.{.alt}));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .control }));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .shift }));
    try std.testing.expect(!modifiers.contain(&.{ .alt, .control, .shift }));
    try std.testing.expect(modifiers.contain(&.{.control}));
    try std.testing.expect(modifiers.contain(&.{.shift}));
    try std.testing.expect(modifiers.contain(&.{ .control, .shift }));
}

test "key-modifiers-set-reset" {
    var left = KeyModifiers.none;
    left.set(&.{ .shift, .control });
    var right = KeyModifiers.all;
    right.reset(&.{.alt});

    try std.testing.expectEqual(left.bitset, right.bitset);
}

test "format-all-key-modifiers" {
    try std.testing.expectFmt("{ shift, control, alt }", "{f}", .{KeyModifiers.all});
}
