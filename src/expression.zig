const std = @import("std");
const float32 = @import("float32.zig");

const Variable = @import("variable.zig").Variable;
const Term = @import("term.zig").Term;

pub const Expression = struct {
    constant: f32 = 0.0,
    term_list: std.ArrayList(Term) = .empty,

    pub const empty = Expression{};

    pub fn deinit(self: *const Expression, gpa: std.mem.Allocator) void {
        gpa.free(self.term_list.allocatedSlice());
    }

    pub fn clearAndRetainCapacity(self: *Expression) void {
        self.constant = 0.0;
        self.term_list.clearRetainingCapacity();
    }

    pub fn add(
        self: *Expression,
        gpa: std.mem.Allocator,
        coefficient: f32,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        if (float32.nearZero(coefficient)) return;
        try self.term_list.append(gpa, Term.init(coefficient, variable));
    }

    pub fn sub(
        self: *Expression,
        gpa: std.mem.Allocator,
        coefficient: f32,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        try self.add(gpa, -coefficient, variable);
    }

    pub fn mul(self: *Expression, k: f32) void {
        self.constant *= k;
        for (self.term_list.items) |*term|
            term.coefficient *= k;
    }

    pub fn append(
        self: *Expression,
        gpa: std.mem.Allocator,
        expression: Expression,
    ) error{OutOfMemory}!void {
        self.constant += expression.constant;
        for (expression.term_list.items) |term|
            try self.add(gpa, term.coefficient, term.variable);
    }
};
