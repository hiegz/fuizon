const std = @import("std");
const Attribute = @import("attribute.zig").Attribute;
const Color = @import("color.zig").Color;

/// Escape Sequence (ESC)
pub const ESC = "\x1b";

/// Control Sequence Introducer (CSI)
pub const CSI = "\x1b[";

pub fn enterAlternateScreen(
    writer: *std.Io.Writer,
) error{WriteFailed}!void {
    return writer.writeAll(CSI ++ "?1049h");
}

pub fn leaveAlternateScreen(
    writer: *std.Io.Writer,
) error{WriteFailed}!void {
    return writer.writeAll(CSI ++ "?1049l");
}

pub fn setForeground(
    writer: *std.Io.Writer,
    color: Color,
) error{WriteFailed}!void {
    return switch (color) {
        // zig fmt: off
        .default => writer.writeAll(CSI ++ "39m"),
        .black   => writer.writeAll(CSI ++ "30m"),
        .white   => writer.writeAll(CSI ++ "37m"),
        .red     => writer.writeAll(CSI ++ "31m"),
        .green   => writer.writeAll(CSI ++ "32m"),
        .blue    => writer.writeAll(CSI ++ "34m"),
        .yellow  => writer.writeAll(CSI ++ "33m"),
        .magenta => writer.writeAll(CSI ++ "35m"),
        .cyan    => writer.writeAll(CSI ++ "36m"),

        .ansi    => |ansi| writer.print(CSI ++ "38;5;{d}m", .{ansi.value}),
        .rgb     => |rgb|  writer.print(CSI ++ "38;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }),
        // zig fmt: on
    };
}

/// ...
pub fn setBackground(
    writer: *std.Io.Writer,
    color: Color,
) error{WriteFailed}!void {
    return switch (color) {
        // zig fmt: off
        .default => writer.writeAll(CSI ++ "49m"),
        .black   => writer.writeAll(CSI ++ "40m"),
        .white   => writer.writeAll(CSI ++ "47m"),
        .red     => writer.writeAll(CSI ++ "41m"),
        .green   => writer.writeAll(CSI ++ "42m"),
        .blue    => writer.writeAll(CSI ++ "44m"),
        .yellow  => writer.writeAll(CSI ++ "43m"),
        .magenta => writer.writeAll(CSI ++ "45m"),
        .cyan    => writer.writeAll(CSI ++ "46m"),

        .ansi    => |ansi| writer.print(CSI ++ "48;5;{d}m", .{ansi.value}),
        .rgb     => |rgb|  writer.print(CSI ++ "48;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }),
        // zig fmt: on
    };
}

pub fn setAttribute(
    writer: *std.Io.Writer,
    attribute: Attribute,
) error{WriteFailed}!void {
    return switch (attribute) {
        // zig fmt: off
        .bold      => writer.writeAll(CSI ++ "1m"),
        .dim       => writer.writeAll(CSI ++ "2m"),
        .underline => writer.writeAll(CSI ++ "4m"),
        .reverse   => writer.writeAll(CSI ++ "7m"),
        .hidden    => writer.writeAll(CSI ++ "8m"),
        // zig fmt: on
    };
}

pub fn resetAttribute(
    writer: *std.Io.Writer,
    attribute: Attribute,
) error{WriteFailed}!void {
    return switch (attribute) {
        // zig fmt: off
        .bold      => writer.writeAll(CSI ++ "21m"),
        .dim       => writer.writeAll(CSI ++ "22m"),
        .underline => writer.writeAll(CSI ++ "24m"),
        .reverse   => writer.writeAll(CSI ++ "27m"),
        .hidden    => writer.writeAll(CSI ++ "28m"),
        // zig fmt: on
    };
}

pub fn showCursor(
    writer: *std.Io.Writer,
) error{WriteFailed}!void {
    try writer.writeAll(CSI ++ "?25h");
}

pub fn hideCursor(
    writer: *std.Io.Writer,
) error{WriteFailed}!void {
    try writer.writeAll(CSI ++ "?25l");
}

pub fn moveCursorUp(
    writer: *std.io.Writer,
    n: u16,
) error{WriteFailed}!void {
    try writer.print(CSI ++ "{d}A", .{n});
}

pub fn moveCursorDown(
    writer: *std.io.Writer,
    n: u16,
) error{WriteFailed}!void {
    try writer.print(CSI ++ "{d}B", .{n});
}

pub fn moveCursorForward(
    writer: *std.Io.Writer,
    n: u16,
) error{WriteFailed}!void {
    try writer.print(CSI ++ "{d}C", .{n});
}

pub fn moveCursorBackward(
    writer: *std.Io.Writer,
    n: u16,
) error{WriteFailed}!void {
    try writer.print(CSI ++ "{d}D", .{n});
}
