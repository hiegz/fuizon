const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Attributes = fuizon.style.Attributes;
const Color = fuizon.style.Color;

const Area = fuizon.area.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

pub const Filler = struct {
    color: fuizon.style.Color,

    /// Renders the filler within a section of the specified frame,
    /// as defined by the provided area.
    pub fn render(self: Filler, frame: *Frame, area: Area) void {
        for (area.left()..area.right()) |x| {
            for (area.top()..area.bottom()) |y| {
                const cell = frame.index(@intCast(x), @intCast(y));
                cell.width = 1;
                cell.content = ' ';
                cell.style = .{
                    .foreground_color = .default,
                    .background_color = self.color,

                    .attributes = Attributes.none,
                };
            }
        }
    }
};

test "Filler.render()" {
    const expected_frame = try Frame.initContent(std.testing.allocator, &[_][]const u8{
        "   ",
        "   ",
        "   ",
    }, .{
        .foreground_color = .default,
        .background_color = .white,
        .attributes = Attributes.none,
    });
    defer expected_frame.deinit();

    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
    defer actual_frame.deinit();

    (Filler{ .color = .white }).render(&actual_frame, actual_frame.area);

    try std.testing.expectEqualSlices(
        FrameCell,
        expected_frame.buffer,
        actual_frame.buffer,
    );
}
