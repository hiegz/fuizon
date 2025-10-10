const std = @import("std");

const Variable = @import("variable.zig").Variable;
const Expression = @import("expression.zig").Expression;

// zig fmt: off

pub const Row = struct {
    basis:     *Variable,
    expression: Expression,

    pub const empty = Row{ .basis = undefined, .expression = .empty };

    /// Solves the row for the specified variable.
    ///
    /// Given a row in the form `z = c + b*y + a*x + ...`, this function
    /// rewrites the row so that `x = -(c - z + b*y + ...) / a`
    pub fn solveFor(
        self: *Row,
        gpa: std.mem.Allocator,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        try self.expression.insert(gpa, -1.0, self.basis);
        try self.expression.solveFor(gpa, variable);
        self.basis = variable;
    }

    pub fn clone(self: Row, gpa: std.mem.Allocator) error{OutOfMemory}!Row {
        var other: Row   = undefined;
        other.basis      = self.basis;
        other.expression = try self.expression.clone(gpa);

        return other;
    }

    pub fn deinit(self: *Row, gpa: std.mem.Allocator) void {
        self.expression.deinit(gpa);
    }

    /// The caller no longer manages the row. Calling `deinit()` is safe, but
    /// unnecessary.
    pub fn release(self: *Row) void {
        self.expression.release();
    }
};
