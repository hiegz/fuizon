const std = @import("std");
const c = @import("headers.zig").c;

pub const Variable = struct {
    allocator: std.mem.Allocator,
    ptr: ?*anyopaque,

    /// Initializes a new Variable with the provided Allocator.
    pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Variable {
        const ptr = c.fuiwi_variable_new(
            @ptrCast(@constCast(&allocator)),
            fuiwi_alloc_fn,
        );
        if (ptr == null) return error.OutOfMemory;
        return .{ .allocator = allocator, .ptr = ptr };
    }

    /// Deinitializes the variable.
    pub fn deinit(self: Variable) void {
        c.fuiwi_variable_del(
            self.ptr,
            @ptrCast(@constCast(&self.allocator)),
            fuiwi_free_fn,
        );
    }

    /// Returns the current value of the variable.
    pub fn value(self: Variable) f64 {
        return c.fuiwi_variable_value(self.ptr);
    }
};

pub const Term = struct {
    variable: Variable,
    constant: f64 = 1.0,
};

pub inline fn term(constant: f64, variable: Variable) Term {
    return .{ .variable = variable, .constant = constant };
}

pub const Expression = struct {
    allocator: std.mem.Allocator,
    ptr: ?*anyopaque,

    /// Initializes a new expression.
    pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Expression {
        const ptr = c.fuiwi_expression_new(
            @ptrCast(@constCast(&allocator)),
            fuiwi_alloc_fn,
        );
        if (ptr == null) return error.OutOfMemory;
        return .{ .allocator = allocator, .ptr = ptr };
    }

    /// Deinitializes the expression.
    pub fn deinit(self: Expression) void {
        c.fuiwi_expression_del(
            self.ptr,
            @ptrCast(@constCast(&self.allocator)),
            fuiwi_free_fn,
        );
    }

    /// Adds a term to the expression.
    pub fn addTerm(self: *Expression, variable: Variable, coefficient: f64) error{OutOfMemory}!void {
        var ret: c_int = undefined;
        ret = c.fuiwi_expression_add_term(self.ptr, variable.ptr, coefficient);
        if (-5915 == ret) return error.OutOfMemory;
    }

    /// Adds a constant to the expression.
    pub fn addConstant(self: *Expression, constant: f64) error{OutOfMemory}!void {
        var ret: c_int = undefined;
        ret = c.fuiwi_expression_add_constant(self.ptr, constant);
        if (-5915 == ret) return error.OutOfMemory;
    }

    /// Removes all terms and constants from the expression.
    pub fn reset(self: *Expression) void {
        c.fuiwi_expression_reset(self.ptr);
    }
};

pub const Constraint = struct {
    allocator: std.mem.Allocator,
    ptr: ?*anyopaque,

    /// Initializes a new constraint.
    pub fn init(
        allocator: std.mem.Allocator,
        expression: anytype,
        strength: f64,
    ) error{OutOfMemory}!Constraint {
        var relation: ?Relation = null;
        var lhs = try Expression.init(allocator);
        defer lhs.deinit();
        var rhs = try Expression.init(allocator);
        defer rhs.deinit();

        var expr: *Expression = &lhs;

        inline for (std.meta.fields(@TypeOf(expression))) |field| {
            const val = @field(expression, field.name);
            switch (@TypeOf(val)) {
                Variable => try expr.addTerm(val, 1.0),
                Term => try expr.addTerm(val.variable, val.constant),
                Relation => {
                    std.debug.assert(relation == null);
                    expr = &rhs;
                    relation = val;
                },
                else => switch (@typeInfo(@TypeOf(val))) {
                    .Int => try expr.addConstant(@floatFromInt(val)),
                    .ComptimeInt => try expr.addConstant(@floatFromInt(val)),
                    .Float => try expr.addConstant(val),
                    .ComptimeFloat => try expr.addConstant(val),
                    else => unreachable,
                },
            }
        }

        return initExpression(allocator, lhs, rhs, relation.?, strength);
    }

    /// Initializes a new constraint.
    pub fn initExpression(
        allocator: std.mem.Allocator,
        lhs: Expression,
        rhs: Expression,
        relation: Relation,
        strength: f64,
    ) std.mem.Allocator.Error!Constraint {
        const ptr = c.fuiwi_constraint_new(
            lhs.ptr,
            rhs.ptr,
            @intFromEnum(relation),
            strength,
            @ptrCast(@constCast(&allocator)),
            fuiwi_alloc_fn,
        );
        if (ptr == null) return error.OutOfMemory;
        return .{ .allocator = allocator, .ptr = ptr };
    }

    /// Deinitializes the constraint.
    pub fn deinit(self: Constraint) void {
        c.fuiwi_constraint_del(
            self.ptr,
            @ptrCast(@constCast(&self.allocator)),
            fuiwi_free_fn,
        );
    }
};

pub const Solver = struct {
    allocator: std.mem.Allocator,
    ptr: ?*anyopaque,

    /// Initializes a new solver.
    pub fn init(allocator: std.mem.Allocator) error{OutOfMemory}!Solver {
        const ptr = c.fuiwi_solver_new(@ptrCast(@constCast(&allocator)), fuiwi_alloc_fn);
        if (ptr == null) return error.OutOfMemory;
        return .{ .allocator = allocator, .ptr = ptr };
    }

    /// Deinitializes the solver.
    pub fn deinit(self: Solver) void {
        c.fuiwi_solver_del(
            self.ptr,
            @ptrCast(@constCast(&self.allocator)),
            fuiwi_free_fn,
        );
    }

    /// Adds a constraint to the solver.
    pub fn addConstraint(self: *Solver, constraint: Constraint) error{ OutOfMemory, UnsatisfiableConstraint }!void {
        var ret: c_int = undefined;
        ret = c.fuiwi_solver_add_constraint(self.ptr, constraint.ptr);
        if (-1 == ret) return error.UnsatisfiableConstraint;
        if (-5915 == ret) return error.OutOfMemory;
    }

    /// Checks whether the constraint has been already added to the solver.
    pub fn hasConstraint(self: Solver, constraint: Constraint) bool {
        const ret = c.fuiwi_solver_has_constraint(self.ptr, constraint.ptr);
        return if (ret == 1) true else false;
    }

    /// Removes an edit variable from the solver.
    pub fn removeConstraint(self: *Solver, constraint: Constraint) void {
        c.fuiwi_solver_remove_constraint(self.ptr, constraint.ptr);
    }

    /// Adds an edit variable to the solver.
    pub fn addVariable(self: *Solver, variable: Variable, strength: f64) error{OutOfMemory}!void {
        var ret: c_int = undefined;
        ret = c.fuiwi_solver_add_edit_variable(self.ptr, variable.ptr, strength);
        if (-5915 == ret) return error.OutOfMemory;
    }

    /// Removes an edit variable from the solver.
    pub fn removeVariable(self: *Solver, variable: Variable) void {
        c.fuiwi_solver_remove_edit_variable(self.ptr, variable.ptr);
    }

    /// Suggests a value for the given edit variable.
    pub fn suggestValue(self: *Solver, variable: Variable, value: f64) error{OutOfMemory}!void {
        var ret: c_int = undefined;
        ret = c.fuiwi_solver_suggest_value(self.ptr, variable.ptr, value);
        if (-5915 == ret) return error.OutOfMemory;
    }

    /// Updates the values of the external solver variables.
    pub fn updateVariables(self: *Solver) void {
        c.fuiwi_solver_update_variables(self.ptr);
    }
};

pub const Relation = enum(u2) {
    /// Less or equal to (<=)
    leq = 0,

    /// Greater or equal to (>=)
    geq = 1,

    /// Equal to (==)
    eq = 2,
};

pub const Strength = struct {
    pub inline fn create(s: f32, m: f32, w: f32) f32 {
        var r: f32 = 0.0;
        r += s * 1000000.0;
        r += m * 1000.0;
        r += w;
        return r;
    }

    pub const required = create(1000.0, 1000.0, 1000.0);
    pub const strong = create(1.0, 0.0, 0.0);
    pub const medium = create(0.0, 1.0, 0.0);
    pub const weak = create(0.0, 0.0, 1.0);
};

fn fuiwi_alloc_fn(
    user_data: ?*anyopaque,
    size: usize,
) callconv(.C) ?*anyopaque {
    const allocator: *const std.mem.Allocator = @ptrCast(@alignCast(user_data));
    const memory = allocator.alloc(u8, size) catch return null;

    return @ptrCast(&memory[0]);
}

fn fuiwi_free_fn(
    user_data: ?*anyopaque,
    ptr: ?*anyopaque,
    size: usize,
) callconv(.C) void {
    const allocator: *const std.mem.Allocator = @ptrCast(@alignCast(user_data));
    const memory = @as([*]u8, @ptrCast(@alignCast(ptr)))[0..size];

    allocator.free(memory);
}
