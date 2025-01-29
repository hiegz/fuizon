const std = @import("std");
const fuizon = @import("fuizon");

fn prompt(comptime p: []const u8, reader: anytype, writer: anytype) !u8 {
    var buffer: [4]u8 = undefined;
    var slice: []u8 = undefined;

    try writer.print(p, .{});
    slice = try reader.readUntilDelimiter(&buffer, '\n');
    return try std.fmt.parseInt(u8, slice, 10);
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    const reader = stdin.reader();
    const writer = stdout.writer();

    const r: u8 = prompt("Red: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        return;
    };
    const g: u8 = prompt("Green: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        return;
    };
    const b: u8 = prompt("Blue: ", reader, writer) catch {
        try writer.print("Invalid input\n", .{});
        return;
    };

    try writer.print("\n\r", .{});
    try writer.print("Your color: ", .{});
    try fuizon.crossterm.text.background.set(writer, .{ .rgb = .{ .r = r, .g = g, .b = b } });
    try writer.print("            ", .{});
    try fuizon.crossterm.text.background.set(writer, .default);
    try writer.print("\n\r", .{});
}
