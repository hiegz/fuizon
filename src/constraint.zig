const std = @import("std");

const Expression = @import("expression.zig").Expression;
const Operator = @import("operator.zig").Operator;

pub const Constraint = struct {
    expression: Expression,
    operator: Operator,
    strength: f32,

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

        self.expression.constant += lhs.constant;
        for (lhs.term_list.items) |term|
            try self.expression.add(gpa, term.coefficient, term.variable);
        self.expression.constant -= rhs.constant;
        for (rhs.term_list.items) |term|
            try self.expression.sub(gpa, term.coefficient, term.variable);

        return self;
    }

    pub fn deinit(self: *const Constraint, gpa: std.mem.Allocator) void {
        self.expression.deinit(gpa);
    }
};
