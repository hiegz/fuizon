// zig fmt: off

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
    rgb:  RgbColor,

    pub fn Ansi(value: u8) Color {
        return .{ .ansi = .{ .value = value } };
    }

    pub fn Rgb(r: u8, g: u8, b: u8) Color {
        return .{ .rgb = .{ .r = r, .g = g, .b = b } };
    }
};

pub const AnsiColor = struct { value: u8 };
pub const RgbColor  = struct { r: u8, g: u8, b: u8 };
