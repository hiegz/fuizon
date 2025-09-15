const std = @import("std");
const fuizon = @import("fuizon");

pub fn main() !void {
    try fuizon.init(std.heap.page_allocator, 1024, .stdout);
    defer fuizon.deinit(std.heap.page_allocator);

    const writer = fuizon.getWriter();

    try writer.print("Black:        ", .{});
    try fuizon.setBackground(.black);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("White:        ", .{});
    try fuizon.setBackground(.white);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Red:          ", .{});
    try fuizon.setBackground(.red);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Red:     ", .{});
    try fuizon.setBackground(.dark_red);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Green:        ", .{});
    try fuizon.setBackground(.green);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Green:   ", .{});
    try fuizon.setBackground(.dark_green);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Blue:         ", .{});
    try fuizon.setBackground(.blue);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Blue:    ", .{});
    try fuizon.setBackground(.dark_blue);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Yellow:       ", .{});
    try fuizon.setBackground(.yellow);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Yellow:  ", .{});
    try fuizon.setBackground(.dark_yellow);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Magenta:      ", .{});
    try fuizon.setBackground(.magenta);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Magenta: ", .{});
    try fuizon.setBackground(.dark_magenta);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Cyan:         ", .{});
    try fuizon.setBackground(.cyan);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Cyan:    ", .{});
    try fuizon.setBackground(.dark_cyan);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Grey:         ", .{});
    try fuizon.setBackground(.grey);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.print("Dark Grey:    ", .{});
    try fuizon.setBackground(.dark_grey);
    try writer.print("   ", .{});
    try fuizon.setBackground(.default);
    try writer.print("\n\r", .{});

    try writer.flush();
}
