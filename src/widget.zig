const std = @import("std");
const Buffer = @import("buffer.zig").Buffer;
const Area = @import("area.zig").Area;
const Dimensions = @import("dimensions.zig").Dimensions;

pub const Widget = struct {

    // zig fmt: off
    data:      *const anyopaque,
    measureFn: *const fn (*const anyopaque, MeasureOptions) anyerror!Dimensions,
    renderFn:  *const fn (*const anyopaque, *Buffer, Area) anyerror!void,

    pub const MeasureOptions = struct {
        max_width:  u16 = std.math.maxInt(u16),
        max_height: u16 = std.math.maxInt(u16),

        pub fn init(max_width: u16, max_height: u16) MeasureOptions {
            return .{ .max_width = max_width, .max_height = max_height };
        }

        pub const opts = MeasureOptions.init;
    };

    pub fn impl(w: anytype) Widget {
        return .{
            .data      = @ptrCast(@alignCast(w)),

            .measureFn = Widget.makeMeasureFn(@TypeOf(w)),
            .renderFn  = Widget.makeRenderFn(@TypeOf(w)),
        };
    }
    // zig fmt: on

    pub fn measure(
        self: Widget,
        opts: MeasureOptions,
    ) anyerror!Dimensions {
        return self.measureFn(self.data, opts);
    }

    pub fn makeMeasureFn(comptime T: type) fn (*const anyopaque, MeasureOptions) anyerror!Dimensions {
        return struct {
            pub fn function(data: *const anyopaque, opts: MeasureOptions) anyerror!Dimensions {
                return @as(T, @ptrCast(@alignCast(data))).measure(opts);
            }
        }.function;
    }

    pub fn render(
        self: Widget,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        return self.renderFn(self.data, buffer, area);
    }

    pub fn makeRenderFn(comptime T: type) fn (*const anyopaque, *Buffer, Area) anyerror!void {
        return struct {
            pub fn function(data: *const anyopaque, buffer: *Buffer, area: Area) anyerror!void {
                return @as(T, @ptrCast(@alignCast(data))).render(buffer, area);
            }
        }.function;
    }
};
