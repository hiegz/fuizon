const std = @import("std");
const fuizon = @import("fuizon.zig");
const vt = @import("vt.zig");
const ESC = vt.ESC;
const CSI = vt.CSI;

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

    ansi: AnsiColor,
    rgb: RgbColor,

    fn writeForegroundSequence(
        self: Color,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return switch (self) {
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

            .ansi    => |ansi| ansi.writeForegroundSequence(writer),
            .rgb     => |rgb|   rgb.writeForegroundSequence(writer),
            // zig fmt: on
        };
    }

    fn writeBackgroundSequence(
        self: Color,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return switch (self) {
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

            .ansi    => |ansi| ansi.writeBackgroundSequence(writer),
            .rgb     => |rgb|   rgb.writeBackgroundSequence(writer),
            // zig fmt: on
        };
    }
};

pub const AnsiColor = struct {
    value: u8,

    fn writeForegroundSequence(
        self: AnsiColor,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return writer.print(CSI ++ "38;5;{d}m", .{self.value});
    }

    fn writeBackgroundSequence(
        self: AnsiColor,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return writer.print(CSI ++ "48;5;{d}m", .{self.value});
    }
};

pub fn Ansi(value: u8) Color {
    return .{ .ansi = .{ .value = value } };
}

pub const RgbColor = struct {
    r: u8,
    g: u8,
    b: u8,

    fn writeForegroundSequence(
        self: RgbColor,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return writer.print(
            CSI ++ "38;2;{d};{d};{d}m",
            .{ self.r, self.g, self.b },
        );
    }

    fn writeBackgroundSequence(
        self: RgbColor,
        writer: *std.Io.Writer,
    ) error{WriteFailed}!void {
        return writer.print(
            CSI ++ "48;2;{d};{d};{d}m",
            .{ self.r, self.g, self.b },
        );
    }
};

pub fn Rgb(r: u8, g: u8, b: u8) Color {
    return .{ .rgb = .{ .r = r, .g = g, .b = b } };
}

pub fn setForeground(color: Color) error{WriteFailed}!void {
    return color.writeForegroundSequence(fuizon.getWriter());
}

pub fn setBackground(color: Color) !void {
    return color.writeBackgroundSequence(fuizon.getWriter());
}
