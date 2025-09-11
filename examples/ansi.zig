const std = @import("std");
const fuizon = @import("fuizon");

const AnsiColor = fuizon.style.AnsiColor;
const Style = fuizon.style.Style;

fn contrastColor(color: AnsiColor) AnsiColor {
    if (color.value == 0) return .{ .value = 15 };
    if (color.value < 16) return .{ .value = 0 };
    if (color.value > 231) {
        if (color.value < 244) return .{ .value = 15 };
        return .{ .value = 0 };
    }
    if (((color.value - 16) % 36) / 6 > 2) return .{ .value = 0 };
    return .{ .value = 15 };
}

fn style(color: AnsiColor) Style {
    return .{
        .foreground_color = .{ .ansi = contrastColor(color) },
        .background_color = .{ .ansi = color },
    };
}

pub fn main() !void {
    var buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch unreachable;

    for (0..16) |c| {
        const s = style(.{ .value = @intCast(c) });
        try fuizon.backend.text.foreground.set(writer, s.foreground_color.?);
        try fuizon.backend.text.background.set(writer, s.background_color.?);
        try writer.print("{: >3}", .{c});
        try fuizon.backend.text.foreground.set(writer, .default);
        try fuizon.backend.text.background.set(writer, .default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});
    try writer.print("\n\r", .{});

    for (16..232) |c| {
        if (c != 16 and (c - 16) % 36 == 0)
            try writer.print("\n\r", .{});
        const s = style(.{ .value = @intCast(c) });
        try fuizon.backend.text.foreground.set(writer, s.foreground_color.?);
        try fuizon.backend.text.background.set(writer, s.background_color.?);
        try writer.print("{: >3}", .{c});
        try fuizon.backend.text.foreground.set(writer, .default);
        try fuizon.backend.text.background.set(writer, .default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});
    try writer.print("\n\r", .{});

    for (232..256) |c| {
        const s = style(.{ .value = @intCast(c) });
        try fuizon.backend.text.foreground.set(writer, s.foreground_color.?);
        try fuizon.backend.text.background.set(writer, s.background_color.?);
        try writer.print("{: >3}", .{c});
        try fuizon.backend.text.foreground.set(writer, .default);
        try fuizon.backend.text.background.set(writer, .default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});
}
