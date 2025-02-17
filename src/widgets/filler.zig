const std = @import("std");
const fuizon = @import("../fuizon.zig");

const Attributes = fuizon.style.Attributes;
const Style = fuizon.style.Style;
const Color = fuizon.style.Color;

const Area = fuizon.area.Area;
const Frame = fuizon.frame.Frame;
const FrameCell = fuizon.frame.FrameCell;

pub const Filler = struct {
    content: u21 = ' ',
    width: u2 = 1,
    style: Style = .{},

    /// Renders the filler within a section of the specified frame,
    /// as defined by the provided area.
    pub fn render(self: Filler, frame: *Frame, area: Area) void {
        for (area.left()..area.right()) |x| {
            for (area.top()..area.bottom()) |y| {
                const cell = frame.index(@intCast(x), @intCast(y));
                cell.width = self.width;
                cell.content = self.content;
                cell.style = self.style;
            }
        }
    }
};

test "Filler.render()" {
    const expected_frame = try Frame.initContent(std.testing.allocator, &[_][]const u8{
        "---",
        "---",
        "---",
    }, .{
        .foreground_color = .black,
        .background_color = .white,
        .attributes = Attributes.all,
    });
    defer expected_frame.deinit();

    var actual_frame = try Frame.initArea(std.testing.allocator, expected_frame.area);
    defer actual_frame.deinit();

    (Filler{
        .content = '-',
        .style = .{
            .foreground_color = .black,
            .background_color = .white,
            .attributes = Attributes.all,
        },
    }).render(&actual_frame, actual_frame.area);

    try std.testing.expectEqualSlices(
        FrameCell,
        expected_frame.buffer,
        actual_frame.buffer,
    );
}
