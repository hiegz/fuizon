const std = @import("std");
const fuizon = @import("fuizon");
const Ansi = fuizon.Ansi;
const Color = fuizon.Color;
const Style = fuizon.Style;

fn contrastColor(color: Color) Color {
    std.debug.assert(color == .ansi);

    const ansi = color.ansi;
    if (ansi.value == 0) return Ansi(15);
    if (ansi.value < 16) return Ansi(0);
    if (ansi.value > 231) {
        if (ansi.value < 244) return Ansi(15);
        return Ansi(0);
    }
    if (((ansi.value - 16) % 36) / 6 > 2) return Ansi(0);
    return Ansi(15);
}

fn style(color: Color) Style {
    std.debug.assert(color == .ansi);

    return .{
        .foreground_color = contrastColor(color),
        .background_color = color,
    };
}

pub fn main() !void {
    const writer = fuizon.getWriter();

    for (0..16) |c| {
        const s = style(Ansi(@intCast(c)));
        try fuizon.setForeground(s.foreground_color);
        try fuizon.setBackground(s.background_color);
        try writer.print("{: >3}", .{c});
        try fuizon.setForeground(.default);
        try fuizon.setBackground(.default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});
    try writer.print("\n\r", .{});

    for (16..232) |c| {
        if (c != 16 and (c - 16) % 36 == 0)
            try writer.print("\n\r", .{});
        const s = style(Ansi(@intCast(c)));
        try fuizon.setForeground(s.foreground_color);
        try fuizon.setBackground(s.background_color);
        try writer.print("{: >3}", .{c});
        try fuizon.setForeground(.default);
        try fuizon.setBackground(.default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});
    try writer.print("\n\r", .{});

    for (232..256) |c| {
        const s = style(Ansi(@intCast(c)));
        try fuizon.setForeground(s.foreground_color);
        try fuizon.setBackground(s.background_color);
        try writer.print("{: >3}", .{c});
        try fuizon.setForeground(.default);
        try fuizon.setBackground(.default);
        try writer.print(" ", .{});
    }
    try writer.print("\n\r", .{});

    try writer.flush();
}
