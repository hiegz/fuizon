const StackConstraint = @import("stack_constraint.zig").StackConstraint;
const Widget = @import("widget.zig").Widget;

pub const StackItem = struct {
    widget: Widget,
    constraint: StackConstraint,

    /// Relevant during rendering and measurement.
    _value: u16 = undefined,

    pub fn init(widget: Widget, constraint: StackConstraint) StackItem {
        return .{ .widget = widget, .constraint = constraint };
    }

    pub const item = StackItem.init;
};
