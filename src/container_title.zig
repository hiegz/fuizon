const std = @import("std");
const Character = @import("character.zig").Character;
const Style = @import("style.zig").Style;
const TextAlignment = @import("text_alignment.zig").TextAlignment;

pub const ContainerTitle = struct {
    character_list: std.ArrayList(Character) = .empty,
    alignment: TextAlignment = .left,

    pub const empty: ContainerTitle = .{};

    pub fn deinit(self: *ContainerTitle, gpa: std.mem.Allocator) void {
        self.character_list.deinit(gpa);
    }

    pub fn length(self: ContainerTitle) u16 {
        return @intCast(self.character_list.items.len);
    }

    pub fn append(
        self: *ContainerTitle,
        gpa: std.mem.Allocator,
        text: []const u8,
        style: Style,
    ) error{OutOfMemory}!void {
        var iterator = (std.unicode.Utf8View.init(text) catch @panic("Invalid UTF-8")).iterator();
        while (iterator.nextCodepoint()) |codepoint|
            try self.character_list.append(gpa, Character.init(codepoint, style));
    }
};
