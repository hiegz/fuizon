const std = @import("std");

const Expression = @import("expression.zig").Expression;
const Operator = @import("operator.zig").Operator;

// zig fmt: off

pub const Constraint = struct {
    expression: Expression,
    operator:   Operator,
    strength:   f32,

    pub fn init(
        gpa: std.mem.Allocator,
        lhs: Expression,
        rhs: Expression,
        operator: Operator,
        strength: f32,
    ) error{OutOfMemory}!Constraint {
        var self: Constraint = undefined;
        errdefer self.deinit(gpa);

        self.expression = .empty;
        self.operator = operator;
        self.strength = strength;

        try self.expression.insertExpression(gpa,  1.0, lhs);
        try self.expression.insertExpression(gpa, -1.0, rhs);

        return self;
    }

    pub fn deinit(self: *Constraint, gpa: std.mem.Allocator) void {
        self.expression.deinit(gpa);
    }
};
