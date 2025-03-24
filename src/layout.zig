const std = @import("std");
const fuiwi = @import("fuiwi.zig");
const fuizon = @import("fuizon.zig");

const Solver = fuiwi.Solver;
const Variable = fuiwi.Variable;
const Expression = fuiwi.Expression;
const Constraint = fuiwi.Constraint;
const Term = fuiwi.Term;
const term = fuiwi.term;
const Relation = fuiwi.Relation;
const Strength = fuiwi.Strength;

// Precision for the rounding of f64 to u16 in layout calculations.
const FLOAT_PRECISION_MULTIPLIER: f64 = 100.0;

// ---

pub const Coordinate = struct { x: u16, y: u16 };

// ---

const Context = struct {
    solver: Solver,

    /// Indicates whether the solver variables reflect the latest layout
    /// changes.
    synced: bool = false,

    fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!Context {
        return .{
            .solver = try Solver.init(allocator),
            .synced = false,
        };
    }

    fn deinit(self: Context) void {
        self.solver.deinit();
    }

    /// Makes sure the solver variables actually reflect the latest layout
    /// changes. If they already do, this function does nothing.
    fn sync(self: *Context) void {
        if (!self.synced) {
            self.solver.updateVariables();
            self.synced = true;
        }
    }
};

// ---

/// Represents a rectangular area.
pub const Area = struct {
    width: u16,
    height: u16,
    origin: Coordinate,

    /// Returns the topmost coordinate of the area.
    pub fn top(self: Area) u16 {
        return self.origin.y;
    }

    test "top() should return the topmost coordinate" {
        try std.testing.expectEqual(5, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).top());
    }

    /// Returns the bottommost coordinate of the area.
    pub fn bottom(self: Area) u16 {
        return self.height + self.origin.y;
    }

    test "bottom() should return the bottommost coordinate" {
        try std.testing.expectEqual(14, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).bottom());
    }

    /// Returns the leftmost coordinate of the area.
    pub fn left(self: Area) u16 {
        return self.origin.x;
    }

    test "left() should return the leftmost coordinate" {
        try std.testing.expectEqual(1, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).left());
    }

    /// Returns the rightmost coordinate of the area.
    pub fn right(self: Area) u16 {
        return self.width + self.origin.x;
    }

    test "right() should return the rightmost coordinate" {
        try std.testing.expectEqual(6, (Area{
            .width = 5,
            .height = 9,
            .origin = .{ .x = 1, .y = 5 },
        }).right());
    }
};

// ---

/// Represents a rectangular area under dynamic constraints.
pub const Item = struct {
    /// Layout context.
    context: *Context,

    /// Strength of the layout item.
    strength: f64,

    // ---

    /// Indicates whether values can be suggested for the width variable.
    width_edit: bool,

    /// Width of the item.
    width_var: Variable,

    /// Minimal width of the item.
    min_width_var: Variable,

    /// Maximal width of the item.
    max_width_var: Variable,

    // ---

    /// Indicates whether values can be suggested for the height variable.
    height_edit: bool,

    /// Height of the item.
    height_var: Variable,

    /// Minimal height of the item.
    min_height_var: Variable,

    /// Maximal height of the item.
    max_height_var: Variable,

    // ---

    /// Indicates whether values can be suggested for the coordinate of the
    /// item's upper and left boundaries.
    origin_edit: bool,

    /// Coordinate of the item's upper boundary.
    top_var: Variable,

    /// Coordinate of the item's lower boundary.
    bottom_var: Variable,

    /// Coordinate of the item's left boundary.
    left_var: Variable,

    /// Coordinate of the item's right boundary.
    right_var: Variable,

    // ---

    /// Initializes a new layout item with the given strength and adds it to
    /// the provided context.
    fn init(allocator: std.mem.Allocator, context: *Context, strength: f32) std.mem.Allocator.Error!Item {
        var item: Item = undefined;

        item.context = context;
        item.strength = strength;

        // ---

        item.width_edit = false;
        item.width_var = try Variable.init(allocator);
        errdefer item.width_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.width_var);

        item.min_width_var = try Variable.init(allocator);
        errdefer item.min_width_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.min_width_var);
        try item.context.solver.addVariable(item.min_width_var, item.strength);

        item.max_width_var = try Variable.init(allocator);
        errdefer item.max_width_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.max_width_var);
        try item.context.solver.addVariable(item.max_width_var, item.strength);
        try item.suggestMaxWidth(null);

        // ---

        item.height_edit = false;
        item.height_var = try Variable.init(allocator);
        errdefer item.height_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.height_var);

        item.min_height_var = try Variable.init(allocator);
        errdefer item.min_height_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.min_height_var);
        try item.context.solver.addVariable(item.min_height_var, item.strength);

        item.max_height_var = try Variable.init(allocator);
        errdefer item.max_height_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.max_width_var);
        try item.context.solver.addVariable(item.max_height_var, item.strength);
        try item.suggestMaxHeight(null);

        // ---

        item.origin_edit = false;

        item.top_var = try Variable.init(allocator);
        errdefer item.top_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.top_var);

        item.bottom_var = try Variable.init(allocator);
        errdefer item.bottom_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.bottom_var);

        item.left_var = try Variable.init(allocator);
        errdefer item.left_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.left_var);

        item.right_var = try Variable.init(allocator);
        errdefer item.right_var.deinit();
        try restrictToUnsigned16(allocator, &item.context.solver, item.right_var);

        // ---

        // right == width + left
        //
        // ...
        const width_constraint = try Constraint.init(
            allocator,
            .{ item.right_var, Relation.eq, item.width_var, item.left_var },
            Strength.required,
        );
        defer width_constraint.deinit();

        item.context.solver.addConstraint(width_constraint) catch |err| return OOM(err);

        // width >= min_width
        //
        // Restricts the width of the item to be greater or equal to the minimum
        // width.
        const min_width_constraint = try Constraint.init(
            allocator,
            .{ item.width_var, Relation.geq, item.min_width_var },
            Strength.required,
        );
        defer min_width_constraint.deinit();

        item.context.solver.addConstraint(min_width_constraint) catch |err| return OOM(err);

        // width <= max_width
        //
        // Restricts the width of the item to be less or equal to the maximum
        // width.
        const max_width_constraint = try Constraint.init(
            allocator,
            .{ item.width_var, Relation.leq, item.max_width_var },
            strength,
        );
        defer max_width_constraint.deinit();

        item.context.solver.addConstraint(max_width_constraint) catch |err| return OOM(err);

        // ---

        // bottom == height + top
        //
        // ...
        const height_constraint = try Constraint.init(
            allocator,
            .{ item.bottom_var, Relation.eq, item.height_var, item.top_var },
            Strength.required,
        );
        defer height_constraint.deinit();

        item.context.solver.addConstraint(height_constraint) catch |err| return OOM(err);

        // height >= min_height
        //
        // Restricts the height of the item to be greater or equal to the minimum
        // height.
        const min_height_constraint = try Constraint.init(
            allocator,
            .{ item.height_var, Relation.geq, item.min_height_var },
            Strength.required,
        );
        defer min_height_constraint.deinit();

        item.context.solver.addConstraint(min_height_constraint) catch |err| return OOM(err);

        // height <= max_height
        //
        // Restricts the height of the item to be less or equal to the maximum
        // height.
        const max_height_constraint = try Constraint.init(
            allocator,
            .{ item.height_var, Relation.leq, item.max_height_var },
            Strength.required,
        );
        defer max_height_constraint.deinit();

        item.context.solver.addConstraint(max_height_constraint) catch |err| return OOM(err);

        // ---

        return item;
    }

    /// Deinitializes the layout item and removes it from the solver.
    fn deinit(self: Item) void {
        self.top_var.deinit();
        self.bottom_var.deinit();
        self.left_var.deinit();
        self.right_var.deinit();

        self.width_var.deinit();
        self.min_width_var.deinit();
        self.max_width_var.deinit();

        self.height_var.deinit();
        self.min_height_var.deinit();
        self.max_height_var.deinit();
    }

    // ---

    /// Allows the solver to determine the optimal width value.
    pub fn optimizeWidth(self: *Item) void {
        if (!self.width_edit) return;
        self.context.synced = false;
        self.context.solver.removeVariable(self.width_var);
        self.width_edit = false;
    }

    /// Suggests a value for the width of the item.
    pub fn suggestWidth(self: *Item, value: u16) error{OutOfMemory}!void {
        self.context.synced = false;
        if (!self.width_edit) {
            try self.context.solver.addVariable(self.width_var, self.strength);
            self.width_edit = true;
        }
        try self.context.solver.suggestValue(
            self.width_var,
            @as(f64, @floatFromInt(value)) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Suggests a value for the minimum width of the item.
    pub fn suggestMinWidth(self: *Item, value: u16) error{OutOfMemory}!void {
        self.context.synced = false;
        return self.context.solver.suggestValue(
            self.min_width_var,
            @as(f64, @floatFromInt(value)) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Suggests a value for the maximum width of the item. If no value is
    /// provided, the previous maximum width constraint will be removed.
    pub fn suggestMaxWidth(self: *Item, value: ?u16) error{OutOfMemory}!void {
        self.context.synced = false;
        return self.context.solver.suggestValue(
            self.max_width_var,
            @as(f64, @floatFromInt(value orelse std.math.maxInt(u16))) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Allows the solver to determine the optimal height value.
    pub fn optimizeHeight(self: *Item) void {
        if (!self.height_edit) return;
        self.context.synced = false;
        self.context.solver.removeVariable(self.height_var);
        self.height_edit = false;
    }

    /// Suggests a value for the height of the item.
    pub fn suggestHeight(self: *Item, value: u16) error{OutOfMemory}!void {
        self.context.synced = false;
        if (!self.height_edit) {
            try self.context.solver.addVariable(self.height_var, self.strength);
            self.height_edit = true;
        }
        try self.context.solver.suggestValue(
            self.height_var,
            @as(f64, @floatFromInt(value)) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Suggests a value for the minimum height of the item.
    pub fn suggestMinHeight(self: *Item, value: u16) error{OutOfMemory}!void {
        self.context.synced = false;
        return self.context.solver.suggestValue(
            self.min_height_var,
            @as(f64, @floatFromInt(value)) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Suggests a value for the maximum height of the item. If no value is
    /// provided, the previous maximum height constraint will be removed.
    pub fn suggestMaxHeight(self: *Item, value: ?u16) error{OutOfMemory}!void {
        self.context.synced = false;
        return self.context.solver.suggestValue(
            self.max_height_var,
            @as(f64, @floatFromInt(value orelse std.math.maxInt(u16))) * FLOAT_PRECISION_MULTIPLIER,
        );
    }

    /// Allows the solver to determine the optimal coordinates for the item's
    /// upper and left boundaries.
    fn optimizeOrigin(self: *Item) void {
        if (!self.origin_edit) return;
        self.context.synced = false;
        self.context.solver.removeVariable(self.top_var);
        self.context.solver.removeVariable(self.left_var);
        self.origin_edit = false;
    }

    /// Suggests coordinates for the item's origin.
    fn suggestOrigin(self: *Item, x: u16, y: u16) error{OutOfMemory}!void {
        self.context.synced = false;

        if (!self.origin_edit) {
            try self.context.solver.addVariable(self.top_var, self.strength);
            errdefer self.context.solver.removeVariable(self.top_var);
            try self.context.solver.addVariable(self.left_var, self.strength);
            errdefer self.context.solver.removeVariable(self.left_var);

            self.origin_edit = true;
        }

        // zig fmt: off
        try self.context.solver.suggestValue(self.top_var,  @as(f64, @floatFromInt(y)) * FLOAT_PRECISION_MULTIPLIER);
        try self.context.solver.suggestValue(self.left_var, @as(f64, @floatFromInt(x)) * FLOAT_PRECISION_MULTIPLIER);
        // zig fmt: on
    }

    /// Returns the width of the item.
    pub fn width(self: Item) u16 {
        self.context.sync();
        return self.right() - self.left();
    }

    test "width() after suggestWidth()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(1559);

        try std.testing.expectEqual(1559, item.width());
    }

    test "width() after suggestMinWidth()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestMinWidth(1559);

        try std.testing.expect(item.width() >= 1559);
    }

    /// Returns the height of the item.
    pub fn height(self: Item) u16 {
        self.context.sync();
        return self.bottom() - self.top();
    }

    test "height() after suggestHeight()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestHeight(1559);

        try std.testing.expectEqual(1559, item.height());
    }

    test "height() after suggestMinHeight()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestMinHeight(1559);

        try std.testing.expect(item.height() >= 1559);
    }

    /// Returns the topmost coordinate of the item.
    pub fn top(self: Item) u16 {
        self.context.sync();
        return @intFromFloat(@round(@round(self.top_var.value()) / FLOAT_PRECISION_MULTIPLIER));
    }

    test "top()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(15);
        try item.suggestHeight(59);
        try item.suggestOrigin(59, 15);

        try std.testing.expectEqual(15, item.top());
    }

    /// Returns the bottommost coordinate of the item.
    pub fn bottom(self: Item) u16 {
        self.context.sync();
        return @intFromFloat(@round(@round(self.bottom_var.value()) / FLOAT_PRECISION_MULTIPLIER));
    }

    test "bottom()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(15);
        try item.suggestHeight(59);
        try item.suggestOrigin(59, 15);

        try std.testing.expectEqual(74, item.bottom());
    }

    /// Returns the leftmost coordinate of the item.
    pub fn left(self: Item) u16 {
        self.context.sync();
        return @intFromFloat(@round(@round(self.left_var.value()) / FLOAT_PRECISION_MULTIPLIER));
    }

    test "left()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(15);
        try item.suggestHeight(59);
        try item.suggestOrigin(59, 15);

        try std.testing.expectEqual(59, item.left());
    }

    /// Returns the rightmost coordinate of the item.
    pub fn right(self: Item) u16 {
        self.context.sync();
        return @intFromFloat(@round(@round(self.right_var.value()) / FLOAT_PRECISION_MULTIPLIER));
    }

    test "right()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(15);
        try item.suggestHeight(59);
        try item.suggestOrigin(59, 15);

        try std.testing.expectEqual(74, item.right());
    }

    /// Returns the area that the item occupies.
    pub fn area(self: Item) Area {
        self.context.sync();
        return Area{
            .width = self.width(),
            .height = self.height(),
            .origin = .{
                .x = self.left(),
                .y = self.top(),
            },
        };
    }

    test "area()" {
        var context = try Context.init(std.testing.allocator);
        defer context.deinit();

        var item = try Item.init(std.testing.allocator, &context, Strength.strong);
        defer item.deinit();

        try item.suggestWidth(15);
        try item.suggestHeight(59);
        try item.suggestOrigin(59, 15);

        const item_area = item.area();

        try std.testing.expectEqual(15, item_area.width);
        try std.testing.expectEqual(59, item_area.height);
        try std.testing.expectEqual(15, item_area.top());
        try std.testing.expectEqual(59, item_area.left());
        try std.testing.expectEqual(74, item_area.bottom());
        try std.testing.expectEqual(74, item_area.right());
    }

    // ---

    fn start(self: Item, direction: Direction) Variable {
        return switch (direction) {
            .vertical => self.top_var,
            .horizontal => self.left_var,
        };
    }

    fn length(self: Item, direction: Direction) Variable {
        return switch (direction) {
            .vertical => self.height_var,
            .horizontal => self.width_var,
        };
    }
};

/// Stack layout.
///
/// Lines up areas vertically or horizontally.
pub const Stack = struct {
    /// The underlying memory allocator.
    allocator: std.mem.Allocator,

    /// Direction of the layout.
    direction: Direction,

    /// Represents the area occupied by the layout.
    root: Item,

    /// List of items in the layout.
    items: []Item,

    /// Initializes a new vertical stack layout.
    pub fn vertical(
        allocator: std.mem.Allocator,
        constraints: []const StackConstraint,
    ) std.mem.Allocator.Error!Stack {
        return Stack.init(allocator, .vertical, constraints);
    }

    /// Initializes a new horizontal stack layout.
    pub fn horizontal(
        allocator: std.mem.Allocator,
        constraints: []const StackConstraint,
    ) std.mem.Allocator.Error!Stack {
        return Stack.init(allocator, .horizontal, constraints);
    }

    /// Initializes a new stack layout.
    pub fn init(
        allocator: std.mem.Allocator,
        direction: Direction,
        constraints: []const StackConstraint,
    ) std.mem.Allocator.Error!Stack {
        var stack: Stack = undefined;

        stack.allocator = allocator;
        stack.direction = direction;

        const context = try stack.allocator.create(Context);
        errdefer stack.allocator.destroy(context);
        context.* = try Context.init(allocator);
        errdefer context.deinit();

        stack.root = try Item.init(stack.allocator, context, Strength.create(5.0, 0.0, 0.0));
        errdefer stack.root.deinit();

        var nitems: usize = 0;
        stack.items = try stack.allocator.alloc(Item, constraints.len);
        errdefer stack.allocator.free(stack.items);
        errdefer for (stack.items[0..nitems]) |item|
            item.deinit();
        for (stack.items) |*item| {
            item.* = try Item.init(allocator, stack.root.context, Strength.medium);
            nitems += 1;
        }
        std.debug.assert(nitems == stack.items.len and nitems == constraints.len);

        try stack.configureItems(constraints);

        return stack;
    }

    /// Deinitializes the stack layout.
    pub fn deinit(self: Stack) void {
        self.root.context.deinit();
        self.allocator.destroy(self.root.context);
        for (self.items) |item|
            item.deinit();
        self.allocator.free(self.items);
        self.root.deinit();
    }

    // ---

    /// Returns the width of the layout.
    pub fn width(self: Stack) u16 {
        return self.root.width();
    }

    /// Allows the solver to determine the optimal width value.
    pub fn optimizeWidth(self: *Stack) void {
        return self.root.optimizeWidth();
    }

    /// Modifies the layout to fit the given width.
    pub fn setWidth(self: *Stack, value: u16) std.mem.Allocator.Error!void {
        return self.root.suggestWidth(value);
    }

    /// Modifies the layout to fit the minimum width.
    pub fn setMinWidth(self: *Stack, value: u16) std.mem.Allocator.Error!void {
        return self.root.suggestMinWidth(value);
    }

    /// Modifies the layout to fit the maximum width.
    pub fn setMaxWidth(self: *Stack, value: ?u16) std.mem.Allocator.Error!void {
        return self.root.suggestMaxWidth(value);
    }

    /// Returns the height of the layout.
    pub fn height(self: Stack) u16 {
        return self.root.height();
    }

    /// Allows the solver to determine the optimal height value.
    pub fn optimizeHeight(self: *Stack) void {
        return self.root.optimizeHeight();
    }

    /// Modifies the layout to fit the given height.
    pub fn setHeight(self: *Stack, value: u16) std.mem.Allocator.Error!void {
        return self.root.suggestHeight(value);
    }

    /// Modifies the layout to fit the minimum height.
    pub fn setMinHeight(self: *Stack, value: u16) std.mem.Allocator.Error!void {
        return self.root.suggestMinHeight(value);
    }

    /// Modifies the layout to fit the maximum height.
    pub fn setMaxHeight(self: *Stack, value: ?u16) std.mem.Allocator.Error!void {
        return self.root.suggestMaxHeight(value);
    }

    // ---

    /// Returns the topmost coordinate of the layout.
    pub fn top(self: Stack) u16 {
        return self.root.top();
    }

    /// Returns the bottommost coordinate of the layout.
    pub fn bottom(self: Stack) u16 {
        return self.root.bottom();
    }

    /// Returns the leftmost coordinate of the layout.
    pub fn left(self: Stack) u16 {
        return self.root.left();
    }

    /// Returns the rightmost coordinate of the layout.
    pub fn right(self: Stack) u16 {
        return self.root.right();
    }

    /// Moves the layout's origin to the provided coordinates.
    pub fn setOrigin(self: *Stack, x: u16, y: u16) std.mem.Allocator.Error!void {
        return self.root.suggestOrigin(x, y);
    }

    // ---

    /// Returns the area of the layout.
    pub fn area(self: Stack) Area {
        var ret: Area = undefined;
        ret.width = self.width();
        ret.height = self.height();
        ret.origin.x = self.left();
        ret.origin.y = self.top();
        return ret;
    }

    /// Modifies the layout to fit the given area.
    pub fn fit(self: *Stack, target: Area) std.mem.Allocator.Error!void {
        try self.setMinWidth(0);
        try self.setMaxWidth(null);
        try self.setWidth(target.width);
        try self.setMinHeight(0);
        try self.setMaxHeight(null);
        try self.setHeight(target.height);
        try self.setOrigin(target.origin.x, target.origin.y);
    }

    // ---

    /// Configures the layout items in `self.items`.
    fn configureItems(
        self: *Stack,
        constraints: []const StackConstraint,
    ) std.mem.Allocator.Error!void {
        if (self.items.len > 0) {
            // zig fmt: off
            const item_start = self.items[0].start(self.direction);
            const root_start = self.root.start(self.direction);
            // zig fmt: on

            const solver_constraint = try Constraint.init(
                self.allocator,
                .{ item_start, Relation.eq, root_start },
                Strength.required,
            );
            defer solver_constraint.deinit();
            self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
        }

        for (self.items) |item| {
            // zig fmt: off
            const item_start = item.start(self.direction.invert());
            const root_start = self.root.start(self.direction.invert());
            // zig fmt: on

            const solver_constraint = try Constraint.init(
                self.allocator,
                .{ item_start, Relation.eq, root_start },
                Strength.required,
            );
            defer solver_constraint.deinit();
            self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
        }

        if (self.items.len > 0) {
            const item = &self.items[self.items.len - 1];

            // zig fmt: off
            const item_start  = item.start(self.direction);
            const item_length = item.length(self.direction);
            const root_start  = self.root.start(self.direction);
            const root_length = self.root.length(self.direction);
            // zig fmt: on

            const solver_constraint = try Constraint.init(
                self.allocator,
                .{ item_start, item_length, Relation.eq, root_start, root_length },
                Strength.required,
            );
            defer solver_constraint.deinit();
            self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
        }

        for (self.items) |item| {
            // zig fmt: off
            const item_start  = item.start(self.direction.invert());
            const item_length = item.length(self.direction.invert());
            const root_start  = self.root.start(self.direction.invert());
            const root_length = self.root.length(self.direction.invert());
            // zig fmt: on

            const solver_constraint = try Constraint.init(
                self.allocator,
                .{ item_start, item_length, Relation.eq, root_start, root_length },
                Strength.required,
            );
            defer solver_constraint.deinit();
            self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
        }

        for (0..self.items.len -| 1) |i| {
            const curr = &self.items[i];
            const next = &self.items[i + 1];

            const connection = try Constraint.init(
                self.allocator,
                .{
                    curr.start(self.direction),
                    curr.length(self.direction),
                    Relation.eq,
                    next.start(self.direction),
                },
                Strength.required,
            );
            defer connection.deinit();
            self.root.context.solver.addConstraint(connection) catch |err| return OOM(err);
        }

        for (constraints, 0..) |i, j| {
            const entry = i.unwrap();
            const stack_constraint = entry.constraint;
            const strength = entry.strength;
            const item = &self.items[j];

            switch (stack_constraint) {
                // auto constraints come in the form of a weak, fill
                // constraint, so the original constraint should never reach
                // this branch. if it does, report the issue.
                .auto_constraint => unreachable,

                // item.length == fraction * root.length
                //
                // Restrict the item to take up a fraction of the layout.
                .fraction_constraint => |fraction| {
                    // zig fmt: off
                    const numerator:   f32 = @floatFromInt(fraction[0]);
                    const denominator: f32 = @floatFromInt(fraction[1]);
                    // zig fmt: on

                    const solver_constraint = try Constraint.init(
                        self.allocator,
                        .{
                            term(denominator, item.length(self.direction)),
                            Relation.eq,
                            term(numerator, self.root.length(self.direction)),
                        },
                        strength,
                    );
                    defer solver_constraint.deinit();
                    self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
                },

                // Restrict the item to fill up the available space
                // proportionally equal to other items in the layout.
                .fill_constraint => |factor| {
                    // Item.length == Frame.length (weak)
                    //
                    // Make sure the element takes up as much available space
                    // as possible if other constraints allow this.
                    {
                        const solver_constraint = try Constraint.init(
                            self.allocator,
                            .{ item.length(self.direction), Relation.eq, self.root.length(self.direction) },
                            Strength.weak,
                        );
                        defer solver_constraint.deinit();
                        self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
                    }

                    const lhs = item;
                    for (j..constraints.len) |k| {
                        if (constraints[k] != .fill_constraint)
                            continue;
                        const rhs = &self.items[k];

                        const lhs_factor: f32 = @floatFromInt(factor);
                        const lhs_length = lhs.length(self.direction);
                        const rhs_factor: f32 = @floatFromInt(constraints[k].fill_constraint);
                        const rhs_length = rhs.length(self.direction);

                        const solver_constraint = try Constraint.init(
                            self.allocator,
                            .{ term(lhs_factor, rhs_length), Relation.eq, term(rhs_factor, lhs_length) },
                            strength,
                        );
                        defer solver_constraint.deinit();
                        self.root.context.solver.addConstraint(solver_constraint) catch |err| return OOM(err);
                    }
                },
            }
        }
    }
};

pub const StackConstraint = union(enum) {
    auto_constraint,
    fill_constraint: u16,
    fraction_constraint: [2]u16,

    // ---

    pub fn auto() StackConstraint {
        return .auto_constraint;
    }

    pub fn fill(value: u16) StackConstraint {
        return .{ .fill_constraint = value };
    }

    pub fn fraction(numerator: u16, denominator: u16) StackConstraint {
        return .{ .fraction_constraint = .{ numerator, denominator } };
    }

    // ---

    fn unwrap(self: StackConstraint) struct { constraint: StackConstraint, strength: f32 } {
        var strength = Strength.strong;
        var constraint = self;
        if (self == .auto_constraint) {
            constraint = .{ .fill_constraint = 1 };
            strength = Strength.weak;
        }

        return .{ .constraint = constraint, .strength = strength };
    }
};

// ---

pub const Direction = enum {
    horizontal,
    vertical,

    pub fn invert(self: Direction) Direction {
        return switch (self) {
            .horizontal => .vertical,
            .vertical => .horizontal,
        };
    }
};

// ---

/// Restricts the variable to fit within an unsigned 16-bit integer.
fn restrictToUnsigned16(
    allocator: std.mem.Allocator,
    solver: *Solver,
    variable: Variable,
) std.mem.Allocator.Error!void {
    const min_constraint = try Constraint.init(
        allocator,
        .{ variable, Relation.geq, 0.0 },
        Strength.required,
    );
    defer min_constraint.deinit();
    solver.addConstraint(min_constraint) catch |err| return OOM(err);

    const max_constraint = try Constraint.init(
        allocator,
        .{ variable, Relation.leq, @as(f64, @floatFromInt(std.math.maxInt(u16))) * FLOAT_PRECISION_MULTIPLIER },
        Strength.required,
    );
    defer max_constraint.deinit();
    solver.addConstraint(max_constraint) catch |err| return OOM(err);

    const shrink_constraint = try Constraint.init(
        allocator,
        .{ variable, Relation.eq, 0.0 },
        Strength.weak,
    );
    defer shrink_constraint.deinit();
    solver.addConstraint(shrink_constraint) catch |err| return OOM(err);
}

fn OOM(err: anyerror) error{OutOfMemory} {
    switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.UnsatisfiableConstraint => @panic("Unsatisfiable Constraint"),

        else => unreachable,
    }
}

//
// Horizontal Stack Layout Tests
//

test "lifecycle of an empty horizontal stack layout" {
    const stack = try Stack.horizontal(std.testing.allocator, &.{});
    defer stack.deinit();
}

test "horizontal()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            const stack = try Stack.horizontal(allocator, &.{
                StackConstraint.auto(),
                StackConstraint.fill(1),
                StackConstraint.fill(2),
                StackConstraint.fraction(1, 2),
            });
            defer stack.deinit();
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "horizontal layout" {
    var stack = try Stack.horizontal(std.testing.allocator, &.{
        StackConstraint.auto(),
        StackConstraint.fill(1),
        StackConstraint.fraction(1, 2),
        StackConstraint.fill(2),
    });
    defer stack.deinit();

    try stack.setWidth(59);
    try stack.setMinHeight(11);
    try stack.setMaxHeight(23);
    try stack.setOrigin(5, 9);

    try stack.items[0].suggestWidth(20);
    try stack.items[0].suggestMinHeight(15);
    try stack.items[1].suggestMinHeight(17);
    try stack.items[2].suggestHeight(25);

    // zig fmt: off

    try std.testing.expectEqual(59, stack.width());
    try std.testing.expectEqual(23, stack.height());

    try std.testing.expectEqual(9,  stack.top());
    try std.testing.expectEqual(32, stack.bottom());
    try std.testing.expectEqual(5,  stack.left());
    try std.testing.expectEqual(64, stack.right());

    // ---

    try std.testing.expectEqual(20, stack.items[0].width());
    try std.testing.expectEqual(23, stack.items[0].height());

    try std.testing.expectEqual(9,  stack.items[0].top());
    try std.testing.expectEqual(32, stack.items[0].bottom());
    try std.testing.expectEqual(5,  stack.items[0].left());
    try std.testing.expectEqual(25, stack.items[0].right());

    // ---
    
    try std.testing.expectEqual(3,  stack.items[1].width());
    try std.testing.expectEqual(23, stack.items[1].height());

    try std.testing.expectEqual(9,  stack.items[1].top());
    try std.testing.expectEqual(32, stack.items[1].bottom());
    try std.testing.expectEqual(25, stack.items[1].left());
    try std.testing.expectEqual(28, stack.items[1].right());

    // ---

    try std.testing.expectEqual(30, stack.items[2].width());
    try std.testing.expectEqual(23, stack.items[2].height());

    try std.testing.expectEqual(9,  stack.items[2].top());
    try std.testing.expectEqual(32, stack.items[2].bottom());
    try std.testing.expectEqual(28, stack.items[2].left());
    try std.testing.expectEqual(58, stack.items[2].right());

    // ---

    try std.testing.expectEqual(6,  stack.items[3].width());
    try std.testing.expectEqual(23, stack.items[3].height());

    try std.testing.expectEqual(9,  stack.items[3].top());
    try std.testing.expectEqual(32, stack.items[3].bottom());
    try std.testing.expectEqual(58, stack.items[3].left());
    try std.testing.expectEqual(64, stack.items[3].right());

    // zig fmt: on
}

//
// Vertical Stack Layout Tests
//

test "deinit() an empty vertical stack layout" {
    const stack = try Stack.vertical(std.testing.allocator, &.{});
    defer stack.deinit();
}

test "vertical()" {
    const impl = struct {
        fn function(allocator: std.mem.Allocator) !void {
            const stack = try Stack.vertical(allocator, &.{
                StackConstraint.auto(),
                StackConstraint.fill(1),
                StackConstraint.fill(2),
                StackConstraint.fraction(1, 2),
            });
            defer stack.deinit();
        }
    };

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        impl.function,
        .{},
    );
}

test "vertical layout" {
    var stack = try Stack.vertical(std.testing.allocator, &.{
        StackConstraint.fill(1),
        StackConstraint.auto(),
        StackConstraint.auto(),
        StackConstraint.fill(2),
    });
    defer stack.deinit();

    try stack.setOrigin(5, 9);
    try stack.setHeight(59);
    stack.optimizeWidth();
    try stack.items[1].suggestHeight(15);
    try stack.items[2].suggestMinWidth(10);
    try stack.items[3].suggestMinWidth(17);

    // zig fmt: off
    
    try std.testing.expectEqual(17, stack.width());
    try std.testing.expectEqual(59, stack.height());

    try std.testing.expectEqual(9,  stack.top());
    try std.testing.expectEqual(68, stack.bottom());
    try std.testing.expectEqual(5,  stack.left());
    try std.testing.expectEqual(22, stack.right());

    // ---

    try std.testing.expectEqual(17, stack.items[0].width());
    try std.testing.expectEqual(11, stack.items[0].height());

    try std.testing.expectEqual(9,  stack.items[0].top());
    try std.testing.expectEqual(20, stack.items[0].bottom());
    try std.testing.expectEqual(5,  stack.items[0].left());
    try std.testing.expectEqual(22, stack.items[0].right());

    // --

    try std.testing.expectEqual(17, stack.items[1].width());
    try std.testing.expectEqual(15, stack.items[1].height());

    try std.testing.expectEqual(20, stack.items[1].top());
    try std.testing.expectEqual(35, stack.items[1].bottom());
    try std.testing.expectEqual(5,  stack.items[1].left());
    try std.testing.expectEqual(22, stack.items[1].right());

    // --

    try std.testing.expectEqual(17, stack.items[2].width());
    try std.testing.expectEqual(11, stack.items[2].height());

    try std.testing.expectEqual(35, stack.items[2].top());
    try std.testing.expectEqual(46, stack.items[2].bottom());
    try std.testing.expectEqual(5,  stack.items[2].left());
    try std.testing.expectEqual(22, stack.items[2].right());

    // --

    try std.testing.expectEqual(17, stack.items[3].width());
    try std.testing.expectEqual(22, stack.items[3].height());

    try std.testing.expectEqual(46, stack.items[3].top());
    try std.testing.expectEqual(68, stack.items[3].bottom());
    try std.testing.expectEqual(5,  stack.items[3].left());
    try std.testing.expectEqual(22, stack.items[3].right());

    // zig fmt: on
}
