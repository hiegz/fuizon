const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.layout.Area;
const Frame = fuizon.frame.Frame;
const Color = fuizon.style.Color;

pub fn center(area: Area, width: u16, height: u16) Area {
    std.debug.assert(width <= area.width and height <= area.height);
    var centered = @as(Area, undefined);
    centered.width = width;
    centered.height = height;
    centered.origin.x = area.origin.x + (area.width - width) / 2;
    centered.origin.y = area.origin.y + (area.height - height) / 2;
    return centered;
}

// zig fmt: off
const red:         Color = .{ .rgb = .{ .r = 250, .g = 22,  .b = 50 } };
const light_red:   Color = .{ .rgb = .{ .r = 250, .g = 81,  .b = 50 } };
const dark_yellow: Color = .{ .rgb = .{ .r = 250, .g = 207, .b = 14 } };
const yellow:      Color = .{ .rgb = .{ .r = 250, .g = 227, .b = 13 } };
const orange:      Color = .{ .rgb = .{ .r = 250, .g = 130, .b = 8  } };
// zig fmt: on

const WIDTH: u16 = 6 * 2;
const HEIGHT: u16 = 10;

const Cell = struct { x: u16, y: u16, color: Color };
fn cell(x: u16, y: u16, color: Color) Cell {
    return .{ .x = x * 2, .y = y, .color = color };
}

const map = [_]Cell{
    cell(2, 0, red),
    cell(0, 1, red),
    cell(6, 2, red),

    cell(3, 2, red),
    cell(3, 3, red),
    cell(4, 3, red),
    cell(2, 4, red),
    cell(1, 5, red),
    cell(0, 6, red),
    cell(0, 7, red),
    cell(0, 8, red),
    cell(1, 9, red),
    cell(5, 5, red),
    cell(5, 6, red),
    cell(5, 7, red),
    cell(4, 8, red),
    cell(3, 9, red),

    cell(4, 7, light_red),
    cell(4, 6, light_red),
    cell(4, 5, light_red),
    cell(4, 4, light_red),
    cell(3, 4, light_red),
    cell(2, 5, light_red),
    cell(1, 6, light_red),

    cell(2, 6, orange),
    cell(1, 7, orange),
    cell(3, 8, orange),

    cell(1, 8, dark_yellow),
    cell(2, 9, dark_yellow),
    cell(3, 5, dark_yellow),
    cell(3, 6, dark_yellow),

    cell(3, 7, yellow),
    cell(2, 7, yellow),
    cell(2, 8, yellow),
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const stdout: *std.io.Writer = &stdout_writer.interface;
    defer stdout.flush() catch unreachable;

    try fuizon.backend.raw_mode.enable();
    defer fuizon.backend.raw_mode.disable() catch {};
    try fuizon.backend.alternate_screen.enter(stdout);
    defer fuizon.backend.alternate_screen.leave(stdout) catch {};
    try fuizon.backend.cursor.hide(stdout);
    defer fuizon.backend.cursor.show(stdout) catch {};

    var frame = try Frame.initArea(allocator, try fuizon.backend.area.fullscreen().render(stdout));
    defer frame.deinit();

    while (true) {
        try fuizon.backend.screen.clearAll(stdout);
        frame.reset();
        if (WIDTH <= frame.area.width and HEIGHT <= frame.area.height) {
            const art_area = center(frame.area, WIDTH, HEIGHT);
            for (map) |map_cell| {
                const x = art_area.origin.x + map_cell.x;
                const y = art_area.origin.y + map_cell.y;

                const l = frame.index(x + 0, y);
                const r = frame.index(x + 1, y);
                l.width = 1;
                l.content = ' ';
                l.style.background_color = map_cell.color;
                r.width = 1;

                r.content = ' ';
                r.style.background_color = map_cell.color;
            }
        }

        try fuizon.backend.frame.render(stdout, frame, Frame.none);
        try stdout.flush();
        switch (try fuizon.backend.event.read()) {
            .key => return,
            .resize => |d| try frame.resize(d.width, d.height),
        }
    }
}
