const std = @import("std");
const fuizon = @import("fuizon");

pub fn main() !void {
    try fuizon.init(std.heap.page_allocator, 1024, .stdout);
    defer fuizon.deinit(std.heap.page_allocator) catch unreachable;

    const writer = fuizon.getWriter();

    try writer.print("Black:   ", .{});
    try fuizon.setForeground(.black);
    try fuizon.setBackground(.black);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("White:   ", .{});
    try fuizon.setForeground(.white);
    try fuizon.setBackground(.white);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Red:     ", .{});
    try fuizon.setForeground(.red);
    try fuizon.setBackground(.red);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Green:   ", .{});
    try fuizon.setForeground(.green);
    try fuizon.setBackground(.green);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Blue:    ", .{});
    try fuizon.setForeground(.blue);
    try fuizon.setBackground(.blue);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Yellow:  ", .{});
    try fuizon.setForeground(.yellow);
    try fuizon.setBackground(.yellow);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Magenta: ", .{});
    try fuizon.setForeground(.magenta);
    try fuizon.setBackground(.magenta);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Cyan:    ", .{});
    try fuizon.setForeground(.cyan);
    try fuizon.setBackground(.cyan);
    try writer.print("this text should be invisible", .{});
    try fuizon.setForeground(.default);
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.flush();
}
