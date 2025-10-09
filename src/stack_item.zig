const Dimensions = @import("dimensions.zig").Dimensions;
const Constraint = @import("constraint.zig").Constraint;
const Widget = @import("widget.zig").Widget;

pub const StackItem = struct {
    widget: Widget,
    constraint: Constraint,

    /// For measurement
    _dimensions: Dimensions = undefined,

    /// Relevant during rendering and measurement.
    _value: u16 = undefined,

    pub fn init(widget: anytype, constraint: Constraint) StackItem {
        return .{ .widget = Widget.impl(widget), .constraint = constraint };
    }

    pub const item = StackItem.init;
};
