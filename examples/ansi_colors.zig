const std = @import("std");
const fuizon = @import("fuizon");

fn contrastColor(color: fuizon.AnsiColor) fuizon.AnsiColor {
    if (color.value == 0) return .{ .value = 15 };
    if (color.value < 16) return .{ .value = 0 };
    if (color.value > 231) {
        if (color.value < 244) return .{ .value = 15 };
        return .{ .value = 0 };
    }
    if (((color.value - 16) % 36) / 6 > 2) return .{ .value = 0 };
    return .{ .value = 15 };
}

fn style(color: fuizon.AnsiColor) fuizon.Style {
    return .{
        .foreground_color = .{ .ansi = contrastColor(color) },
        .background_color = .{ .ansi = color },
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();
    var backend = try fuizon.crossterm.Backend(@TypeOf(writer)).init(allocator, writer);
    defer backend.deinit();

    inline for (0..16) |c| {
        try backend.write(
            std.fmt.comptimePrint("{: >3}", .{c}),
            style(.{ .value = @intCast(c) }),
        );
        try backend.write(" ", null);
    }
    try backend.write("\n\r", null);
    try backend.write("\n\r", null);

    inline for (16..232) |c| {
        if (c != 16 and (c - 16) % 36 == 0)
            try backend.write("\n\r", null);
        try backend.write(
            std.fmt.comptimePrint("{: >3}", .{c}),
            style(.{ .value = @intCast(c) }),
        );
        try backend.write(" ", null);
    }
    try backend.write("\n\r", null);
    try backend.write("\n\r", null);

    inline for (232..256) |c| {
        try backend.write(
            std.fmt.comptimePrint("{: >3}", .{c}),
            style(.{ .value = @intCast(c) }),
        );
        try backend.write(" ", null);
    }
    try backend.write("\n\r", null);
}
