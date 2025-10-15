const std = @import("std");

const Expression = @import("expression.zig").Expression;
const Operator = @import("operator.zig").Operator;

// zig fmt: off

pub const Constraint = struct {
    lhs:        Expression = .empty,
    rhs:        Expression = .empty,
    operator:   Operator   = undefined,
    strength:   f64        = undefined,

    pub const empty = Constraint{};

    pub fn deinit(self: *Constraint, gpa: std.mem.Allocator) void {
        self.lhs.deinit(gpa);
        self.rhs.deinit(gpa);
    }

    /// The caller no longer manages the constraint. Calling `deinit()` is
    /// safe, but unnecessary.
    pub fn release(self: *Constraint) void {
        self.lhs.release();
        self.rhs.release();
    }
};
