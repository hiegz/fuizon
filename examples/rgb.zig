const std = @import("std");
const fuizon = @import("fuizon");

fn prompt(comptime p: []const u8, reader: *std.io.Reader, writer: *std.io.Writer) !u8 {
    try writer.print(p, .{});
    try writer.flush();
    const slice = try reader.takeDelimiterExclusive('\n');
    return try std.fmt.parseInt(u8, slice, 10);
}

pub fn main() !void {
    var read_buffer: [4]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&read_buffer);
    const reader = &stdin_reader.interface;

    const writer = fuizon.getWriter();

    const r: u8 = prompt("Red: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        try writer.flush();
        return;
    };
    const g: u8 = prompt("Green: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        try writer.flush();
        return;
    };
    const b: u8 = prompt("Blue: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        try writer.flush();
        return;
    };

    try writer.print("\n\r", .{});
    try writer.print("Your color: ", .{});
    try fuizon.setBackground(fuizon.Rgb(r, g, b));
    try writer.print("            ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.flush();
}
