const std = @import("std");
const KeyCode = @import("key_code.zig").KeyCode;
const KeyModifiers = @import("key_modifiers.zig").KeyModifiers;

pub const Key = struct {
    code: KeyCode,
    modifiers: KeyModifiers,

    pub fn init(code: KeyCode, modifiers: KeyModifiers) Key {
        return .{ .code = code, .modifiers = modifiers };
    }

    pub fn initChar(char: u21, modifiers: KeyModifiers) Key {
        return .{ .code = .{ .char = char }, .modifiers = modifiers };
    }

    pub fn format(self: Key, writer: *std.io.Writer) !void {
        try writer.print("Key {{ code: {f}, modifiers: {f} }}", .{ self.code, self.modifiers });
    }
};
