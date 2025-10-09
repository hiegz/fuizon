const std = @import("std");

/// used for comparing float values.
const TOLERANCE = 1.0e-8;

pub const System = struct {
    tableau: Tableau = .empty,
    objective: Row = .empty,

    /// Maps added constraints to their markers
    ///
    /// If constraint is an inequality, then the first marker is always a slack
    /// variable. The second marker is an error variable when the constraint is
    /// also non-required.
    ///
    /// If constraint is an equation, then the markers are plus and minus error
    /// variables when the constraint is also non-required. For required
    /// equality constraints, the first marker is a "dummy" variable.
    constraint_marker_map: std.AutoArrayHashMapUnmanaged(*const Constraint, [2]?*Variable) = .empty,

    pub const empty = System{};

    pub fn deinit(self: *System, gpa: std.mem.Allocator) void {
        self.tableau.deinit(gpa);
        self.objective.deinit(gpa);

        var marker_it = self.constraint_marker_map.iterator();
        while (marker_it.next()) |entry| {
            const markers = entry.value_ptr.*;
            for (markers) |marker| {
                if (marker == null)
                    continue;
                gpa.destroy(marker.?);
            }
        }
        self.constraint_marker_map.deinit(gpa);
    }

    // zig fmt: off

    pub fn addConstraint(
        self: *System,
        gpa: std.mem.Allocator,
        constraint: *const Constraint,
    ) error{ OutOfMemory, DuplicateConstraint, UnsatisfiableConstraint, ObjectiveUnbound }!void {
        if (self.constraint_marker_map.contains(constraint))
            return error.DuplicateConstraint;

        var   markers: [2]?*Variable = .{ null, null };
        defer if (markers[0]) |marker| gpa.destroy(marker);
        defer if (markers[1]) |marker| gpa.destroy(marker);

        // use the current tableau to substitute out all the basic variables

        var   new_row:          Row          = .empty;
        var   new_row_iterator: Row.Iterator = undefined;
        defer new_row.deinit(gpa);

        new_row.constant = constraint.expression.constant;

        for (constraint.expression.term_list.items) |term| {
            if (self.tableau.findBasis(term.variable)) |entry|
                try new_row.insertRow(gpa, term.coefficient, entry.row.*)
            else
                try new_row.insertTerm(gpa, term);
        }

        // add slack and error variables

        switch (constraint.operator) {
            .le, .ge => {
                const coefficient: f32 = switch (constraint.operator) { .le => 1.0, .ge => -1.0, .eq => unreachable };

                const slack = try gpa.create(Variable);
                slack.name  = "";
                slack.kind  = .slack;

                markers[0] = slack;

                try new_row.insert(gpa, coefficient, slack);

                if (constraint.strength < Strength.required) {
                    const err = try gpa.create(Variable);
                    err.name  = "";
                    err.kind  = .err;

                    markers[1] = err;

                    try new_row.insert(gpa, -coefficient, err);
                    try self.objective.insert(gpa, constraint.strength, err);
                }
            },

            .eq => this: {
                // add a dummy variable to server as a marker
                if (constraint.strength == Strength.required) {
                    const dummy = try gpa.create(Variable);
                    dummy.name = "";
                    dummy.kind = .dummy;

                    markers[0] = dummy;

                    try new_row.insert(gpa, 1.0, dummy);

                    break :this;
                }

                const err_plus  = try gpa.create(Variable);
                err_plus.name   = "";
                err_plus.kind   = .err;

                markers[0] = err_plus;

                try new_row.insert(gpa, -1.0, err_plus);
                try self.objective.insert(gpa, constraint.strength, err_plus);

                const err_minus = try gpa.create(Variable);
                err_minus.name  = "";
                err_minus.kind  = .err;

                markers[1] = err_minus;

                try new_row.insert(gpa, 1.0, err_minus);
                try self.objective.insert(gpa, constraint.strength, err_minus);
            },
        }

        // multiply the entire row with -1 so that the constant becomes
        // non-negative.
        //
        // this is possible because the row is of the form l = 0
        if (new_row.constant < 0.0 and !nearZero(new_row.constant)) {
            new_row.constant *= -1;
            new_row_iterator = new_row.iterator();
            while (new_row_iterator.next()) |entry|
                entry.coefficient.* *= -1;
        }

        // choose the subject to enter the basis

        var subject: ?*Variable = null;

        // this block chooses a subject variable which is either an external
        // variable or a new negative slack/error variable.
        //
        // the chosen subject will be assigned to `subject`. Otherwise,
        // `subject` is null.
        selection: {
            new_row_iterator = new_row.iterator();
            while (new_row_iterator.next()) |entry| {
                const term = entry.toTerm();

                if (term.variable.kind != .external)
                    continue;

                subject = term.variable;
                break :selection;
            }

            for (markers) |marker| {
                if  (marker == null) continue;
                if ((marker.?.kind == .slack or marker.?.kind == .err) and
                    new_row.coefficientOf(marker.?) < 0.0)
                {
                    subject = marker.?;
                    break :selection;
                }
            }
        }

        if (subject != null) {
            try new_row.solveFor(gpa, subject.?);
            try self.tableau.substitute(gpa, subject.?, new_row);
            try self.objective.substitute(gpa, subject.?, new_row);
            try self.tableau.insert(gpa, subject.?, new_row);
            new_row = .empty;

        }

        // no subject was found, use an artificial variable
        else {
            var artificial_variable: Variable = undefined;
            artificial_variable.name = "";
            artificial_variable.kind = .slack;

            var artificial_objective = try new_row.clone(gpa);
            defer artificial_objective.deinit(gpa);

            try self.tableau.insert(gpa, &artificial_variable, new_row);
            new_row = .empty;

            try optimize(gpa, &self.tableau, &artificial_objective);
            if (!nearZero(artificial_objective.constant))
                return error.UnsatisfiableConstraint;

            // artificial variable is basic
            if (self.tableau.findBasis(&artificial_variable)) |tableau_entry| {
                var   row = tableau_entry.row.*;
                defer row.deinit(gpa);

                self.tableau.removeEntry(tableau_entry);

                // since we were able to achieve a value of zero for our
                // artificial objective function which is equal to
                // `artificial_variable`, the constant of this row must
                // also be zero
                std.debug.assert(nearZero(row.constant));

                // find a variable to enter the basis

                var entry_variable: ?*Variable = null;

                var row_iterator = row.iterator();
                while (row_iterator.next()) |row_entry| {
                    const term = row_entry.toTerm();

                    if (term.variable.kind == .dummy)
                        continue;

                    entry_variable = term.variable;
                    break;
                }

                // If an entering variable is found, perform the pivot using
                // that variable. Otherwise, the row is either empty or
                // contains only dummy variables, so no further action is
                // needed.
                if (entry_variable) |entry| {
                    try row.solveFor(gpa, entry);
                    try self.tableau.substitute(gpa, entry, row);
                    try self.objective.substitute(gpa, entry, row);
                    try self.tableau.insert(gpa, entry, row);
                    row = .empty;
                }
            }

            // remove any occurrence of the artificial variable from the system

            var tableau_iterator = self.tableau.iterator();
            while (tableau_iterator.next()) |entry|
                 _ = entry.row.removeVariable(&artificial_variable);
            _ = self.objective.removeVariable(&artificial_variable);
        }

        try optimize(gpa, &self.tableau, &self.objective);

        try self.constraint_marker_map.putNoClobber(
            gpa,
            constraint,
            markers,
        );
        markers[0] = null;
        markers[1] = null;
    }

    pub fn removeConstraint(
        self: *System,
        gpa: std.mem.Allocator,
        constraint: *const Constraint,
    ) error{ OutOfMemory, UnknownConstraint, ConstraintMarkerNotFound, ObjectiveUnbound }!void {
        if (!self.constraint_marker_map.contains(constraint))
            return error.UnknownConstraint;

        const markers = self.constraint_marker_map.get(constraint).?;

        // remove error variable effects from the objective function
        for (markers) |marker| {
            if (marker == null or marker.?.kind != .err)
                continue;

            // here, we assume the marker error variable or its equivalent
            // substitution are all part of the objective function so the
            // following just removes these terms from the objective without
            // allocating new memory. Hence, no allocator is needed and no
            // memory errors are anticipated.
            if (self.tableau.findBasis(marker.?)) |entry| {
                self.objective.insertRow(
                    undefined,
                    -constraint.strength,
                    entry.row.*,
                ) catch unreachable;
            } else {
                self.objective.insert(
                    undefined,
                    -constraint.strength,
                    marker.?,
                ) catch unreachable;
            }
        }

        std.debug.assert(markers[0] != null);
        const marker = markers[0].?;

        // if the marker is already in the basis, just drop that row
        if (self.tableau.findBasis(marker)) |entry| {
            entry.row.deinit(gpa);
            self.tableau.removeEntry(entry);
        }
        // otherwise determine the most restrictive row with the marker
        // variable to be dropped
        else {
            var min_ratio:   [2]f32            = undefined;
            var candidates:  [3]?Tableau.Entry = .{ null, null, null };

            min_ratio[0] = std.math.floatMax(f32);
            min_ratio[1] = std.math.floatMax(f32);

            var tableau_iterator = self.tableau.iterator();
            while (tableau_iterator.next()) |entry| {
                const basis = entry.basis;
                const row   = entry.row;

                if (basis.kind == .external) {
                    candidates[2] = entry;
                    continue;
                }

                const constant    = row.constant;
                const coefficient = row.coefficientOf(marker);

                if (coefficient == 0.0)
                    continue;

                if (coefficient < 0.0) {
                    const ratio = -constant / coefficient;
                    if (ratio < min_ratio[0]) {
                         min_ratio[0] = ratio;
                        candidates[0] = entry;
                    }
                    continue;
                }

                if (coefficient > 0.0) {
                    const ratio = constant / coefficient;
                    if (ratio < min_ratio[1]) {
                         min_ratio[1] = ratio;
                        candidates[1] = entry;
                    }
                    continue;
                }
            }

            const leaving_entry: Tableau.Entry =
                if      (candidates[0]) |candidate| candidate
                else if (candidates[1]) |candidate| candidate
                else if (candidates[2]) |candidate| candidate
                else return error.ConstraintMarkerNotFound;

            const leaving_basis = leaving_entry.basis;
            var   leaving_row   = leaving_entry.row.*;
            defer leaving_row.deinit(gpa);

            self.tableau.removeEntry(leaving_entry);
            try leaving_row.insert(gpa, -1.0, leaving_basis);
            try leaving_row.solveFor(gpa, marker);
            try self.tableau.substitute(gpa, marker, leaving_row);
            try self.objective.substitute(gpa, marker, leaving_row);
        }

        try optimize(gpa, &self.tableau, &self.objective);

        for (markers) |_marker| {
            if (_marker == null)
                continue;
            gpa.destroy(_marker.?);
        }
        _ = self.constraint_marker_map.swapRemove(constraint);
    }

    // zig fmt: on

    pub fn refreshVariable(self: *System, variable: *Variable) void {
        if (self.tableau.findBasis(variable)) |entry|
            variable.value = entry.row.constant
        else
            variable.value = 0.0;
    }

    pub fn refreshVariables(self: *System, variables: []const *Variable) void {
        // TODO: check for system anomalies when in debug mode

        for (variables) |variable|
            self.refreshVariable(variable);
    }
};

test "System" {
    _ = System;
}

const Tableau = struct {
    const Map = std.AutoHashMapUnmanaged(*Variable, Row);

    row_map: Map = .empty,

    pub const empty = Tableau{};

    pub fn deinit(self: *Tableau, gpa: std.mem.Allocator) void {
        var tableau_iterator = self.iterator();
        while (tableau_iterator.next()) |entry|
            entry.row.deinit(gpa);
        self.row_map.deinit(gpa);
    }

    pub const Entry = struct {
        basis: *Variable,
        row: *Row,
    };

    pub fn findBasis(self: *const Tableau, basis: *Variable) ?Entry {
        if (self.row_map.getEntry(basis)) |entry| {
            return Entry{
                .basis = entry.key_ptr.*,
                .row = entry.value_ptr,
            };
        }

        return null;
    }

    pub const Iterator = struct {
        row_map_iterator: Map.Iterator,

        pub fn next(self: *Iterator) ?Entry {
            if (self.row_map_iterator.next()) |entry| {
                return Entry{
                    .basis = entry.key_ptr.*,
                    .row = entry.value_ptr,
                };
            }

            return null;
        }
    };

    pub fn iterator(self: *const Tableau) Iterator {
        return .{ .row_map_iterator = self.row_map.iterator() };
    }

    pub fn insert(
        self: *Tableau,
        gpa: std.mem.Allocator,
        basis: *Variable,
        row: Row,
    ) error{OutOfMemory}!void {
        try self.row_map.putNoClobber(gpa, basis, row);
    }

    pub fn removeEntry(self: *Tableau, entry: Entry) void {
        const removed = self.row_map.remove(entry.basis);
        std.debug.assert(removed == true);
    }

    pub fn substitute(self: *Tableau, gpa: std.mem.Allocator, variable: *Variable, row: Row) error{OutOfMemory}!void {
        var tableau_iterator = self.iterator();
        while (tableau_iterator.next()) |entry|
            try entry.row.substitute(gpa, variable, row);
    }

    pub fn equals(self: Tableau, other: Tableau) bool {
        var tableau_iterator: Tableau.Iterator = undefined;

        tableau_iterator = self.iterator();
        while (tableau_iterator.next()) |entry|
            if (!other.contains(entry))
                return false;

        tableau_iterator = other.iterator();
        while (tableau_iterator.next()) |entry|
            if (!self.contains(entry))
                return false;

        return true;
    }

    pub fn contains(self: Tableau, entry: Entry) bool {
        if (self.row_map.getPtr(entry.basis)) |row|
            return row.equals(entry.row.*);
        return false;
    }

    pub fn format(self: Tableau, writer: *std.Io.Writer) !void {
        var tableau_iterator: Tableau.Iterator = undefined;

        tableau_iterator = self.iterator();
        while (tableau_iterator.next()) |entry| {
            if (entry.basis.kind != .external) continue;
            try writer.print("{f} = {f}\n", .{ entry.basis, entry.row });
        }

        try writer.writeAll("-----\n");

        tableau_iterator = self.iterator();
        while (tableau_iterator.next()) |entry| {
            if (entry.basis.kind == .external) continue;
            try writer.print("{f} = {f}\n", .{ entry.basis, entry.row });
        }
    }
};

const Row = struct {
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
        if (nearEq(term.coefficient, 0.0)) return;

        if (self.findVariable(term.variable)) |entry| {
            entry.coefficient.* += term.coefficient;
            if (nearZero(entry.coefficient.*))
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
            if (nearZero(entry.coefficient.*))
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

        if (!nearEq(self.constant, other.constant))
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

// zig fmt: on

pub const Variable = struct {
    kind: VariableKind = .external,
    name: []const u8 = "",
    value: f32 = 0.0,

    pub fn init(name: []const u8) Variable {
        return .{ .name = name };
    }

    pub fn id(self: *const Variable) usize {
        return @intFromPtr(self);
    }

    pub fn format(self: *const Variable, writer: *std.Io.Writer) !void {
        const kind =
            switch (self.kind) {
                .invalid => "inval",
                .external => "ext",
                .slack => "slack",
                .err => "err",
                .dummy => "dummy",
            };

        try writer.print("{s}", .{kind});
        try writer.writeAll("[");
        try writer.print("id={d}", .{self.id()});
        if (self.name.len > 0) {
            try writer.print(",name={s}", .{self.name});
        }
        try writer.writeAll("]");
    }
};

pub const VariableKind = enum {
    invalid,
    external,
    slack,
    err,
    dummy,
};

pub const Term = struct {
    coefficient: f32,
    variable: *Variable,

    pub fn init(coefficient: f32, variable: *Variable) Term {
        return .{ .coefficient = coefficient, .variable = variable };
    }
};

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
        self.operator   = operator;
        self.strength   = strength;

        self.expression.constant += lhs.constant;
        for (lhs.term_list.items) |term|
            try self.expression.add(gpa, term.coefficient, term.variable);
        self.expression.constant -= rhs.constant;
        for (rhs.term_list.items) |term|
            try self.expression.sub(gpa, term.coefficient, term.variable);

        return self;
    }

    pub fn deinit(self: *Constraint, gpa: std.mem.Allocator) void {
        self.expression.deinit(gpa);
    }
};

pub const Expression = struct {
    constant:  f32 = 0.0,
    term_list: std.ArrayList(Term) = .empty,

    pub const empty = Expression{};

    pub fn deinit(self: *Expression, gpa: std.mem.Allocator) void {
        self.term_list.deinit(gpa);
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
        if (nearEq(coefficient, 0.0)) return;

        for (self.term_list.items, 0..) |*term, i| {
            if (term.variable != variable)
                continue;

            term.coefficient += coefficient;
            if (nearEq(term.coefficient, 0.0))
                _ = self.term_list.swapRemove(i);

            return;
        }

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
};

pub const Strength = struct {
    pub fn init(s: f32, m: f32, w: f32) f32 {
        const lo = @as(f32, -1000.0);
        const hi = @as(f32,  1000.0);
        var   rt = @as(f32,     0.0);

        rt += std.math.clamp(s, lo, hi) * 1000000.0;
        rt += std.math.clamp(m, lo, hi) * 1000.0;
        rt += std.math.clamp(w, lo, hi);

        return rt;
    }

    pub const required = init(1000.0, 1000.0, 1000.0);
    pub const strong   = init(1.0, 0.0, 0.0);
    pub const medium   = init(0.0, 1.0, 0.0);
    pub const weak     = init(0.0, 0.0, 1.0);
};

pub const Operator = enum {
    le,
    eq,
    ge,
};

/// Performs Phase II of the standard two-phase simplex algorithm.
///
/// Given a simplex tableau that is already in a basic feasible solved form
/// this function iteratively performs pivot operations until it finds an
/// optimum.
///
/// This function assumes the tableau is already in a basic feasible solved
/// form.
fn optimize(
    gpa: std.mem.Allocator,
    tableau: *Tableau,
    objective: *Row,
) error{ OutOfMemory, ObjectiveUnbound }!void {
    var min_id:    usize = undefined;
    var min_ratio: f32   = undefined;

    while (true) {
        var entry_variable: ?*Variable      = null;
        var exit_entry:     ? Tableau.Entry = null;

        // select an entry variable for the pivot operation

        min_id = std.math.maxInt(usize);

        var objective_iterator = objective.iterator();
        while (objective_iterator.next()) |entry| {
            const term = entry.toTerm();
            const coefficient = term.coefficient;
            const variable = term.variable;

            if (variable.kind == .dummy or coefficient >= 0.0)
                continue;

            // choose the lowest numbered variable to prevent cycling
            if (variable.id() < min_id) {
                min_id = variable.id();
                entry_variable = variable;
            }
        }

        // Optimum has been reached.
        if (entry_variable == null)
            break;

        // select a row that contains an exit variable needed for a pivot

        min_id    = std.math.maxInt(usize);
        min_ratio = std.math.floatMax(f32);

        var tableau_iterator = tableau.iterator();
        while (tableau_iterator.next()) |entry| {
            const basis = entry.basis;
            const row = entry.row;
            const constant = row.constant;
            const coefficient = row.coefficientOf(entry_variable.?);

            // filter out unrestricted (external) variables + restricted variables
            // that don't meet the criteria
            if (basis.kind == .external or coefficient >= 0.0) continue;

            const ratio = -constant / coefficient;

            if (ratio < min_ratio) {
                min_id = basis.id();
                min_ratio = ratio;
                exit_entry = entry;

                continue;
            }

            // choose the lowest numbered variable to prevent cycling
            if (nearEq(ratio, min_ratio) and basis.id() < min_id) {
                min_id = basis.id();
                min_ratio = ratio;
                exit_entry = entry;

                continue;
            }
        }

        if (exit_entry == null)
            return error.ObjectiveUnbound;

        // perform the pivot

        const exit_basis = exit_entry.?.basis;
        var   exit_row   = exit_entry.?.row.*;
        defer exit_row.deinit(gpa);

        tableau.removeEntry(exit_entry.?);

        try exit_row.insert(gpa, -1.0, exit_basis);
        try exit_row.solveFor(gpa, entry_variable.?);
        try tableau.substitute(gpa, entry_variable.?, exit_row);
        try objective.substitute(gpa, entry_variable.?, exit_row);
        try tableau.insert(gpa, entry_variable.?, exit_row);
        exit_row = .empty;
    }
}

test "optimize()" {
    const testFn = struct {
        pub fn testFn(gpa: std.mem.Allocator) !void {
            var   row  = @as(Row, .empty);
            defer row.deinit(gpa);

            var   actual_objective   = Row.empty;
            var   expected_objective = Row.empty;
            var   actual_tableau     = Tableau.empty;
            var   expected_tableau   = Tableau.empty;

            defer actual_objective.deinit(gpa);
            defer expected_objective.deinit(gpa);
            defer actual_tableau.deinit(gpa);
            defer expected_tableau.deinit(gpa);

            var xl: Variable = .{ .name = "xl", .kind = .external };
            var xm: Variable = .{ .name = "xm", .kind = .external };
            var xr: Variable = .{ .name = "xr", .kind = .external };
            var s1: Variable = .{ .name = "s1", .kind = .slack    };
            var s2: Variable = .{ .name = "s2", .kind = .slack    };
            var s3: Variable = .{ .name = "s3", .kind = .slack    };

            // ------------ //
            //   Expected   //
            // ------------ //

            // 5 + (1/2)s1

            expected_objective.constant = 5;
            try expected_objective.insertTerm(gpa, Term.init(0.5, &s1));

            // xl = 90 - s1 - s3

            row = .empty;
            row.constant = 90;
            try row.insertTerm(gpa, Term.init(-1.0, &s1));
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try expected_tableau.insert(gpa, &xl, row);
            row = .empty;

            // xm = 95 - (1/2)s1 - s3

            row = .empty;
            row.constant = 95;
            try row.insertTerm(gpa, Term.init(-0.5, &s1));
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try expected_tableau.insert(gpa, &xm, row);
            row = .empty;

            // xr = 100 - s3

            row = .empty;
            row.constant = 100;
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try expected_tableau.insert(gpa, &xr, row);
            row = .empty;

            // s2 = 100 - s1 - s3

            row = .empty;
            row.constant = 100;
            try row.insertTerm(gpa, Term.init(-1.0, &s1));
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try expected_tableau.insert(gpa, &s2, row);
            row = .empty;

            // ------------ //
            //  Test input  //
            // ------------ //

            // 55 - (1/2) * s2 - (1/2) * s3

            actual_objective.constant = 55;
            try actual_objective.insertTerm(gpa, Term.init(-0.5, &s2));
            try actual_objective.insertTerm(gpa, Term.init(-0.5, &s3));

            // xl = -10 + s2

            row = .empty;
            row.constant = -10;
            try row.insertTerm(gpa, Term.init(1.0, &s2));

            try actual_tableau.insert(gpa, &xl, row);
            row = .empty;

            // xm = 45 + (1/2)s2 - (1/2)s3

            row = .empty;
            row.constant = 45;
            try row.insertTerm(gpa, Term.init( 0.5, &s2));
            try row.insertTerm(gpa, Term.init(-0.5, &s3));

            try actual_tableau.insert(gpa, &xm, row);
            row = .empty;

            // xr = 100 - s3

            row = .empty;
            row.constant = 100;
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try actual_tableau.insert(gpa, &xr, row);
            row = .empty;

            // s1 = 100 - s2 - s3

            row = .empty;
            row.constant = 100;
            try row.insertTerm(gpa, Term.init(-1.0, &s2));
            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try actual_tableau.insert(gpa, &s1, row);
            row = .empty;

            //

            try optimize(gpa, &actual_tableau, &actual_objective);

            std.testing.expect(
                expected_objective.equals(actual_objective)
            ) catch |err| {
                std.debug.print("\t\n", .{});
                std.debug.print("expected objective: {f}\n", .{expected_objective});
                std.debug.print("  actual objective: {f}\n", .{  actual_objective});

                return err;
            };

            std.testing.expect(
                expected_tableau.equals(actual_tableau)
            ) catch |err| {
                std.debug.print("\t\n", .{});
                std.debug.print("expected tableau:\n{f}\n\n", .{expected_tableau});
                std.debug.print("  actual tableau:\n{f}\n",   .{actual_tableau});

                return err;
            };
        }
    }.testFn;

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testFn,
        .{},
    );
}

/// Performs the dual simplex optimization algorithm.
///
/// Given a system with an optimal but infeasible solution, this function finds
/// an optimal and feasible solution.
fn reoptimize(
    gpa: std.mem.Allocator,
    tableau: *Tableau,
    objective: *Row,
) error{ OutOfMemory, EntryVariableNotFound }!void {
    var min_id:    usize = undefined;
    var min_ratio: f32   = undefined;

    while (true) {
        var infeasible_entry: ? Tableau.Entry = null;
        var entry_variable:   ?*Variable      = null;

        // find an infeasible row

        var tableau_iterator = tableau.iterator();
        while (tableau_iterator.next()) |entry| {
            const row = entry.row;
            const basis = entry.basis;

            // row is feasible. skipping ...
            if (basis.kind == .external or row.constant >= 0.0)
                continue;

            infeasible_entry = entry;
        }

        // all rows are feasible. we're good to go
        if (infeasible_entry == null)
            return;

        // find an entry variable

        min_id    = std.math.maxInt(usize);
        min_ratio = std.math.floatMax(f32);

        var infeasible_row_iterator = infeasible_entry.?.row.iterator();
        while (infeasible_row_iterator.next()) |entry| {
            const term = entry.toTerm();
            const variable = term.variable;
            const d = objective.coefficientOf(variable);
            const a = term.coefficient;

            if (variable.kind == .dummy or a <= 0.0)
                continue;

            const ratio = d / a;

            if (ratio < min_ratio) {
                min_id = variable.id();
                min_ratio = ratio;
                entry_variable = variable;

                continue;
            }

            // choose the lowest numbered variable to prevent cycling
            if (nearEq(ratio, min_ratio) and variable.id() < min_id) {
                min_id = variable.id();
                min_ratio = ratio;
                entry_variable = variable;

                continue;
            }
        }

        // this can't be good
        if (entry_variable == null)
            return error.EntryVariableNotFound;

        // perform the pivot

        const infeasible_basis = infeasible_entry.?.basis;
        var   infeasible_row   = infeasible_entry.?.row.*;
        defer infeasible_row.deinit(gpa);

        tableau.removeEntry(infeasible_entry.?);

        try infeasible_row.insert(gpa, -1.0, infeasible_basis);
        try infeasible_row.solveFor(gpa, entry_variable.?);
        try tableau.substitute(gpa, entry_variable.?, infeasible_row);
        try objective.substitute(gpa, entry_variable.?, infeasible_row);
        try tableau.insert(gpa, entry_variable.?, infeasible_row);
        infeasible_row = .empty;
    }
}

test "reoptimize()" {
    const testFn = struct {
        pub fn testFn(gpa: std.mem.Allocator) !void {
            var   row  = @as(Row, .empty);
            defer row.deinit(gpa);

            var actual_objective   = Row.empty;
            var expected_objective = Row.empty;
            var actual_tableau     = Tableau.empty;
            var expected_tableau   = Tableau.empty;

            defer actual_objective.deinit(gpa);
            defer expected_objective.deinit(gpa);
            defer actual_tableau.deinit(gpa);
            defer expected_tableau.deinit(gpa);

            var s1:  Variable = .{ .name = "s1",  .kind = .slack    };
            var s2:  Variable = .{ .name = "s2",  .kind = .slack    };
            var s3:  Variable = .{ .name = "s3",  .kind = .slack    };

            var xl:  Variable = .{ .name = "xl",  .kind = .external };
            var xlp: Variable = .{ .name = "xlp", .kind = .err      };
            var xlm: Variable = .{ .name = "xlm", .kind = .err      };

            var xm:  Variable = .{ .name = "xm",  .kind = .external };
            var xmp: Variable = .{ .name = "xmp", .kind = .err      };
            var xmm: Variable = .{ .name = "xmm", .kind = .err      };

            var xr:  Variable = .{ .name = "xr",  .kind = .external };
            var xrp: Variable = .{ .name = "xrp", .kind = .err      };
            var xrm: Variable = .{ .name = "xrm", .kind = .err      };

            // ------------ //
            //   Expected   //
            // ------------ //

            // [0,60] + [1,2]xmp + [1,-2]xmm + [0,2]xlm + [0,2]xrm

            expected_objective.constant = Strength.init(0.0, 0.0, 60.0);

            try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), &xmp));
            try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), &xmm));
            try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xlm));
            try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xrm));

            // xm = 90 + xmp - xmm

            row = .empty;
            row.constant = 90;

            try row.insertTerm(gpa, Term.init( 1.0, &xmp));
            try row.insertTerm(gpa, Term.init(-1.0, &xmm));

            try expected_tableau.insert(gpa, &xm, row);
            row = .empty;

            // xl = 80 + s3 + 2 * xmp - 2 * xmm

            row = .empty;
            row.constant = 80;

            try row.insertTerm(gpa, Term.init( 1.0, &s3));
            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));

            try expected_tableau.insert(gpa, &xl, row);
            row = .empty;

            // xr = 100 - s3

            row = .empty;
            row.constant = 100;

            try row.insertTerm(gpa, Term.init(-1.0, &s3));

            try expected_tableau.insert(gpa, &xr, row);
            row = .empty;

            // s1 = 10 - 2 * s3 - 2 * xmp + 2 * xmm

            row = .empty;
            row.constant = 10;

            try row.insertTerm(gpa, Term.init(-2.0, &s3));
            try row.insertTerm(gpa, Term.init(-2.0, &xmp));
            try row.insertTerm(gpa, Term.init( 2.0, &xmm));

            try expected_tableau.insert(gpa, &s1, row);
            row = .empty;

            // xlp = 50 + s3 + 2 * xmp - 2 * xmm + xlm

            row = .empty;
            row.constant = 50;

            try row.insertTerm(gpa, Term.init( 1.0, &s3));
            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));
            try row.insertTerm(gpa, Term.init( 1.0, &xlm));

            try expected_tableau.insert(gpa, &xlp, row);
            row = .empty;

            // xrp = 10 - s3 + xrm

            row = .empty;
            row.constant = 10;

            try row.insertTerm(gpa, Term.init(-1.0, &s3));
            try row.insertTerm(gpa, Term.init( 1.0, &xrm));

            try expected_tableau.insert(gpa, &xrp, row);
            row = .empty;

            // s2 = 90 + s3 + 2 * xmp - 2 * xmm

            row = .empty;
            row.constant = 90;

            try row.insertTerm(gpa, Term.init( 1.0, &s3));
            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));

            try expected_tableau.insert(gpa, &s2, row);
            row = .empty;

            // ------------ //
            //  Test input  //
            // ------------ //

            // [0,60] + [1,2]xmp + [1,-2]xmm + [0,2]xl.err_mius + [0,2]xrm

            actual_objective.constant = Strength.init(0.0, 0.0, 60.0);

            try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), &xmp));
            try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), &xmm));
            try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xlm));
            try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xrm));

            // xm = 90 + xmp - xmm

            row = .empty;
            row.constant = 90;

            try row.insertTerm(gpa, Term.init( 1.0, &xmp));
            try row.insertTerm(gpa, Term.init(-1.0, &xmm));

            try actual_tableau.insert(gpa, &xm, row);
            row = .empty;

            // xl = 30 + xlp - xlm

            row = .empty;
            row.constant = 30;

            try row.insertTerm(gpa, Term.init( 1.0, &xlp));
            try row.insertTerm(gpa, Term.init(-1.0, &xlm));

            try actual_tableau.insert(gpa, &xl, row);
            row = .empty;

            // xr = 150 + 2 * xmp - 2 * xmm - xlp + xlm

            row = .empty;
            row.constant = 150;

            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));
            try row.insertTerm(gpa, Term.init(-1.0, &xlp));
            try row.insertTerm(gpa, Term.init( 1.0, &xlm));

            try actual_tableau.insert(gpa, &xr, row);
            row = .empty;

            // s1 = 110 + 2 * xmp - 2 * xmm - 2 * xlp + 2 * xlm

            row = .empty;
            row.constant = 110;

            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));
            try row.insertTerm(gpa, Term.init(-2.0, &xlp));
            try row.insertTerm(gpa, Term.init( 2.0, &xlm));

            try actual_tableau.insert(gpa, &s1, row);
            row = .empty;

            // s3 = -50 - 2 * xmp + 2 * xmm + xlp - xlm

            row = .empty;
            row.constant = -50;

            try row.insertTerm(gpa, Term.init(-2.0, &xmp));
            try row.insertTerm(gpa, Term.init( 2.0, &xmm));
            try row.insertTerm(gpa, Term.init( 1.0, &xlp));
            try row.insertTerm(gpa, Term.init(-1.0, &xlm));

            try actual_tableau.insert(gpa, &s3, row);
            row = .empty;

            // xrp = 60 + 2 * xmp - 2 * xmm - xlp + xlm + xrm

            row = .empty;
            row.constant = 60;

            try row.insertTerm(gpa, Term.init( 2.0, &xmp));
            try row.insertTerm(gpa, Term.init(-2.0, &xmm));
            try row.insertTerm(gpa, Term.init(-1.0, &xlp));
            try row.insertTerm(gpa, Term.init( 1.0, &xlm));
            try row.insertTerm(gpa, Term.init( 1.0, &xrm));

            try actual_tableau.insert(gpa, &xrp, row);
            row = .empty;

            // s2 = 40 + xlp - xlm

            row = .empty;
            row.constant = 40;

            try row.insertTerm(gpa, Term.init( 1.0, &xlp));
            try row.insertTerm(gpa, Term.init(-1.0, &xlm));

            try actual_tableau.insert(gpa, &s2, row);
            row = .empty;

            //

            try reoptimize(gpa, &actual_tableau, &actual_objective);

            std.testing.expect(
                expected_objective.equals(actual_objective)
            ) catch |err| {
                std.debug.print("\t\n", .{});
                std.debug.print("expected objective: {f}\n", .{expected_objective});
                std.debug.print("  actual objective: {f}\n", .{  actual_objective});

                return err;
            };

            std.testing.expect(
                expected_tableau.equals(actual_tableau)
            ) catch |err| {
                std.debug.print("\t\n", .{});
                std.debug.print("expected tableau:\n{f}\n\n", .{expected_tableau});
                std.debug.print("  actual tableau:\n{f}\n",   .{actual_tableau});

                return err;
            };
        }
    }.testFn;

    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testFn,
        .{},
    );
}

// zig fmt: on

/// Returns true if two floating point values are equal within `TOLERANCE`
fn nearEq(lhs: f32, rhs: f32) bool {
    return @abs(lhs - rhs) <= TOLERANCE;
}

fn nearZero(num: f32) bool {
    return nearEq(num, 0.0);
}

// zig fmt: off

const VariableStore = struct {
    map: std.StringHashMapUnmanaged(*Variable) = .empty,

    pub const empty = VariableStore{};

    pub fn deinit(self: *VariableStore, gpa: std.mem.Allocator) void {
        var iterator = self.map.valueIterator();
        while (iterator.next()) |variable| {
            gpa.free(variable.*.name);
            gpa.destroy(variable.*);
        }
        self.map.deinit(gpa);
    }

    pub fn get(self: *VariableStore, name: []const u8) ?*Variable {
        return self.map.get(name);
    }

    pub fn getOrPut(self: *VariableStore, gpa: std.mem.Allocator, name: []const u8) error{OutOfMemory}!*Variable {
        if (self.get(name)) |variable|
            return variable
        else {
            const    variable = try gpa.create(Variable);
            errdefer gpa.destroy(variable);

            variable.name  = try gpa.dupe(u8, name);
            errdefer gpa.free(variable.name);

            variable.kind  = .external;
            variable.value = undefined;

            try self.map.putNoClobber(gpa, variable.name, variable);

            return variable;
        }
    }
};

fn tokenizeConstraintString(
    gpa: std.mem.Allocator,
    constraint: []const u8,
) error{OutOfMemory}![]const u8 {
    var   array_list = std.ArrayList(u8).empty;
    defer array_list.deinit(gpa);

    for (constraint) |character|
        switch (character) {
            ' '  => continue,
            else => try array_list.append(gpa, character),
        };

    try array_list.append(gpa, 0);

    return try array_list.toOwnedSlice(gpa);
}

fn parseConstraint(
    gpa: std.mem.Allocator,
    constraint: []const u8,
    strength: f32,
    variables: *VariableStore,
) error{OutOfMemory}!*Constraint {
    var   expressions = @as([2]Expression, .{ .empty, .empty });
    defer expressions[0].deinit(gpa);
    defer expressions[1].deinit(gpa);

    var   expression  = &expressions[0];
    var   sign        = @as(f32, 1.0);
    var   relation    = @as(?u8, null);
    var   operator    = @as(Operator, undefined);
    var   coefficient = @as(f32, 0.0);
    var   name        = std.ArrayList(u8).empty;
    defer name.deinit(gpa);
    const tokens = try tokenizeConstraintString(gpa, constraint);
    defer gpa.free(tokens);

    for (tokens) |token| switch (token) {
        '<' => relation = '<',
        '>' => relation = '>',

        'a'...'z', 'A'...'Z'
            => try name.append(gpa, token),

        '0'...'9' => {
            if (name.items.len > 0)
                try name.append(gpa, token)
            else {
                const digit: f32 = @floatFromInt(token - '0');
                coefficient = coefficient * 10.0 + digit;
            }
        },

        '+', '-', '=', 0 => {
            if (name.items.len == 0) {
                expression.constant += sign * coefficient;
                coefficient = 0.0;
                sign = if (token == '-') -1.0 else 1.0;

                continue;
            }

            const k = sign * if (coefficient == 0.0) 1.0 else coefficient;
            const v = name.items;

            coefficient = 0.0;
            name.clearRetainingCapacity();
            sign = if (token == '-') -1.0 else 1.0;

            try expression.add(gpa, k, try variables.getOrPut(gpa, v));

            if (token == '=') {
                if (relation == null)
                    operator = .eq
                else if (relation != null and relation.? == '>')
                    operator = .ge
                else if (relation != null and relation.? == '<')
                    operator = .le
                else
                    unreachable;

                expression = &expressions[1];
            }
        },

        else => continue,
    };

    const    c = try gpa.create(Constraint);
    errdefer gpa.destroy(c);

    c.* = try Constraint.init(
        gpa,
        expressions[0],
        expressions[1],
        operator,
        strength,
    );

    return c;
}

const Test = struct {
    pub const Action = union(enum) {
        const Self = @This();

        log: []const u8,
        inspect,
        add:          struct { constraint: []const u8, strength: f32, unsatisfiable: bool },
        remove:       usize,
        expect_equal: struct { name: []const u8, value: f32 },

        pub fn Log(message: []const u8) Action {
            return .{ .log = message };
        }

        pub fn Inspect() Action {
            return .inspect;
        }

        pub fn Add(constraint: []const u8, strength: f32) Action {
            return .{ .add = .{ .constraint = constraint, .strength = strength, .unsatisfiable = false } };
        }

        pub fn AddUnsatisfiable(constraint: []const u8, strength: f32) Action {
            return .{ .add = .{ .constraint = constraint, .strength = strength, .unsatisfiable = true } };
        }

        pub fn Remove(index: usize) Action {
            return .{ .remove = index };
        }

        pub fn ExpectEqual(variable_name: []const u8, value: f32) Action {
            return .{ .expect_equal = .{ .name = variable_name, .value = value } };
        }
    };

    pub fn run(gpa: std.mem.Allocator, id: usize, actions: []const Action) !void {
        var   system = System.empty;
        defer system.deinit(gpa);
        var   variable_store = VariableStore.empty;
        defer variable_store.deinit(gpa);
        var   constraint_list = std.ArrayList(*Constraint).empty;
        defer {
            for (constraint_list.items) |constraint| {
                constraint.deinit(gpa);
                gpa.destroy(constraint);
            }
            constraint_list.deinit(gpa);
        }

        for (actions) |action| switch (action) {
            .log => |message|
                std.debug.print("{s}\n", .{message}),

            .inspect => {
                std.debug.print("f: {f}\n\n", .{system.objective});
                std.debug.print("{f}\n", .{system.tableau});
            },

            .add => |structure| {
                const unsatisfiable = structure.unsatisfiable;
                const constraint    = structure.constraint;
                const strength      = structure.strength;
                var   failed        = false;

                var      parsedConstraint = try parseConstraint(gpa, constraint, strength, &variable_store);
                errdefer gpa.destroy(parsedConstraint);
                errdefer parsedConstraint.deinit(gpa);

                system.addConstraint(gpa, parsedConstraint)
                    catch |err| {
                        if (unsatisfiable != true or err != error.UnsatisfiableConstraint)
                            return err;
                        failed = true;
                    };

                if (unsatisfiable == true and failed == false) {
                    std.debug.print("(test case #{d}) expected unsatisfiable constraint was satisfiable\n", .{id});
                    return error.TestExpectedUnsatisfiable;
                }

                try constraint_list.append(gpa, parsedConstraint);

                if (unsatisfiable == true)
                    break;
            },

            .remove => |index| {
                const constraint = constraint_list.orderedRemove(index);
                try system.removeConstraint(gpa, constraint);
                constraint.deinit(gpa);
                gpa.destroy(constraint);
            },

            .expect_equal => |_variable| {
                const name     = _variable.name;
                const value    = _variable.value;
                const variable = variable_store.get(name) orelse @panic("Unknown Variable");

                system.refreshVariable(variable);

                std.testing.expect(value == variable.value) catch |err| {
                    std.debug.print("\t\ntest case #{d} failed\n", .{id});
                    std.debug.print("expected: {s} = {d}\n", .{name, value});
                    std.debug.print("found:    {s} = {d}\n", .{variable.name, variable.value});

                    return err;
                };
            },
        };
    }
};

test {
    inline for(
        [_][]const Test.Action{
            // #0
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .ExpectEqual("x", 10.0),
            },

            // #1
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),

                .ExpectEqual("x", 20.0),
            },

            // #2
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .ExpectEqual("x", 30.0),
            },

            // #3
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .Remove(2),

                .ExpectEqual("x", 20.0),
            },

            // #3
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .Remove(2),
                .Remove(1),

                .ExpectEqual("x", 10.0),
            },

            // #4
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .Remove(2),
                .Remove(1),
                .Remove(0),

                .ExpectEqual("x", 0.0),
            },

            // #5
            &[_]Test.Action{
                .Add("x = 10", Strength.required),
                .AddUnsatisfiable("x >= 20", Strength.required),
            },

            // #6
            &[_]Test.Action{
                .Add("x >= 20", Strength.required),
                .AddUnsatisfiable("x = 10", Strength.required),
            },

            // #7
            &[_]Test.Action{
                .Add("x = 10", Strength.required),
                .AddUnsatisfiable("x = 30", Strength.required),
            },

            // #8
            &[_]Test.Action{
                .Add("x <= 10", Strength.required),
                .AddUnsatisfiable("x = 20", Strength.required),
            },

            // #9
            &[_]Test.Action{
                .Add("x  =  5", Strength.strong),
                .Add("x >= 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #10
            &[_]Test.Action{
                .Add("x  = 15", Strength.strong),
                .Add("x <= 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #11
            &[_]Test.Action{
                .Add("x  =  5", Strength.medium),
                .Add("x >= 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #12
            &[_]Test.Action{
                .Add("x  = 15", Strength.medium),
                .Add("x <= 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #13
            &[_]Test.Action{
                .Add("x  =  5", Strength.weak),
                .Add("x >= 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #14
            &[_]Test.Action{
                .Add("x  = 15", Strength.weak),
                .Add("x <= 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #15
            &[_]Test.Action{
                .Add("x = 15", Strength.weak),
                .Add("x = 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #16
            &[_]Test.Action{
                .Add("x = 15", Strength.medium),
                .Add("x = 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #17
            &[_]Test.Action{
                .Add("x = 15", Strength.strong),
                .Add("x = 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #18
            &[_]Test.Action{
                .Add("x  = 15", Strength.medium),
                .ExpectEqual("x", 15.0),

                .Add("x  = 10", Strength.strong),
                .ExpectEqual("x", 10.0),

                .Remove(1),
                .ExpectEqual("x", 15.0),
            },

            // #19
            &[_]Test.Action{
                .Add("x  >= 10", Strength.medium),
                .ExpectEqual("x", 10.0),

                .Add("x  >= 15", Strength.strong),
                .ExpectEqual("x", 15.0),

                .Remove(1),
                .ExpectEqual("x", 10.0),
            },

            // #20
            &[_]Test.Action{
                .Add("x  <= 15", Strength.medium),
                .ExpectEqual("x", 15.0),

                .Add("x  <= 10", Strength.strong),
                .ExpectEqual("x", 10.0),

                .Remove(1),
                .ExpectEqual("x", 15.0),
            },
        },
        0..,
    ) |actions, id| {
        var logging = false;

        for (actions) |action| {
            if (action == .log or action == .inspect)
                logging = true;
        }

        if (logging)
            try Test.run(std.testing.allocator, id,  actions)
        else
            try std.testing.checkAllAllocationFailures(
                std.testing.allocator,
                Test.run,
                .{ id, actions },
            );
    }
}
