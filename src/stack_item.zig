const Dimensions = @import("dimensions.zig").Dimensions;
const SizePolicy = @import("size_policy.zig").SizePolicy;
const Widget = @import("widget.zig").Widget;

pub const StackItem = struct {
    widget: Widget,
    size_policy: SizePolicy,

    /// For measurement
    _dimensions: Dimensions = undefined,

    /// Relevant during rendering and measurement.
    _value: u16 = undefined,

    pub fn init(widget: anytype, size_policy: SizePolicy) StackItem {
        return .{ .widget = Widget.impl(widget), .size_policy = size_policy };
    }

    pub const item = StackItem.init;
};
