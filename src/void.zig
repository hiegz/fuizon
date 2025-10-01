const Dimensions = @import("dimensions.zig").Dimensions;
const Area = @import("area.zig").Area;
const Buffer = @import("buffer.zig").Buffer;
const Widget = @import("widget.zig").Widget;

pub const Void = (struct {
    const Self = @This();

    pub fn measure(
        self: Self,
        opts: Widget.MeasureOptions,
    ) anyerror!Dimensions {
        _ = self;
        _ = opts;
        return Dimensions.init(0, 0);
    }

    pub fn render(
        self: Self,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        _ = self;
        _ = buffer;
        _ = area;
    }
}){};
