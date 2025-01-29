const std = @import("std");
const fuizon = @import("fuizon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();
    var backend = try fuizon.crossterm.Backend(@TypeOf(writer)).init(allocator, writer);
    defer backend.deinit();

    try backend.write("Black:        ", null);
    try backend.write("   ", .{ .background_color = .black });
    try backend.write("\n\r", null);

    try backend.write("White:        ", null);
    try backend.write("   ", .{ .background_color = .white });
    try backend.write("\n\r", null);

    try backend.write("Red:          ", null);
    try backend.write("   ", .{ .background_color = .red });
    try backend.write("\n\r", null);

    try backend.write("Dark Red:     ", null);
    try backend.write("   ", .{ .background_color = .dark_red });
    try backend.write("\n\r", null);

    try backend.write("Green:        ", null);
    try backend.write("   ", .{ .background_color = .green });
    try backend.write("\n\r", null);

    try backend.write("Dark Green:   ", null);
    try backend.write("   ", .{ .background_color = .dark_green });
    try backend.write("\n\r", null);

    try backend.write("Blue:         ", null);
    try backend.write("   ", .{ .background_color = .blue });
    try backend.write("\n\r", null);

    try backend.write("Dark Blue:    ", null);
    try backend.write("   ", .{ .background_color = .dark_blue });
    try backend.write("\n\r", null);

    try backend.write("Yellow:       ", null);
    try backend.write("   ", .{ .background_color = .yellow });
    try backend.write("\n\r", null);

    try backend.write("Dark Yellow:  ", null);
    try backend.write("   ", .{ .background_color = .dark_yellow });
    try backend.write("\n\r", null);

    try backend.write("Magenta:      ", null);
    try backend.write("   ", .{ .background_color = .magenta });
    try backend.write("\n\r", null);

    try backend.write("Dark Magenta: ", null);
    try backend.write("   ", .{ .background_color = .dark_magenta });
    try backend.write("\n\r", null);

    try backend.write("Cyan:         ", null);
    try backend.write("   ", .{ .background_color = .cyan });
    try backend.write("\n\r", null);

    try backend.write("Dark Cyan:    ", null);
    try backend.write("   ", .{ .background_color = .dark_cyan });
    try backend.write("\n\r", null);

    try backend.write("Grey:         ", null);
    try backend.write("   ", .{ .background_color = .grey });
    try backend.write("\n\r", null);

    try backend.write("Dark Grey:    ", null);
    try backend.write("   ", .{ .background_color = .dark_grey });
    try backend.write("\n\r", null);
}
