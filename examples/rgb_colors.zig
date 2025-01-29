const std = @import("std");
const fuizon = @import("fuizon");

fn prompt(p: []const u8, reader: anytype, backend: anytype) !u8 {
    var buffer: [4]u8 = undefined;
    var slice: []u8 = undefined;

    try backend.write(p, null);
    slice = try reader.readUntilDelimiter(&buffer, '\n');
    return try std.fmt.parseInt(u8, slice, 10);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();
    var backend = try fuizon.crossterm.Backend(@TypeOf(writer)).init(allocator, writer);
    defer backend.deinit();

    const r: u8 = prompt("Red: ", reader, &backend) catch {
        try backend.write("Invalid input\n", null);
        return;
    };
    const g: u8 = prompt("Green: ", reader, &backend) catch {
        try backend.write("Invalid input\n", null);
        return;
    };
    const b: u8 = prompt("Blue: ", reader, &backend) catch {
        try backend.write("Invalid input\n", null);
        return;
    };

    try backend.write("\n\r", null);
    try backend.write("Your color: ", null);
    try backend.write("            ", .{ .background_color = .{ .rgb = .{ .r = r, .g = g, .b = b } } });
    try backend.write("\n\r", null);
}
