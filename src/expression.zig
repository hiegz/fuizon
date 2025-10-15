const std = @import("std");
const float64 = @import("float64.zig");

const Variable = @import("variable.zig").Variable;
const Term = @import("term.zig").Term;
const TermMap = std.AutoHashMapUnmanaged(*Variable, f64);

// zig fmt: off

pub const Expression = struct {
    constant: f64 = 0.0,
    term_map: TermMap = .empty,

    pub const empty = Expression{};

    pub fn deinit(self: *Expression, gpa: std.mem.Allocator) void {
        self.term_map.deinit(gpa);
    }

    /// The caller no longer manages the expression. Calling `deinit()` is
    /// safe, but unnecessary.
    pub fn release(self: *Expression) void {
        self.term_map = .empty;
    }

    /// Creates a deep copy of the expression.
    pub fn clone(self: Expression, gpa: std.mem.Allocator) error{OutOfMemory}!Expression {
        var ret: Expression = undefined;
        ret.constant = self.constant;
        ret.term_map = try self.term_map.clone(gpa);
        return ret;
    }

    /// Non-owning view of a term inside an Expression's hash map. Backing
    /// memory is owned by the respective Expression instance. The pointers
    /// must not be reassigned, but the data they reference may be modified.
    ///
    /// Insertions or removals of terms in the expression invalidate the
    /// pointers.
    pub const TermEntry = struct {
        coefficient_ptr:  *f64,
        variable_ptr:    **Variable,

        pub fn coefficient(self: TermEntry) f64 {
            return self.coefficient_ptr.*;
        }

        pub fn variable(self: TermEntry) *Variable {
            return self.variable_ptr.*;
        }

        /// Returns an owning copy of the non-owning term view.
        pub fn toOwned(self: TermEntry) Term {
            return Term.init(self.coefficient(), self.variable());
        }

        pub fn fromHashMapEntry(entry: TermMap.Entry) TermEntry {
            return .{
                .variable_ptr    = entry.key_ptr,
                .coefficient_ptr = entry.value_ptr,
            };
        }
    };

    /// Provides an interface for iterating over terms in an expression.
    ///
    /// Insertions or removals of terms in the expression invalidate live
    /// iterators.
    pub const TermIterator = struct {
        iterator: TermMap.Iterator,

        pub fn next(self: *TermIterator) ?TermEntry {
            if (self.iterator.next()) |entry|
                return TermEntry.fromHashMapEntry(entry);

            return null;
        }
    };

    pub fn termIterator(self: *const Expression) TermIterator {
        return .{ .iterator = self.term_map.iterator() };
    }

    /// Returns a non-owning view of a term (if any) associated with the given variable.
    pub fn find(self: Expression, variable: *Variable) ?TermEntry {
        if (self.term_map.getEntry(variable)) |entry|
            return TermEntry.fromHashMapEntry(entry);

        return null;
    }

    /// Returns the coefficient of a given variable in the expression.
    ///
    /// If the expression contains the specified variable, its coefficient is
    /// returned. If the variable does not appear in the expression, this
    /// function returns `0.0`
    pub fn getCoefficientFor(self: Expression, variable: *Variable) f64 {
        return if (self.find(variable)) |term| term.coefficient() else 0.0;
    }

    pub fn containsVariable(self: Expression, variable: *Variable) bool {
        return self.term_map.contains(variable);
    }

    pub fn containsTerm(self: Expression, term: Term) bool {
        return term.coefficient == self.getCoefficientFor(term.variable);
    }

    /// Adds a given value to the constant.
    pub fn add(self: *Expression, constant: f64) void {
        self.constant += constant;
    }

    /// Subtracts a given value from the constant.
    pub fn subtract(self: *Expression, constant: f64) void {
        self.constant -= constant;
    }

    /// Multiplies the whole expression with a given value.
    pub fn multiply(self: *Expression, k: f64) void {
        self.constant *= k;
        var iterator = self.term_map.valueIterator();
        while (iterator.next()) |coefficient|
            coefficient.* *= k;
    }

    /// Divides the whole expression with a given value.
    pub fn divide(self: *Expression, k: f64) void {
        self.multiply(1 / k);
    }

    /// Adds the provided variable multiplied by `coefficient` to the
    /// expression.
    pub fn insert(
        self: *Expression,
        gpa: std.mem.Allocator,
        coefficient: f64,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        return self.insertTerm(gpa, Term.init(coefficient, variable));
    }

    /// Adds the provided term to the expression.
    pub fn insertTerm(self: *Expression, gpa: std.mem.Allocator, term: Term) error{OutOfMemory}!void {
        if (float64.nearZero(term.coefficient)) return;

        if (self.find(term.variable)) |term_entry| {
            term_entry.coefficient_ptr.* += term.coefficient;
            if (float64.nearZero(term_entry.coefficient_ptr.*))
                self.remove(term_entry);
        } else {
            try self.term_map.putNoClobber(gpa, term.variable, term.coefficient);
        }
    }

    /// Adds the constant and terms from the provided expression into this expression.
    pub fn insertExpression(
        self: *Expression,
        gpa: std.mem.Allocator,
        coefficient: f64,
        expression: Expression,
    ) error{OutOfMemory}!void {
        self.constant += coefficient * expression.constant;

        var term_iterator = expression.termIterator();
        while (term_iterator.next()) |term_entry| {
            const term = term_entry.toOwned();
            const new_coefficient = coefficient * term.coefficient;
            const variable = term.variable;

            try self.insert(gpa, new_coefficient, variable);
        }
    }

    /// Removes the term from the expression.
    pub fn remove(self: *Expression, entry: TermEntry) void {
        return self.term_map.removeByPtr(entry.variable_ptr);
    }

    /// Removes the term from the expression and returns it to the caller.
    pub fn fetchRemove(self: *Expression, entry: TermEntry) Term {
        const term = entry.toOwned();
        self.remove(entry);
        return term;
    }

    /// Replaces all occurrences of a variable in this expression with the
    /// provided expression.
    pub fn substitute(
        self: *Expression,
        gpa: std.mem.Allocator,
        variable: *Variable,
        expression: Expression,
    ) error{OutOfMemory}!void {
        if (self.find(variable)) |term_entry| {
            const term = self.fetchRemove(term_entry);
            try self.insertExpression(gpa, term.coefficient, expression);
        }
    }

    /// Solves the expression for the specified variable.
    ///
    /// Given an expression in the form `c + b*y + a*x + ...`, this function
    /// rewrites the expression so that the expression `x = e = -(c + b*y + ...) / a`
    /// holds, where `e` represents the rewritten expression. The specified
    /// variable (`x`) is removed from the expression.
    ///
    /// The caller is responsible for adding any previous basis variable to the
    /// expression before calling this function, and for setting the specified
    /// variable (`x`) as the new basis in the tableau afterwards.
    pub fn solveFor(
        self: *Expression,
        gpa: std.mem.Allocator,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        var coefficient: f64 = 0.0;

        if (self.find(variable)) |entry|
            coefficient = -1.0 / self.fetchRemove(entry).coefficient;

        if (coefficient == 0.0)
            @panic("variable is not in the row");

        self.constant *= coefficient;

        // any modification in the hash map invalidates live entries and
        // iterators, so we can't remove variables while iterating over the
        // map. instead, we memorize these variables inside `remove_list` and
        // remove them later.
        var   remove_list = std.ArrayList(*Variable).empty;
        defer remove_list.deinit(gpa);

        var   row_iterator = self.termIterator();
        while (row_iterator.next()) |entry| {
            entry.coefficient_ptr.* *= coefficient;
            if (float64.nearZero(entry.coefficient_ptr.*))
                try remove_list.append(gpa, entry.variable());
        }

        for (remove_list.items) |item|
            self.remove(self.find(item).?);
    }

    pub fn equals(self: Expression, other: Expression) bool {
        var iterator: TermIterator = undefined;

        if (!float64.nearEq(self.constant, other.constant))
            return false;

        iterator = self.termIterator();
        while (iterator.next()) |term_entry|
            if (!other.containsTerm(term_entry.toOwned()))
                return false;

        iterator = other.termIterator();
        while (iterator.next()) |entry|
            if (!self.containsTerm(entry.toOwned()))
                return false;

        return true;
    }

    pub fn format(self: Expression, writer: *std.Io.Writer) !void {
        try writer.print("{d}", .{self.constant});

        var low_id:   usize = 0;
        var min_id:   usize = undefined;
        var min_term: Term  = undefined;

        var _row_iterator = self.termIterator();
        while (_row_iterator.next()) |_| {
            min_id = std.math.maxInt(usize);

            var row_iterator = self.termIterator();
            while (row_iterator.next()) |term_entry| {
                const variable = term_entry.variable();
                if (variable.id() > low_id and variable.id() < min_id) {
                    min_id   = variable.id();
                    min_term = term_entry.toOwned();
                }
            }

            low_id = min_id;

            try writer.writeAll(if (min_term.coefficient >= 0) " + " else " - ");
            try writer.print("{d} * {f}", .{ @abs(min_term.coefficient), min_term.variable });
        }
    }
};
