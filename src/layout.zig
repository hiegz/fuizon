const std = @import("std");
const fuiwi = @import("fuiwi.zig");
const fuizon = @import("fuizon.zig");

const Area = fuizon.area.Area;

/// Dynamic layout configuration API.
pub const Layout = struct {
    /// The underlying allocator.
    allocator: std.mem.Allocator,

    /// The underlying constraint solver.
    solver: fuiwi.Solver,

    /// Intermediate expression instances.
    expression: [2]fuiwi.Expression,

    //

    /// Length of the layout.
    ///
    /// Whenever the value of this variable is adjusted, the underlying solver
    /// will attempt to scale the entire layout, ensuring it fits within the
    /// new length without exceeding it. If the solver fails to satisfy all the
    /// constraints, the variable may be modified in which case the layout is
    /// considered violated.
    length_variable: fuiwi.Variable,

    /// Direction of the layout.
    ///
    /// Specifies which dimension to divide into segments: width for
    /// horizontal, or height for vertical.
    direction: LayoutDirection,

    /// The target area.
    ///
    /// Specifies the objective area for the solver by suggesting the respective
    /// values for the `start` and `length` variables. If these values deviate
    /// after modifying the layout constraints, the entire layout is considered
    /// violated.
    area: Area,

    /// A list of areas resolved by the solver.
    ///
    /// This list contains the areas that have been processed and resolved by
    /// the solver. If the layout is valid and all constraints are satisfied,
    /// the areas are expected to align with the provided segment constraints.
    area_list: std.ArrayList(Area),

    /// A list of the user-specified segments.
    ///
    /// Segments are linked in the order they appear, preserving their relative
    /// relationships and layout constraints. It is important to unlink any
    /// affected segments before modifying the list, as failing to do so may
    /// irreversibly break the links between segments.
    segment_list: std.ArrayList(Segment),

    /// A hash map of constraints.
    ///
    /// Maps solver constraints to the respective segments. It provides a convenient
    /// way to remove constraints from the solver as the associated segments
    /// are removed from the layout.
    constraint_map: ConstraintMap,

    /// A start constraint.
    ///
    /// Ensures that a segment begins at the start coordinate (0) of the
    /// layout.
    ///
    /// Use linkStart() apply or unlinkStart() to remove this constrating from
    /// the first segment in the segment list.
    start_constraint: ?fuiwi.Constraint,

    //

    /// Initializes a new layout with the provided allocator and specified direction.
    pub fn init(allocator: std.mem.Allocator, direction: LayoutDirection) error{OutOfMemory}!Layout {
        var self: Layout = undefined;

        self.allocator = allocator;

        //

        self.solver = try fuiwi.Solver.init(allocator);
        errdefer self.solver.deinit();

        self.expression[0] = try fuiwi.Expression.init(allocator);
        errdefer self.expression[0].deinit();

        self.expression[1] = try fuiwi.Expression.init(allocator);
        errdefer self.expression[1].deinit();

        //

        self.direction = direction;
        self.area = undefined;

        self.area_list = std.ArrayList(Area).init(allocator);
        errdefer self.area_list.deinit();

        self.segment_list = std.ArrayList(Segment).init(allocator);
        errdefer self.segment_list.deinit();

        self.constraint_map = ConstraintMap.init(self.allocator);
        errdefer self.constraint_map.deinit();

        //

        self.length_variable = try fuiwi.Variable.init(allocator);
        errdefer self.length_variable.deinit();

        try self.solver.addVariable(self.length_variable, fuiwi.Strength.strong);
        errdefer self.solver.removeVariable(self.length_variable);

        self.start_constraint = null;

        // Initialize the segment list
        //
        // Adds a dummy element to represent the end of the layout such that
        // other elements can dynamically link to it.

        // zig fmt: off
        try self.segment_list.append(undefined);
        const end_seg = &self.segment_list.items[self.segment_list.items.len - 1];
        end_seg.* = try Segment.init(allocator, .{ .length = 0 });
        errdefer end_seg.deinit();
        // zig fmt: on

        self.expression[0].reset();
        self.expression[1].reset();

        try self.expression[0].addTerm(end_seg.variable, 1.0);
        try self.expression[1].addConstant(0.0);

        // end_segment >= 0
        //
        // Ensure that the variable is non-negative.
        const end_geq_zero = self.addSegmentConstraint(
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.geq,
            fuiwi.Strength.required,
            &[_]u64{end_seg.id},
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnsatisfiableConstraint => @panic("Internal Error"),
        };
        errdefer self.removeSegmentConstraint(end_geq_zero);

        self.expression[0].reset();
        self.expression[1].reset();

        try self.expression[0].addTerm(end_seg.variable, 1.0);
        try self.expression[1].addTerm(self.length_variable, 1.0);

        // end_segment <= length
        //
        // Ensure that the end is at most the suggested length.
        const end_leq_layout_length = self.addSegmentConstraint(
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.leq,
            fuiwi.Strength.required,
            &[_]u64{end_seg.id},
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnsatisfiableConstraint => @panic("Internal Error"),
        };
        errdefer self.removeSegmentConstraint(end_leq_layout_length);

        // end_segment -> length
        //
        // Ensure that the end grows towards the suggested length.
        const end_grows_towards_layout_length = self.addSegmentConstraint(
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.eq,
            fuiwi.Strength.strong,
            &[_]u64{end_seg.id},
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnsatisfiableConstraint => @panic("Internal Error"),
        };
        errdefer self.removeSegmentConstraint(end_grows_towards_layout_length);

        //

        return self;
    }

    /// Deinitializes the layout.
    pub fn deinit(self: *Layout) void {
        self.expression[0].deinit();
        self.expression[1].deinit();

        self.area_list.deinit();

        for (self.segment_list.items) |seg|
            seg.deinit();
        self.segment_list.deinit();

        for (self.constraint_map.keys()) |constraint| {
            self.solver.removeConstraint(constraint.*);
            constraint.deinit();
            self.allocator.destroy(constraint);
        }
        for (self.constraint_map.values()) |segid_list|
            segid_list.deinit();
        self.constraint_map.deinit();

        if (self.start_constraint) |start_constraint| {
            start_constraint.deinit();
        }

        self.solver.removeVariable(self.length_variable);
        self.length_variable.deinit();

        self.solver.deinit();
    }

    /// Returns a slice containing the areas that have been processed and
    /// resolved by the underlying constraint solver.
    ///
    /// Consider calling refresh() on the respective layout instance to ensure
    /// the areas are up-to-date and reflect the latest layout size and applied
    /// constraints.
    pub fn areas(self: Layout) []Area {
        return self.area_list.items;
    }

    //

    /// Inserts a new segment with the provided layout constraint at the specified index.
    ///
    /// If the layout constraint for the new segment cannot be satisfied, the
    /// function returns the `UnsatisfiableConstraint` error. This can occur if
    /// the segment is constrained to occupy a fraction of the layout that
    /// cannot be fulfilled — either because the fraction is invalid (e.g.,
    /// 2/1, 3/2, 5/3, etc.), or because the space required for that fraction
    /// is already occupied by other segments.
    pub fn insert(self: *Layout, index: usize, constraint: LayoutConstraint) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        std.debug.assert(index <= self.segment_list.items.len - 1);
        if (index == 0)
            return self.prepend(constraint);
        const seg = try Segment.init(self.allocator, constraint);
        errdefer seg.deinit();

        self.unlink(index - 1);
        errdefer self.link(index - 1) catch @panic("Internal Error");

        try self.segment_list.insert(index, seg);
        errdefer _ = self.segment_list.orderedRemove(index);

        try self.link(index);
        errdefer self.unlink(index);

        try self.link(index - 1);
    }

    /// Inserts a new segment with the specified layout constraint before the
    /// first element in the segment list.
    ///
    /// If the layout constraint for the new segment cannot be satisfied, the
    /// function returns the `UnsatisfiableConstraint` error. This can occur if
    /// the segment is constrained to occupy a fraction of the layout that
    /// cannot be fulfilled — either because the fraction is invalid (e.g.,
    /// 2/1, 3/2, 5/3, etc.), or because the space required for that fraction
    /// is already occupied by other segments.
    pub fn prepend(self: *Layout, constraint: LayoutConstraint) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        const seg = try Segment.init(self.allocator, constraint);
        errdefer seg.deinit();

        self.unlinkStart();
        errdefer self.linkStart() catch @panic("Internal Error");

        try self.segment_list.insert(0, seg);
        errdefer _ = self.segment_list.orderedRemove(0);

        try self.link(0);
        errdefer self.unlink(0);

        try self.linkStart();
    }

    /// Inserts a new segment with the specified layout constraint after the
    /// last element in the segment list.
    ///
    /// If the layout constraint for the new segment cannot be satisfied, the
    /// function returns the `UnsatisfiableConstraint` error. This can occur if
    /// the segment is constrained to occupy a fraction of the layout that
    /// cannot be fulfilled — either because the fraction is invalid (e.g.,
    /// 2/1, 3/2, 5/3, etc.), or because the space required for that fraction
    /// is already occupied by other segments.
    pub fn append(self: *Layout, constraint: LayoutConstraint) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        return self.insert(self.segment_list.items.len - 1, constraint);
    }

    //

    /// Removes the segment at the specified index from the layout.
    pub fn remove(self: *Layout, index: usize) error{OutOfMemory}!void {
        std.debug.assert(index < self.segment_list.items.len - 1);
        if (index == 0)
            return self.popFront();
        self.unlink(index - 1);
        self.unlink(index);
        self.segment_list.orderedRemove(index).deinit();
        self.link(index - 1) catch |err| return handleInternalError(err);
    }

    /// Removes the first segment from the layout.
    pub fn popFront(self: *Layout) error{OutOfMemory}!void {
        self.unlinkStart();
        self.unlink(0);
        self.segment_list.orderedRemove(0).deinit();
        self.linkStart() catch |err| return handleInternalError(err);
    }

    //

    /// Changes the layout dimensions and origin to fit the given area.
    pub fn fit(self: *Layout, area: Area) error{OutOfMemory}!void {
        const length = switch (self.direction) {
            // zig fmt: off
            .horizontal => area.width,
            .vertical   => area.height,
            // zig fmt: on
        };
        try self.solver.suggestValue(self.length_variable, @floatFromInt(length));

        self.area = area;
    }

    /// Modifies the layout direction.
    pub fn redirect(self: *Layout, direction: LayoutDirection) error{OutOfMemory}!void {
        if (self.direction == direction) return;
        for (0..self.segment_list.items.len - 1) |i|
            self.unlink(i);
        self.direction = direction;
        const length = switch (self.direction) {
            // zig fmt: off
            .horizontal => self.area.width,
            .vertical   => self.area.height,
            // zig fmt: on
        };
        try self.solver.suggestValue(self.length_variable, @floatFromInt(length));
        for (0..self.segment_list.items.len - 1) |i|
            self.link(i) catch |err| return handleInternalError(err);
    }

    //

    /// Updates the segment areas to reflect the latest layout size and applied
    /// constraints.
    ///
    /// If the layout constraints cannot be satisfied, the function returns the
    /// `LayoutViolated` error.
    pub fn refresh(self: *Layout) error{ OutOfMemory, LayoutViolated }!void {
        self.solver.updateVariables();

        if (switch (self.direction) {
            // zig fmt: off
            .horizontal => @as(u16, @intFromFloat(@round(self.length_variable.value()))) != self.area.width,
            .vertical   => @as(u16, @intFromFloat(@round(self.length_variable.value()))) != self.area.height,
            // zig fmt: on
        }) return error.LayoutViolated;

        if (self.area_list.capacity != self.segment_list.items.len - 1)
            try self.area_list.resize(self.segment_list.items.len - 1);

        for (0..self.segment_list.items.len - 1) |i| {
            const curr = &self.segment_list.items[i];
            const next = &self.segment_list.items[i + 1];

            const start = @as(u16, @intFromFloat(@round(curr.variable.value())));
            const end = @as(u16, @intFromFloat(@round(next.variable.value())));
            const length = end - start;

            // zig fmt: off
            const width  = switch (self.direction) { .horizontal => length,                     .vertical => self.area.width };
            const height = switch (self.direction) { .horizontal => self.area.height,           .vertical => length };
            const x      = switch (self.direction) { .horizontal => start + self.area.origin.x, .vertical => self.area.origin.x };
            const y      = switch (self.direction) { .horizontal => self.area.origin.y,         .vertical => start + self.area.origin.y };
            // zig fmt: on

            self.area_list.items[i] = Area{
                .width = width,
                .height = height,
                .origin = .{ .x = x, .y = y },
            };
        }
    }

    //

    fn addSegmentConstraint(
        self: *Layout,
        left: fuiwi.Expression,
        right: fuiwi.Expression,
        relation: fuiwi.Relation,
        strength: f64,
        segments: []const u64,
    ) error{ OutOfMemory, UnsatisfiableConstraint }!*fuiwi.Constraint {
        const constraint = try self.allocator.create(fuiwi.Constraint);
        errdefer self.allocator.destroy(constraint);

        constraint.* = try fuiwi.Constraint.init(
            self.allocator,
            left,
            right,
            relation,
            strength,
        );
        errdefer constraint.deinit();

        var segment_list = try std.ArrayList(u64).initCapacity(self.allocator, segments.len);
        errdefer segment_list.deinit();
        for (segments) |seg| segment_list.append(seg) catch unreachable;

        try self.constraint_map.putNoClobber(constraint, segment_list);
        errdefer _ = self.constraint_map.swapRemove(constraint);

        try self.solver.addConstraint(constraint.*);

        return constraint;
    }

    fn removeSegmentConstraint(self: *Layout, constraint: *fuiwi.Constraint) void {
        // std.debug.assert(self.solver.hasConstraint(constraint));
        self.solver.removeConstraint(constraint.*);
        constraint.deinit();
        self.constraint_map.get(constraint).?.deinit();
        const res = self.constraint_map.swapRemove(constraint);
        std.debug.assert(res == true);
        self.allocator.destroy(constraint);
    }

    //

    fn linkStart(self: *Layout) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        if (self.segment_list.items.len == 1)
            return;

        const segment = &self.segment_list.items[0];

        self.expression[0].reset();
        self.expression[1].reset();

        try self.expression[0].addTerm(segment.variable, 1.0);
        try self.expression[1].addConstant(0.0);

        self.start_constraint = try fuiwi.Constraint.init(
            self.allocator,
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.eq,
            fuiwi.Strength.required,
        );
        errdefer {
            self.start_constraint.?.deinit();
            self.start_constraint = null;
        }

        try self.solver.addConstraint(self.start_constraint.?);
        errdefer self.solver.removeConstraint(self.start_constraint.?);
    }

    fn unlinkStart(self: *Layout) void {
        if (self.start_constraint) |start_constraint| {
            self.solver.removeConstraint(start_constraint);
            start_constraint.deinit();
        }
        self.start_constraint = null;
    }

    //

    fn link(self: *Layout, index: usize) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        // Make sure the given index is within the segment list.
        std.debug.assert(index < self.segment_list.items.len - 1);

        errdefer self.unlink(index);

        const curr = &self.segment_list.items[index];
        const next = &self.segment_list.items[index + 1];

        // curr >= 0
        //
        // Ensure that the variable is non-negative.

        self.expression[0].reset();
        self.expression[1].reset();

        try self.expression[0].addTerm(curr.variable, 1.0);
        try self.expression[1].addConstant(0.0);

        _ = try self.addSegmentConstraint(
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.geq,
            fuiwi.Strength.required,
            &[_]u64{curr.id},
        );

        // curr <= next
        //
        // Ensure the linked elements follow the correct sequence.

        self.expression[0].reset();
        self.expression[1].reset();

        try self.expression[0].addTerm(curr.variable, 1.0);
        try self.expression[1].addTerm(next.variable, 1.0);

        _ = try self.addSegmentConstraint(
            self.expression[0],
            self.expression[1],
            fuiwi.Relation.leq,
            fuiwi.Strength.required,
            &[_]u64{curr.id},
        );

        //

        switch (curr.objective) {
            .length => {
                // next - curr = length
                //
                // Ensure that the segment has the specified length.

                self.expression[0].reset();
                self.expression[1].reset();

                try self.expression[0].addTerm(next.variable, 1.0);
                try self.expression[0].addTerm(curr.variable, -1.0);

                try self.expression[1].addConstant(@floatFromInt(curr.objective.length));

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.eq,
                    fuiwi.Strength.required,
                    &[_]u64{curr.id},
                );
            },

            .fraction => {
                // zig fmt: off
                const fraction    = curr.objective.fraction;
                const numerator   = @as(f64, @floatFromInt(fraction.numerator));
                const denominator = @as(f64, @floatFromInt(fraction.denominator));
                // zig fmt: on

                // m * (next - curr) = n * length
                //
                // Ensure that the segment occupies the specified layout fraction.

                self.expression[0].reset();
                self.expression[1].reset();

                try self.expression[0].addTerm(next.variable, 1.0 * denominator);
                try self.expression[0].addTerm(curr.variable, -1.0 * denominator);

                try self.expression[1].addTerm(self.length_variable, 1.0 * numerator);

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.eq,
                    fuiwi.Strength.required,
                    &[_]u64{curr.id},
                );
            },

            .min => {
                // next - curr >= min
                //
                // Ensure that the segment occupies at least the specified minimum

                self.expression[0].reset();
                self.expression[1].reset();

                try self.expression[0].addTerm(next.variable, 1.0);
                try self.expression[0].addTerm(curr.variable, -1.0);

                try self.expression[1].addConstant(@floatFromInt(curr.objective.min));

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.geq,
                    fuiwi.Strength.required,
                    &[_]u64{curr.id},
                );

                // next - curr -> length
                //
                // Ensure that the segment grows towards the total size of the layout

                self.expression[1].reset();

                try self.expression[1].addTerm(self.length_variable, 1.0);

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.eq,
                    fuiwi.Strength.weak,
                    &[_]u64{curr.id},
                );
            },

            .max => {
                // next - curr <= max
                //
                // Ensure that the segment occupies at most the specified maximum

                self.expression[0].reset();
                self.expression[1].reset();

                try self.expression[0].addTerm(next.variable, 1.0);
                try self.expression[0].addTerm(curr.variable, -1.0);

                try self.expression[1].addConstant(@floatFromInt(curr.objective.max));

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.leq,
                    fuiwi.Strength.required,
                    &[_]u64{curr.id},
                );

                // next - curr -> max
                //
                // Ensure that the segment grows towards the specified maximum

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.eq,
                    fuiwi.Strength.medium,
                    &[_]u64{curr.id},
                );
            },

            .fill => {
                // next - curr -> (end - start)
                //
                // Ensure that the segment grows towards the total size of the layout

                self.expression[1].reset();

                try self.expression[0].addTerm(next.variable, 1.0);
                try self.expression[0].addTerm(curr.variable, -1.0);

                try self.expression[1].addTerm(self.length_variable, 1.0);

                _ = try self.addSegmentConstraint(
                    self.expression[0],
                    self.expression[1],
                    fuiwi.Relation.eq,
                    fuiwi.Strength.weak,
                    &[_]u64{curr.id},
                );
            },
        }

        // left-hand scaling factor
        const lhsf = @as(f64, @floatFromInt(switch (curr.objective) {
            .fill => curr.objective.fill,
            .min => 1,
            else => return,
        }));
        const lhcurr = curr; // current segment (left-hand)
        const lhnext = next; // next segment (left-hand)
        for (0..self.segment_list.items.len - 1) |i| {
            if (i == index) continue;
            const rhcurr = self.segment_list.items[i]; // current segment (right-hand)
            const rhnext = self.segment_list.items[i + 1]; // next segment (right-hand)
            // right-hand scaling factor
            const rhsf = @as(f64, @floatFromInt(switch (rhcurr.objective) {
                .fill => rhcurr.objective.fill,
                .min => 1,
                else => continue,
            }));

            self.expression[0].reset();
            self.expression[1].reset();

            // zig fmt: off
            try self.expression[0].addTerm(lhnext.variable,  1.0 * rhsf);
            try self.expression[0].addTerm(lhcurr.variable, -1.0 * rhsf);
            try self.expression[1].addTerm(rhnext.variable,  1.0 * lhsf);
            try self.expression[1].addTerm(rhcurr.variable, -1.0 * lhsf);
            // zig fmt: on

            _ = try self.addSegmentConstraint(
                self.expression[0],
                self.expression[1],
                fuiwi.Relation.eq,
                fuiwi.Strength.required,
                &[_]u64{ lhcurr.id, rhcurr.id },
            );
        }
    }

    fn unlink(self: *Layout, index: usize) void {
        // Make sure the given index is within the segment list.
        std.debug.assert(index < self.segment_list.items.len - 1);

        const seg = &self.segment_list.items[index];

        var iterator = self.constraint_map.iterator();
        while (iterator.next()) |it| {
            const constraint = it.key_ptr.*;
            const segment_list = it.value_ptr;

            for (segment_list.items) |segment_id| {
                if (segment_id != seg.id) continue;
                self.removeSegmentConstraint(constraint);
                iterator.len -= 1;
                iterator.index -= 1;
                break;
            }
        }
    }

    //

    inline fn handleInternalError(err: anyerror) error{OutOfMemory} {
        switch (err) {
            // zig fmt: off
            error.OutOfMemory             => return error.OutOfMemory,
            error.UnsatisfiableConstraint => @panic("Unsatisfiable Constraint"),
            else                          => unreachable,
            // zig fmt: on
        }
    }

    //

    const Segment = struct {
        id: u64,
        objective: LayoutConstraint,
        variable: fuiwi.Variable,

        pub fn init(
            allocator: std.mem.Allocator,
            objective: LayoutConstraint,
        ) std.mem.Allocator.Error!Segment {
            var self: Segment = undefined;
            self.objective = objective;
            self.variable = try fuiwi.Variable.init(allocator);
            self.id = @intFromPtr(self.variable.ptr);
            return self;
        }

        pub fn deinit(self: Segment) void {
            self.variable.deinit();
        }
    };

    const ConstraintMap = std.AutoArrayHashMap(
        *fuiwi.Constraint,
        std.ArrayList(u64),
    );
};

/// Represents different types of layout constraints used to control the size
/// or position of layout elements relative to their container or siblings.
/// The exact behavior depends on the active variant.
pub const LayoutConstraint = union(enum) {
    /// Applies a length constraint to a layout segment.
    ///
    /// The layout segment is guaranteed to occupy exactly the specified length
    /// unless other required layout constraints are violated.
    length: u16,

    /// Applies a fraction of the total container dimension to a layout
    /// segment.
    ///
    /// The layout segment is guaranteed to occupy exactly the specified fraction of the
    /// container dimension unless other required layout constraints are violated.
    fraction: struct { numerator: u16, denominator: u16 },

    /// Applies a minimum size constraint to a layout segment.
    ///
    /// The segment is guaranteed to occupy at least the specified minimum length,
    /// unless other layout constraints are violated. Similar to the `fill`
    /// constraint, it will occupy the remaining space in the container
    /// dimension after ensuring the minimum size is met.
    min: u16,

    /// Applies a maximum size constraint to a layout segment.
    ///
    /// The segment is guaranteed to occupy at most the specified minimum length,
    /// unless other layout constraints are violated. Similar to the `fill`
    /// constraint, it will occupy the remaining space in the container
    /// dimension after ensuring the maximum size is met.
    max: u16,

    /// Applies a scaling factor proportional to all other `fill` constraints
    /// to fill the excess space in the container dimension.
    fill: u16,
};

/// ...
pub const LayoutDirection = enum {
    horizontal,
    vertical,
};

//
// Tests
//

fn letters(
    allocator: std.mem.Allocator,
    segments: []const Area,
    direction: LayoutDirection,
) std.mem.Allocator.Error![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var letter: u8 = 'a';

    for (segments) |segment| {
        const length = switch (direction) {
            // zig fmt: off
            .horizontal => segment.width,
            .vertical   => segment.height,
            // zig fmt: on
        };

        for (0..length) |_|
            try out.append(letter);

        letter += 1;
    }

    return try out.toOwnedSlice();
}

test "memory errors" {
    const TestCase = struct {
        const Self = @This();

        direction: LayoutDirection,

        fn test_memory(allocator: std.mem.Allocator, direction: LayoutDirection) !void {
            var layout = try Layout.init(allocator, direction);
            defer layout.deinit();

            // 1/5 -> min5 -> max10 -> 50 -> fill10
            try layout.append(.{ .length = 50 });
            try layout.prepend(.{ .min = 5 });
            try layout.insert(1, .{ .max = 10 });
            try layout.append(.{ .fill = 1 });
            try layout.prepend(.{ .fraction = .{ .numerator = 1, .denominator = 5 } });

            try layout.fit(.{ .width = 100, .height = 100, .origin = .{ .x = 5, .y = 9 } });
            try layout.refresh();

            try layout.redirect(if (direction == .horizontal) .vertical else .horizontal);
            try layout.refresh();

            try layout.remove(0);
            try layout.remove(2);
            try layout.remove(2);
            try layout.remove(1);
            try layout.remove(0);

            try layout.refresh();
        }

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    try Self.test_memory(std.testing.allocator, self.direction);
                    // try std.testing.checkAllAllocationFailures(
                    //     std.testing.allocator,
                    //     Self.test_memory,
                    //     .{self.direction},
                    // );
                }
            };
        }
    };

    inline for ([_]TestCase{
        .{ .direction = .horizontal },
        .{ .direction = .vertical },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "static layout" {
    const TestCase = struct {
        const Self = @This();

        id: usize = undefined,
        constraints: []const LayoutConstraint,
        expected: []const u8,

        fn test_fn(self: Self) type {
            return struct {
                test "horizontal" {
                    var layout = try Layout.init(std.testing.allocator, .horizontal);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    const actual = try letters(std.testing.allocator, layout.areas(), .horizontal);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(self.expected, actual);
                }

                test "from horizontal to vertical" {
                    var layout = try Layout.init(std.testing.allocator, .horizontal);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });
                    try layout.redirect(.vertical);
                    try layout.refresh();

                    const actual = try letters(std.testing.allocator, layout.areas(), .vertical);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(self.expected, actual);
                }

                test "vertical" {
                    var layout = try Layout.init(std.testing.allocator, .vertical);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    const actual = try letters(std.testing.allocator, layout.areas(), .vertical);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(self.expected, actual);
                }

                test "from vertical to horizontal" {
                    var layout = try Layout.init(std.testing.allocator, .vertical);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });
                    try layout.redirect(.horizontal);
                    try layout.refresh();

                    const actual = try letters(std.testing.allocator, layout.areas(), .horizontal);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(self.expected, actual);
                }
            };
        }
    };

    inline for ([_]TestCase{
        TestCase{
            .id = 0,
            .constraints = &.{
                .{ .length = 1 },
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
            },
            .expected = "abbbbbbb",
        },
        TestCase{
            .id = 1,
            .constraints = &.{
                .{ .length = 2 },
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
            },
            .expected = "aabbbbbbb",
        },
        TestCase{
            .id = 2,
            .constraints = &.{
                .{ .length = 3 },
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
            },
            .expected = "aaabbbbbbb",
        },
        TestCase{
            .id = 3,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
                .{ .length = 1 },
            },
            .expected = "aaaaaaab",
        },
        TestCase{
            .id = 4,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
                .{ .length = 2 },
            },
            .expected = "aaaaaaabb",
        },
        TestCase{
            .id = 5,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 2, .denominator = 3 } },
                .{ .length = 3 },
            },
            .expected = "aaaaaaabbb",
        },
        TestCase{
            .id = 6,
            .constraints = &.{
                .{ .fill = 1 },
                .{ .fill = 2 },
                .{ .fill = 3 },
            },
            .expected = "aabbbccccc",
        },
        TestCase{
            .id = 7,
            .constraints = &.{
                .{ .fill = 2 },
                .{ .fill = 1 },
                .{ .fill = 3 },
            },
            .expected = "aaabbccccc",
        },
        TestCase{
            .id = 8,
            .constraints = &.{
                .{ .fill = 2 },
                .{ .fill = 3 },
                .{ .fill = 1 },
            },
            .expected = "aaabbbbbcc",
        },
        TestCase{
            .id = 9,
            .constraints = &.{
                .{ .fill = 3 },
                .{ .fill = 2 },
                .{ .fill = 1 },
            },
            .expected = "aaaaabbbcc",
        },
        TestCase{
            .id = 10,
            .constraints = &.{
                .{ .fill = 1 },
                .{ .min = 5 },
            },
            .expected = "aaaaabbbbb",
        },
        TestCase{
            .id = 11,
            .constraints = &.{
                .{ .min = 3 },
                .{ .fill = 2 },
            },
            .expected = "aaabbbbbbb",
        },
        TestCase{
            .id = 12,
            .constraints = &.{
                .{ .min = 3 },
                .{ .fill = 2 },
            },
            .expected = "aaabbbbbbb",
        },
        TestCase{
            .id = 13,
            .constraints = &.{
                .{ .min = 4 },
                .{ .max = 8 },
            },
            .expected = "aaaabbbbbb",
        },
        TestCase{
            .id = 14,
            .constraints = &.{
                .{ .fill = 1 },
                .{ .fraction = .{ .numerator = 1, .denominator = 2 } },
                .{ .fill = 1 },
            },
            .expected = "aaabbbbbcc",
        },
        TestCase{
            .id = 15,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 1, .denominator = 1 } },
            },
            .expected = "aaaaaaaaaa",
        },
        TestCase{
            .id = 15,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 1, .denominator = 1 } },
                .{ .max = 10000 },
            },
            .expected = "aaaaaaaaaa",
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "prepend() should add a new segment at the beginning" {
    const TestCase = struct {
        const Self = @This();

        direction: LayoutDirection,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    var layout = try Layout.init(std.testing.allocator, self.direction);
                    defer layout.deinit();

                    try layout.append(.{ .length = 5 });
                    try layout.prepend(.{ .fill = 1 });
                    try layout.prepend(.{ .fill = 2 });

                    try layout.fit(.{ .width = 14, .height = 14, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    const expected = "aaaaaabbbccccc";
                    const actual = try letters(std.testing.allocator, layout.areas(), self.direction);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(expected, actual);
                }
            };
        }
    };

    inline for ([_]LayoutDirection{
        .horizontal,
        .vertical,
    }) |direction| {
        _ = (TestCase{ .direction = direction }).test_fn();
    }
}

test "insert() should add a new segment at the specified position" {
    const TestCase = struct {
        const Self = @This();

        direction: LayoutDirection,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    var layout = try Layout.init(std.testing.allocator, self.direction);
                    defer layout.deinit();

                    try layout.append(.{ .length = 4 });
                    try layout.append(.{ .max = 4 });
                    try layout.append(.{ .min = 2 });
                    try layout.insert(1, .{ .fill = 2 });

                    try layout.fit(.{ .width = 14, .height = 14, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    const expected = "aaaabbbbccccdd";
                    const actual = try letters(std.testing.allocator, layout.areas(), self.direction);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(expected, actual);
                }
            };
        }
    };

    inline for ([_]LayoutDirection{
        .horizontal,
        .vertical,
    }) |direction| {
        _ = (TestCase{ .direction = direction }).test_fn();
    }
}

test "remove() should remove the segment at the specified position" {
    const TestCase = struct {
        const Self = @This();

        direction: LayoutDirection,

        pub fn test_fn(self: Self) type {
            return struct {
                test {
                    var layout = try Layout.init(std.testing.allocator, self.direction);
                    defer layout.deinit();

                    try layout.append(.{ .length = 5 });
                    try layout.append(.{ .fill = 1 });
                    try layout.append(.{ .fill = 2 });

                    try layout.remove(1);

                    try layout.fit(.{ .width = 14, .height = 14, .origin = .{ .x = 0, .y = 0 } });
                    try layout.refresh();

                    const expected = "aaaaabbbbbbbbb";
                    const actual = try letters(std.testing.allocator, layout.areas(), self.direction);
                    defer std.testing.allocator.free(actual);

                    try std.testing.expectEqualStrings(expected, actual);
                }
            };
        }
    };

    inline for ([_]LayoutDirection{
        .horizontal,
        .vertical,
    }) |direction| {
        _ = (TestCase{ .direction = direction }).test_fn();
    }
}

test "should fail due to an improper set constraints" {
    const TestCase = struct {
        const Self = @This();

        id: usize,
        constraints: []const LayoutConstraint,

        pub fn test_fn(self: Self) type {
            return struct {
                test "horizontal" {
                    var layout = try Layout.init(std.testing.allocator, .horizontal);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());
                }

                test "from horizontal to vertical" {
                    var layout = try Layout.init(std.testing.allocator, .horizontal);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });
                    try layout.redirect(.vertical);

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());
                }

                test "vertical" {
                    var layout = try Layout.init(std.testing.allocator, .vertical);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());
                }

                test "from vertical to horizontal" {
                    var layout = try Layout.init(std.testing.allocator, .vertical);
                    defer layout.deinit();

                    for (self.constraints) |constraint|
                        try layout.append(constraint);

                    try layout.fit(.{ .width = 0, .height = 10, .origin = .{ .x = 0, .y = 0 } });

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());

                    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });
                    try layout.redirect(.horizontal);

                    try std.testing.expectEqual(error.LayoutViolated, layout.refresh());
                }
            };
        }
    };

    inline for ([_]TestCase{
        TestCase{
            .id = 0,
            .constraints = &.{
                .{ .length = 15 },
            },
        },
        TestCase{
            .id = 1,
            .constraints = &.{
                .{ .length = 10 },
                .{ .length = 1 },
            },
        },
        TestCase{
            .id = 2,
            .constraints = &.{
                .{ .min = 15 },
            },
        },
        TestCase{
            .id = 3,
            .constraints = &.{
                .{ .length = 10 },
                .{ .min = 1 },
            },
        },
        TestCase{
            .id = 4,
            .constraints = &.{
                .{ .min = 10 },
                .{ .length = 1 },
            },
        },
        TestCase{
            .id = 5,
            .constraints = &.{
                .{ .min = 10 },
                .{ .length = 30 },
                .{ .min = 50 },
            },
        },
        TestCase{
            .id = 5,
            .constraints = &.{
                .{ .fraction = .{ .numerator = 59, .denominator = 15 } },
            },
        },
    }) |test_case| {
        _ = test_case.test_fn();
    }
}

test "should fail due to improper fraction" {
    var layout = try Layout.init(std.testing.allocator, .horizontal);
    defer layout.deinit();

    try layout.append(.{ .length = 1 });
    try layout.append(.{ .fraction = .{ .numerator = 1, .denominator = 2 } });

    try std.testing.expectEqual(
        error.UnsatisfiableConstraint,
        layout.append(.{ .fraction = .{ .numerator = 1, .denominator = 2 } }),
    );
}

test "should recover from an unsatisfiable constraint" {
    var layout = try Layout.init(std.testing.allocator, .horizontal);
    defer layout.deinit();

    try layout.append(.{ .length = 1 });
    try layout.append(.{ .fraction = .{ .numerator = 1, .denominator = 2 } });

    try std.testing.expectEqual(
        error.UnsatisfiableConstraint,
        layout.prepend(.{ .fraction = .{ .numerator = 1, .denominator = 2 } }),
    );

    try std.testing.expectEqual(
        error.UnsatisfiableConstraint,
        layout.append(.{ .fraction = .{ .numerator = 1, .denominator = 2 } }),
    );

    try layout.prepend(.{ .fill = 1 });

    try layout.fit(.{ .width = 10, .height = 0, .origin = .{ .x = 0, .y = 0 } });
    try layout.refresh();

    const expected = "aaaabccccc";
    const actual = try letters(std.testing.allocator, layout.areas(), .horizontal);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
