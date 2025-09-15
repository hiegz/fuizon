const std = @import("std");
const fuizon = @import("fuizon");
const Area = fuizon.Area;
const Color = fuizon.Color;
const Rgb = fuizon.Rgb;

pub fn center(area: Area, width: u16, height: u16) Area {
    std.debug.assert(width <= area.width and height <= area.height);
    var centered = @as(Area, undefined);
    centered.width = width;
    centered.height = height;
    centered.x = area.x + (area.width - width) / 2;
    centered.y = area.y + (area.height - height) / 2;
    return centered;
}

// zig fmt: off
const red:         Color = Rgb(250,  22, 50);
const light_red:   Color = Rgb(250,  81, 50);
const dark_yellow: Color = Rgb(250, 207, 14);
const yellow:      Color = Rgb(250, 227, 13);
const orange:      Color = Rgb(250, 130,  8);
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
    defer fuizon.getWriter().flush() catch {};

    try fuizon.enableRawMode();
    defer fuizon.disableRawMode() catch {};
    try fuizon.enterAlternateScreen();
    defer fuizon.leaveAlternateScreen() catch {};
    try fuizon.hideCursor();
    defer fuizon.showCursor() catch {};

    while (true) {
        const screen = try fuizon.getScreenSize();
        try fuizon.clearScreen();

        if (WIDTH <= screen.width and HEIGHT <= screen.height) {
            const art_area = center(Area.init(screen.width, screen.height, 0, 0), WIDTH, HEIGHT);
            for (map) |map_cell| {
                const x = art_area.x + map_cell.x;
                const y = art_area.y + map_cell.y;

                try fuizon.moveCursorTo(x, y);
                try fuizon.setBackground(map_cell.color);
                try fuizon.getWriter().print("  ", .{});
                try fuizon.setBackground(.default);
            }
        }

        try fuizon.getWriter().flush();

        switch (try fuizon.event.read()) {
            .key => return,
            else => {},
        }
    }
}
