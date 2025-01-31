const std = @import("std");
const fuizon = @import("fuizon");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    try writer.print("Black:        ", .{});
    try fuizon.backend.text.background.set(writer, .black);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("White:        ", .{});
    try fuizon.backend.text.background.set(writer, .white);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Red:          ", .{});
    try fuizon.backend.text.background.set(writer, .red);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Red:     ", .{});
    try fuizon.backend.text.background.set(writer, .dark_red);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Green:        ", .{});
    try fuizon.backend.text.background.set(writer, .green);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Green:   ", .{});
    try fuizon.backend.text.background.set(writer, .dark_green);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Blue:         ", .{});
    try fuizon.backend.text.background.set(writer, .blue);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Blue:    ", .{});
    try fuizon.backend.text.background.set(writer, .dark_blue);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Yellow:       ", .{});
    try fuizon.backend.text.background.set(writer, .yellow);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Yellow:  ", .{});
    try fuizon.backend.text.background.set(writer, .dark_yellow);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Magenta:      ", .{});
    try fuizon.backend.text.background.set(writer, .magenta);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Magenta: ", .{});
    try fuizon.backend.text.background.set(writer, .dark_magenta);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Cyan:         ", .{});
    try fuizon.backend.text.background.set(writer, .cyan);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Cyan:    ", .{});
    try fuizon.backend.text.background.set(writer, .dark_cyan);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Grey:         ", .{});
    try fuizon.backend.text.background.set(writer, .grey);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Grey:    ", .{});
    try fuizon.backend.text.background.set(writer, .dark_grey);
    try writer.print("   ", .{});
    try fuizon.backend.text.background.set(writer, .default);
    try writer.print("\n\r", .{});
}
