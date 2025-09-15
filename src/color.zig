const std = @import("std");
const fuizon = @import("fuizon.zig");

pub const Color = union(enum) {
    default,
    black,
    white,
    red,
    green,
    blue,
    yellow,
    magenta,
    cyan,
    grey,
    dark_red,
    dark_green,
    dark_blue,
    dark_yellow,
    dark_magenta,
    dark_cyan,
    dark_grey,

    ansi: AnsiColor,
    rgb: RgbColor,
};

pub const AnsiColor = struct {
    value: u8,
};

pub fn Ansi(value: u8) Color {
    return .{ .ansi = .{ .value = value } };
}

pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub fn Rgb(r: u8, g: u8, b: u8) Color {
    return .{ .rgb = .{ .r = r, .g = g, .b = b } };
}

pub fn setForeground(color: Color) !void {
    _ = color;
    // Not implemented
}

pub fn setBackground(color: Color) !void {
    _ = color;
    // Not implemented
}
