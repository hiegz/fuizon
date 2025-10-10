const std = @import("std");
const float32 = @import("float32.zig");

const Term = @import("term.zig").Term;
const Variable = @import("variable.zig").Variable;

pub const Row = struct {
    const Map = std.AutoHashMapUnmanaged(*Variable, f32);

    constant: f32 = 0.0,
    term_map: Map = .empty,

    pub const empty = Row{};

    pub fn deinit(self: *Row, gpa: std.mem.Allocator) void {
        self.term_map.deinit(gpa);
    }

    pub fn clone(self: Row, gpa: std.mem.Allocator) error{OutOfMemory}!Row {
        var ret: Row = undefined;
        ret.constant = self.constant;
        ret.term_map = try self.term_map.clone(gpa);
        return ret;
    }

    pub const Entry = struct {
        coefficient: *f32,
        variable: *Variable,

        pub fn toTerm(self: Entry) Term {
            return Term.init(self.coefficient.*, self.variable);
        }
    };

    pub fn findVariable(self: *const Row, variable: *Variable) ?Entry {
        if (self.term_map.getEntry(variable)) |entry| {
            return Entry{
                .coefficient = entry.value_ptr,
                .variable = entry.key_ptr.*,
            };
        }

        return null;
    }

    pub const Iterator = struct {
        term_map_iterator: Map.Iterator,

        pub fn next(self: *Iterator) ?Entry {
            if (self.term_map_iterator.next()) |entry| {
                return Entry{
                    .coefficient = entry.value_ptr,
                    .variable = entry.key_ptr.*,
                };
            }

            return null;
        }
    };

    pub fn iterator(self: *const Row) Iterator {
        return .{ .term_map_iterator = self.term_map.iterator() };
    }

    /// Returns the coefficient of a given variable in this row.
    ///
    /// If the row contains a term for the specified `variable`, its
    /// coefficient is returned. If the variable does not appear in the row,
    /// this function returns `0.0`
    pub fn coefficientOf(self: Row, variable: *Variable) f32 {
        return self.term_map.get(variable) orelse 0.0;
    }

    pub fn containsVariable(self: Row, variable: *Variable) bool {
        return self.coefficientOf(variable) != 0.0;
    }

    pub fn containsTerm(self: Row, term: Term) bool {
        return term.coefficient == self.coefficientOf(term.variable);
    }

    pub fn insertRow(
        self: *Row,
        gpa: std.mem.Allocator,
        coefficient: f32,
        row: Row,
    ) error{OutOfMemory}!void {
        self.constant += coefficient * row.constant;

        var row_iterator = row.iterator();
        while (row_iterator.next()) |entry| {
            const term = entry.toTerm();
            const new_coefficient = coefficient * term.coefficient;
            const variable = term.variable;

            try self.insert(gpa, new_coefficient, variable);
        }
    }

    pub fn insertTerm(self: *Row, gpa: std.mem.Allocator, term: Term) error{OutOfMemory}!void {
        if (float32.nearZero(term.coefficient)) return;

        if (self.findVariable(term.variable)) |entry| {
            entry.coefficient.* += term.coefficient;
            if (float32.nearZero(entry.coefficient.*))
                self.removeEntry(entry);
        } else {
            try self.term_map.putNoClobber(gpa, term.variable, term.coefficient);
        }
    }

    pub fn insert(
        self: *Row,
        gpa: std.mem.Allocator,
        coefficient: f32,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        return self.insertTerm(gpa, Term.init(coefficient, variable));
    }

    pub fn removeEntry(self: *Row, entry: Entry) void {
        _ = self.removeVariable(entry.variable);
    }

    pub fn removeVariable(self: *Row, variable: *Variable) bool {
        return self.term_map.remove(variable);
    }

    /// Replaces all occurrences of a variable in this row with the provided
    /// row. After this operation, the variable will no longer appear in this
    /// row.
    pub fn substitute(
        self: *Row,
        gpa: std.mem.Allocator,
        variable: *Variable,
        row: Row,
    ) error{OutOfMemory}!void {
        if (self.findVariable(variable)) |entry| {
            const coefficient = entry.coefficient.*;
            self.removeEntry(entry);
            try self.insertRow(gpa, coefficient, row);
        }
    }

    // zig fmt: off

    /// Solves the row for the specified variable.
    ///
    /// Given a row in the form `c + b*y + a*x + ...`, this function rewrites
    /// the row so that the expression `x = r = -(c + b*y + ...) / a` holds,
    /// where `r` represents the rewritten row. The specified variable (`x`) is
    /// removed from the row.
    ///
    /// The caller is responsible for adding any previous basis variable to the
    /// row before calling this function, and for setting the specified
    /// variable (`x`) as the new basis in the tableau afterwards.
    pub fn solveFor(
        self: *Row,
        gpa: std.mem.Allocator,
        variable: *Variable,
    ) error{OutOfMemory}!void {
        var coefficient: f32 = 0.0;

        if (self.findVariable(variable)) |entry| {
            coefficient = -1.0 / entry.coefficient.*;
            self.removeEntry(entry);
        }

        if (coefficient == 0.0)
            @panic("variable is not in the row");

        self.constant *= coefficient;

        // any modification in the hash map invalidates live entries and
        // iterators, so we can't remove variables while iterating over the
        // map. instead, we memorize these variables inside `remove_list` and
        // remove them later.
        var   remove_list = std.ArrayList(*Variable).empty;
        defer remove_list.deinit(gpa);

        var   row_iterator = self.iterator();
        while (row_iterator.next()) |entry| {
            entry.coefficient.* *= coefficient;
            if (float32.nearZero(entry.coefficient.*))
                try remove_list.append(gpa, entry.variable);
        }

        for (remove_list.items) |item| {
            const removed = self.removeVariable(item);
            std.debug.assert(removed);
        }
    }

    // zig fmt: on

    pub fn equals(self: Row, other: Row) bool {
        var row_iterator: Iterator = undefined;

        if (!float32.nearEq(self.constant, other.constant))
            return false;

        row_iterator = self.iterator();
        while (row_iterator.next()) |entry|
            if (!other.containsTerm(entry.toTerm()))
                return false;

        row_iterator = other.iterator();
        while (row_iterator.next()) |entry|
            if (!self.containsTerm(entry.toTerm()))
                return false;

        return true;
    }

    pub fn format(self: Row, writer: *std.Io.Writer) !void {
        try writer.print("{d}", .{self.constant});

        // zig fmt: off

        var low_id:   usize = 0;
        var min_id:   usize = undefined;
        var min_term: Term  = undefined;

        var _row_iterator = self.iterator();
        while (_row_iterator.next()) |_| {
            min_id = std.math.maxInt(usize);

            var row_iterator = self.iterator();
            while (row_iterator.next()) |entry| {
                const term = entry.toTerm();
                const variable = term.variable;
                if (variable.id() > low_id and variable.id() < min_id) {
                    min_id   = variable.id();
                    min_term = term;
                }
            }

            // zig fmt: on

            low_id = min_id;
            try writer.writeAll(if (min_term.coefficient >= 0) " + " else " - ");
            try writer.print("{d} * {f}", .{ @abs(min_term.coefficient), min_term.variable });
        }
    }
};
