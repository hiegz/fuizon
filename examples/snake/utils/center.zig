const std = @import("std");
const fuizon = @import("fuizon");

const Area = fuizon.layout.Area;

pub fn center(area: Area, width: u16, height: u16) Area {
    std.debug.assert(width <= area.width and height <= area.height);
    var centered = @as(Area, undefined);
    centered.width = width;
    centered.height = height;
    centered.origin.x = area.origin.x + (area.width - width) / 2;
    centered.origin.y = area.origin.y + (area.height - height) / 2;
    return centered;
}
