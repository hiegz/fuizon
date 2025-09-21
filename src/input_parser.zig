const std = @import("std");
const fuizon = @import("fuizon.zig");
const Queue = @import("queue.zig").Queue;
const Input = fuizon.Input;
const Key = fuizon.Key;
const KeyCode = fuizon.KeyCode;
const KeyModifiers = fuizon.KeyModifiers;

pub const InputParser = struct {
    state: enum { default, esc, csi } = .default,
    args: [4]u8 = [_]u8{ 0, 0, 0, 0 },
    nargs: u3 = 0,

    pub const Result = union(enum) {
        // zig fmt: off
        none:      void,
        ambiguous: Input,
        final:     Input,
        // zig fmt: on

        fn Ambiguous(input: Input) Result {
            return .{ .ambiguous = input };
        }

        fn Final(input: Input) Result {
            return .{ .final = input };
        }
    };

    pub fn parse(
        self: *InputParser,
        slice: []const u8,
        offset: *usize,
    ) error{Unexpected}!Result {
        var ret: Result = .none;
        while (ret != .final and offset.* < slice.len) {
            ret = try self.step(slice[offset.*]);
            offset.* += 1;
        }
        return ret;
    }

    pub fn step(
        self: *InputParser,
        byte: u8,
    ) error{Unexpected}!Result {
        return switch (byte) {
            // zig fmt: off

            // Escape
            '\x1b' => tag: {
                self.state = .esc;
                break :tag Result.Ambiguous(.{ .key = Key.init(.escape, KeyModifiers.none) });
            },

            // Space
            '\x20' => Result.Final(.{ .key = Key.init(.space, KeyModifiers.none) }),

            // Ctrl + Space
            '\x00' => Result.Final(.{ .key = Key.init(.space, KeyModifiers.join(&.{.control})) }),

            // Backspace
            '\x7f' => Result.Final(.{ .key = Key.init(.backspace, KeyModifiers.none) }),

            // Tab
            '\x09' => Result.Final(.{ .key = Key.init(.tab, KeyModifiers.none) }),

            // Enter
            '\x0a'   => Result.Final(.{ .key = Key.init(.enter, KeyModifiers.none) }),

            // Ctrl + Character
            '\x01'...'\x08',
            '\x0b'...'\x1a' => Result.Final(.{ .key = Key.initChar(byte - 0x01 + 'a', KeyModifiers.join(if (self.state != .esc) &.{.control} else &.{ .control, .alt })) }),
            '\x1c'...'\x1f' => Result.Final(.{ .key = Key.initChar(byte - 0x1c + '4', KeyModifiers.join(if (self.state != .esc) &.{.control} else &.{ .control, .alt })) }),

            // Switch to CSI
            //
            // Possible Alt + [ keypress
            '[' => tag: {
                self.state = .csi;
                break :tag Result.Ambiguous(.{ .key = Key.initChar('[', KeyModifiers.join(&.{.alt})) });
            },

            // Character
            else => switch (self.state) {
                .default, .esc => self.utf8(byte),
                .csi           => self.csi(byte),
            },

            // zig fmt: on
        };
    }

    // zig fmt: off
    fn utf8(
        self: *InputParser,
        byte: u8,
    ) error{Unexpected}!Result {
        std.debug.assert(self.state != .csi);

        if (self.state == .esc and self.args[0] == 'O')
            return switch (byte) {
                'P'  => Result.Final(.{ .key = Key.init(.f1, KeyModifiers.none) }),
                'Q'  => Result.Final(.{ .key = Key.init(.f2, KeyModifiers.none) }),
                'R'  => Result.Final(.{ .key = Key.init(.f3, KeyModifiers.none) }),
                'S'  => Result.Final(.{ .key = Key.init(.f4, KeyModifiers.none) }),

                else => error.Unexpected,
            };

        self.args[self.nargs] = byte;
        self.nargs += 1;

        const len =
            std.unicode.utf8ByteSequenceLength(self.args[0])
                catch return error.Unexpected;
        if (len != self.nargs) return .none;

        const ch: u21 = switch (len) {
            1    => @intCast(byte),
            2    => std.unicode.utf8Decode2(self.args[0..2].*) catch return error.Unexpected,
            3    => std.unicode.utf8Decode3(self.args[0..3].*) catch return error.Unexpected,
            4    => std.unicode.utf8Decode4(self.args[0..4].*) catch return error.Unexpected,
            else => return error.Unexpected,
        };

        var modifiers = KeyModifiers.none;
        if (self.state == .esc)
            modifiers.set(&.{.alt});
        if (ch >= 'A' and ch <= 'Z')
            modifiers.set(&.{.shift});

        const input: Input = .{ .key = Key.initChar(ch, modifiers) };

        // the sequence "ESC O" is ambiguous;
        // it can still resolve to F1–F4 if followed by another byte.
        return if (self.state == .esc and ch == 'O')
            Result.Ambiguous(input)
        else
            Result.Final(input);
    }
    // zig fmt: on

    // zig fmt: off
    fn csi(
        self: *InputParser,
        byte: u8,
    ) error{Unexpected}!Result {
        std.debug.assert(self.state == .csi);

        return switch (byte) {
            // Arrow Keys
            'A' => self.arrow_key(.up_arrow),
            'B' => self.arrow_key(.down_arrow),
            'C' => self.arrow_key(.right_arrow),
            'D' => self.arrow_key(.left_arrow),

            // Home/End
            'H' => Result.Final(.{ .key = Key.init(.home, KeyModifiers.none) }),
            'F' => Result.Final(.{ .key = Key.init(.end,  KeyModifiers.none) }),

            // Shift + Tab : esc[Z
            'Z' => Result.Final(.{ .key = Key.init(.tab, KeyModifiers.join(&.{.shift})) }),

            '0'...'9' => tag: {
                self.args[self.nargs] = self.args[self.nargs] * 10 + (byte - '0');
                break :tag .none;
            },

            ';' => tag: {
                if (self.nargs != 0)
                    break :tag error.Unexpected;
                self.nargs = 1;
                break :tag .none;
            },

            '~' => tag: {
                if (self.nargs != 0)
                    return error.Unexpected;

                break :tag switch (self.args[0]) {
                     1 => Result.Final(.{ .key = Key.init(.home,      KeyModifiers.none) }),
                     2 => Result.Final(.{ .key = Key.init(.insert,    KeyModifiers.none) }),
                     3 => Result.Final(.{ .key = Key.init(.delete,    KeyModifiers.none) }),
                     4 => Result.Final(.{ .key = Key.init(.end,       KeyModifiers.none) }),
                     5 => Result.Final(.{ .key = Key.init(.page_up,   KeyModifiers.none) }),
                     6 => Result.Final(.{ .key = Key.init(.page_down, KeyModifiers.none) }),

                    15 => Result.Final(.{ .key = Key.init( .f5, KeyModifiers.none) }),
                    17 => Result.Final(.{ .key = Key.init( .f6, KeyModifiers.none) }),
                    18 => Result.Final(.{ .key = Key.init( .f7, KeyModifiers.none) }),
                    19 => Result.Final(.{ .key = Key.init( .f8, KeyModifiers.none) }),
                    20 => Result.Final(.{ .key = Key.init( .f9, KeyModifiers.none) }),
                    21 => Result.Final(.{ .key = Key.init(.f10, KeyModifiers.none) }),
                    23 => Result.Final(.{ .key = Key.init(.f11, KeyModifiers.none) }),
                    24 => Result.Final(.{ .key = Key.init(.f12, KeyModifiers.none) }),

                    else => error.Unexpected,
                };
            },

            else => return error.Unexpected,
        };
    }
    // zig fmt: on

    fn arrow_key(
        self: *InputParser,
        code: KeyCode,
    ) error{Unexpected}!Result {
        var modifiers: KeyModifiers = .none;
        if (self.args[0] == 1 and self.args[1] == 5)
            modifiers.set(&.{.control});
        return Result.Final(.{ .key = Key.init(code, modifiers) });
    }
};

test "unicode" {
    const sequence: []const u8 = "😀";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('😀', KeyModifiers.none) }),
        result,
    );
}

test "alt + unicode" {
    const sequence: []const u8 = "\x1b😀";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('😀', KeyModifiers.join(&.{.alt})) }),
        result,
    );
}

test "ascii letter" {
    const sequence: []const u8 = "z";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('z', KeyModifiers.none) }),
        result,
    );
}

test "alt + ascii letter" {
    const sequence: []const u8 = "\x1bz";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('z', KeyModifiers.join(&.{.alt})) }),
        result,
    );
}

test "shift + ascii letter" {
    const sequence: []const u8 = "Z";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('Z', KeyModifiers.join(&.{.shift})) }),
        result,
    );
}

test "alt + shift + ascii letter" {
    const sequence: []const u8 = "\x1bZ";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('Z', KeyModifiers.join(&.{ .alt, .shift })) }),
        result,
    );
}

test "control + ascii letter" {
    const sequence: []const u8 = "\x1a";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('z', KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "control + alt + ascii letter" {
    const sequence: []const u8 = "\x1b\x1a";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('z', KeyModifiers.join(&.{ .control, .alt })) }),
        result,
    );
}

test "digit" {
    const sequence: []const u8 = "4";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('4', KeyModifiers.none) }),
        result,
    );
}

test "alt + digit" {
    const sequence: []const u8 = "\x1b4";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('4', KeyModifiers.join(&.{.alt})) }),
        result,
    );
}

test "control + digit" {
    const sequence: []const u8 = "\x1c";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('4', KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "control + alt + digit" {
    const sequence: []const u8 = "\x1b\x1c";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('4', KeyModifiers.join(&.{ .control, .alt })) }),
        result,
    );
}

test "symbol" {
    const sequence: []const u8 = "$";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('$', KeyModifiers.none) }),
        result,
    );
}

test "alt + symbol" {
    const sequence: []const u8 = "\x1b$";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.initChar('$', KeyModifiers.join(&.{.alt})) }),
        result,
    );
}

test "up arrow" {
    const sequence: []const u8 = "\x1b[A";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.up_arrow, KeyModifiers.none) }),
        result,
    );
}

test "ctrl + up arrow" {
    const sequence: []const u8 = "\x1b[1;5A";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(6, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.up_arrow, KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "down arrow" {
    const sequence: []const u8 = "\x1b[B";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.down_arrow, KeyModifiers.none) }),
        result,
    );
}

test "ctrl + down arrow" {
    const sequence: []const u8 = "\x1b[1;5B";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(6, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.down_arrow, KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "left arrow" {
    const sequence: []const u8 = "\x1b[D";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.left_arrow, KeyModifiers.none) }),
        result,
    );
}

test "ctrl + left arrow" {
    const sequence: []const u8 = "\x1b[1;5D";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(6, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.left_arrow, KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "right arrow" {
    const sequence: []const u8 = "\x1b[C";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.right_arrow, KeyModifiers.none) }),
        result,
    );
}

test "ctrl + right arrow" {
    const sequence: []const u8 = "\x1b[1;5C";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(6, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.right_arrow, KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "home (1)" {
    const sequence: []const u8 = "\x1b[H";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.home, KeyModifiers.none) }),
        result,
    );
}

test "home (2)" {
    const sequence: []const u8 = "\x1b[1~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.home, KeyModifiers.none) }),
        result,
    );
}

test "end (1)" {
    const sequence: []const u8 = "\x1b[F";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.end, KeyModifiers.none) }),
        result,
    );
}

test "end (2)" {
    const sequence: []const u8 = "\x1b[4~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.end, KeyModifiers.none) }),
        result,
    );
}

test "enter" {
    const sequence: []const u8 = "\n";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.enter, KeyModifiers.none) }),
        result,
    );
}

test "space" {
    const sequence: []const u8 = " ";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.space, KeyModifiers.none) }),
        result,
    );
}

test "ctrl-space" {
    const sequence: []const u8 = "\x00";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.space, KeyModifiers.join(&.{.control})) }),
        result,
    );
}

test "backspace" {
    const sequence: []const u8 = "\x7f";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.backspace, KeyModifiers.none) }),
        result,
    );
}

test "escape" {
    const sequence: []const u8 = "\x1b";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(1, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Ambiguous(.{ .key = Key.init(.escape, KeyModifiers.none) }),
        result,
    );
}

test "insert" {
    const sequence: []const u8 = "\x1b[2~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.insert, KeyModifiers.none) }),
        result,
    );
}

test "delete" {
    const sequence: []const u8 = "\x1b[3~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.delete, KeyModifiers.none) }),
        result,
    );
}

test "page up" {
    const sequence: []const u8 = "\x1b[5~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.page_up, KeyModifiers.none) }),
        result,
    );
}

test "page down" {
    const sequence: []const u8 = "\x1b[6~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(4, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.page_down, KeyModifiers.none) }),
        result,
    );
}

test "ambiguous Ctrl-Shift-O" {
    const sequence: []const u8 = "\x1bO";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(2, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Ambiguous(.{ .key = Key.initChar('O', KeyModifiers.join(&.{ .alt, .shift })) }),
        result,
    );
}

test "f1" {
    const sequence: []const u8 = "\x1bOP";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f1, KeyModifiers.none) }),
        result,
    );
}

test "f2" {
    const sequence: []const u8 = "\x1bOQ";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f2, KeyModifiers.none) }),
        result,
    );
}

test "f3" {
    const sequence: []const u8 = "\x1bOR";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f3, KeyModifiers.none) }),
        result,
    );
}

test "f4" {
    const sequence: []const u8 = "\x1bOS";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(3, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f4, KeyModifiers.none) }),
        result,
    );
}

test "f5" {
    const sequence: []const u8 = "\x1b[15~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f5, KeyModifiers.none) }),
        result,
    );
}

test "f6" {
    const sequence: []const u8 = "\x1b[17~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f6, KeyModifiers.none) }),
        result,
    );
}

test "f7" {
    const sequence: []const u8 = "\x1b[18~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f7, KeyModifiers.none) }),
        result,
    );
}

test "f8" {
    const sequence: []const u8 = "\x1b[19~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f8, KeyModifiers.none) }),
        result,
    );
}

test "f9" {
    const sequence: []const u8 = "\x1b[20~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f9, KeyModifiers.none) }),
        result,
    );
}

test "f10" {
    const sequence: []const u8 = "\x1b[21~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f10, KeyModifiers.none) }),
        result,
    );
}

test "f11" {
    const sequence: []const u8 = "\x1b[23~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f11, KeyModifiers.none) }),
        result,
    );
}

test "f12" {
    const sequence: []const u8 = "\x1b[24~";
    var offset: usize = 0;
    var parser = InputParser{};
    const result = try parser.parse(sequence, &offset);

    try std.testing.expectEqual(5, offset);
    try std.testing.expectEqualDeep(
        InputParser.Result.Final(.{ .key = Key.init(.f12, KeyModifiers.none) }),
        result,
    );
}
