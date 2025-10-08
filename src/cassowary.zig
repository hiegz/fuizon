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

        var new_row = try self.tableau.addRow(gpa);

        // use the current tableau to substitute out all the basic variables

        new_row.constant = constraint.expression.constant;

        outer: for (constraint.expression.term_list.items) |term| {
            for (self.tableau.row_list.items) |*row| {
                if (row.basis != term.variable)
                    continue;

                try new_row.insertRow(gpa, row, term.coefficient);

                continue :outer;
            }

            // term.variable is not basic, so just insert it into the row
            try new_row.insertTerm(gpa, term);
        }

        // add slack and error variables

        try self.constraint_marker_map.putNoClobber(gpa, constraint, .{ null, null });
        const markers = self.constraint_marker_map.getPtr(constraint).?;

        switch (constraint.operator) {
            .le, .ge => {
                const coefficient: f32 = switch (constraint.operator) { .le => 1.0, .ge => -1.0, .eq => unreachable };

                const slack = try gpa.create(Variable);
                slack.name  = "";
                slack.kind  = .slack;

                markers[0] = slack;

                try new_row.insertTerm(gpa, Term.init(coefficient, slack));


                if (constraint.strength < Strength.required) {
                    const err = try gpa.create(Variable);
                    err.name  = "";
                    err.kind  = .err;

                    markers[1] = err;

                    try new_row.insertTerm(gpa, Term.init(-coefficient, err));
                    try self.objective.insertTerm(gpa, Term.init(constraint.strength, err));
                }
            },

            .eq => this: {
                // add a dummy variable to server as a marker
                if (constraint.strength == Strength.required) {
                    const dummy = try gpa.create(Variable);
                    dummy.name = "";
                    dummy.kind = .dummy;

                    markers[0] = dummy;

                    try new_row.insertTerm(gpa, Term.init(1.0, dummy));

                    break :this;
                }

                const err_plus  = try gpa.create(Variable);
                err_plus.name   = "";
                err_plus.kind   = .err;

                markers[0] = err_plus;

                try new_row.insertTerm(gpa, Term.init(-1.0, err_plus));
                try self.objective.insertTerm(gpa, Term.init(constraint.strength, err_plus));

                const err_minus = try gpa.create(Variable);
                err_minus.name  = "";
                err_minus.kind  = .err;

                markers[1] = err_minus;

                try new_row.insertTerm(gpa, Term.init(1.0, err_minus));
                try self.objective.insertTerm(gpa, Term.init(constraint.strength, err_minus));
            },
        }

        // multiply the entire row with -1 so that the constant becomes
        // non-negative.
        //
        // this is possible because the row is of the form l = 0
        if (new_row.constant < 0.0 and !nearZero(new_row.constant)) {
            new_row.constant *= -1;
            for (new_row.term_list.items) |*term|
                term.coefficient *= -1;
        }

        // choose the subject to enter the basis

        var subject: ?*Variable = null;

        // this block chooses a subject variable which is either an external
        // variable or a new negative slack/error variable.
        //
        // the chosen subject will be assigned to `subject`. Otherwise,
        // `subject` is null.
        selection: {
            for (new_row.term_list.items) |term| {
                if (term.variable.kind != .external) continue;

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
            for (self.tableau.row_list.items) |*row| try row.substitute(gpa, new_row);
            try self.objective.substitute(gpa, new_row);
        }

        // no subject was found, use an artificial variable
        else {
            var artificial_variable: Variable = undefined;
            artificial_variable.name = "";
            artificial_variable.kind = .slack;

            var artificial_objective = try new_row.clone(gpa);
            defer artificial_objective.deinit(gpa);

            new_row.basis = &artificial_variable;

            try optimize(gpa, &self.tableau, &artificial_objective);
            if (!nearZero(artificial_objective.constant))
                return error.UnsatisfiableConstraint;

            var artificial_row_index: ?usize = null;
            var artificial_row:       *Row   = undefined;

            for (self.tableau.row_list.items, 0..) |*row, i| {
                if (row.basis.? != &artificial_variable) continue;
                artificial_row = row;
                artificial_row_index = i;
                break;
            }

            // artificial variable is basic
            if (artificial_row_index) |index| {
                // since we were able to achieve a value of zero for our
                // artificial objective function which is equal to
                // `artificial_variable`, the constant of this row must
                // also be zero
                std.debug.assert(nearZero(artificial_row.constant));

                // find a variable to enter the basis

                var entry_variable: ?*Variable = null;

                for (artificial_row.term_list.items) |term| {
                    if (term.variable.kind == .dummy)
                        continue;
                    entry_variable = term.variable;
                    break;
                }

                // the row is just a = 0 (+ dummies), so it can be removed
                if (entry_variable == null) {
                    _ = self.tableau.row_list.swapRemove(index);
                }

                // perform the pivot
                else {
                    try artificial_row.solveFor(gpa, entry_variable.?);
                    for (self.tableau.row_list.items) |*row| try row.substitute(gpa, artificial_row);
                    try self.objective.substitute(gpa, artificial_row);
                }
            }

            // remove any occurrence of the artificial variable from the system

            for (self.tableau.row_list.items) |*row| {
                for (row.term_list.items, 0..) |*term, i| {
                    if (term.variable != &artificial_variable) continue;
                    _ = row.term_list.swapRemove(i);
                    break;
                }
            }

            for (self.objective.term_list.items, 0..) |*term, i| {
                if (term.variable != &artificial_variable) continue;
                _ = self.objective.term_list.swapRemove(i);
                break;
            }
        }

        try optimize(gpa, &self.tableau, &self.objective);
    }

    pub fn removeConstraint(
        self: *System,
        gpa: std.mem.Allocator,
        constraint: *const Constraint,
    ) error{ OutOfMemory, UnknownConstraint, ConstraintMarkerNotFound, ObjectiveUnbound }!void {
        if (!self.constraint_marker_map.contains(constraint))
            return error.UnknownConstraint;

        // remove error variable effects from the objective function

        const markers = self.constraint_marker_map.get(constraint).?;

        for (markers) |marker| {
            if (marker == null or marker.?.kind != .err)
                continue;

            var marked_row: ?*Row = null;

            for (self.tableau.row_list.items) |*row| {
                if (row.basis.? != marker.?)
                    continue;

                marked_row = row;

                break;
            }

            // here, we assume the marker error variable or its equivalent
            // substitution are all part of the objective function so the
            // following just removes these terms from the objective without
            // allocating new memory. Hence, no allocator is needed and no
            // memory errors are anticipated.
            if (marked_row) |row| {
                self.objective.insertRow(
                    undefined,
                    row,
                    -constraint.strength,
                ) catch unreachable;
            } else {
                self.objective.insertTerm(
                    undefined,
                    Term.init(-constraint.strength, marker.?),
                ) catch unreachable;
            }
        }

        std.debug.assert(markers[0] != null);
        const marker = markers[0].?;

        var marked_row_index: ?usize = null;

        for (self.tableau.row_list.items, 0..) |*row, i| {
            if (row.basis.? != marker)
                continue;
            marked_row_index = i;
            break;
        }

        // if the marker is already in the basis, just drop that row
        if (marked_row_index) |i| {
            var row = self.tableau.row_list.swapRemove(i);
            row.deinit(gpa);
        }
        // otherwise determine the most restrictive row with the marker
        // variable to be dropped
        else {
            var min_ratio:   [2]f32   = undefined;
            var candidates:  [3]?*Row = .{ null, null, null };

            min_ratio[0] = std.math.floatMax(f32);
            min_ratio[1] = std.math.floatMax(f32);

            for (self.tableau.row_list.items) |*row| {
                if (row.basis.?.kind == .external)
                    candidates[2] = row;

                const constant    = row.constant;
                const coefficient = row.coefficientOf(marker);

                if (coefficient == 0.0)
                    continue;

                if (coefficient < 0.0) {
                    const ratio = -constant / coefficient;
                    if (ratio < min_ratio[0]) {
                         min_ratio[0] = ratio;
                        candidates[0] = row;
                    }
                    continue;
                }

                if (coefficient > 0.0) {
                    const ratio = constant / coefficient;
                    if (ratio < min_ratio[1]) {
                         min_ratio[1] = ratio;
                        candidates[1] = row;
                    }
                    continue;
                }
            }

            const leaving_row: *Row =
                if      (candidates[0]) |candidate| candidate
                else if (candidates[1]) |candidate| candidate
                else if (candidates[2]) |candidate| candidate
                else return error.ConstraintMarkerNotFound;

            try leaving_row.solveFor(gpa, marker);
            for (self.tableau.row_list.items) |*row|
                try row.substitute(gpa, leaving_row);
            try self.objective.substitute(gpa, leaving_row);
            for (self.tableau.row_list.items, 0..) |*row, i| {
                if (row == leaving_row) {
                    _ = self.tableau.row_list.swapRemove(i);
                    row.deinit(gpa);
                    break;
                }
            }
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

    pub fn refresh(self: *System) void {
        // TODO: check for system anomalies when in debug mode

        for (self.tableau.row_list.items) |row| {
            const basis = row.basis.?;
            if (basis.kind != .external)
                continue;
            basis.value = row.constant;
        }
    }
};

test "System" {
    _ = System;
}

const Tableau = struct {
    row_list: std.ArrayList(Row) = .empty,

    pub const empty = Tableau{};

    pub fn deinit(self: *Tableau, gpa: std.mem.Allocator) void {
        for (self.row_list.items) |*row|
            row.deinit(gpa);
        self.row_list.deinit(gpa);
    }

    pub fn addRow(self: *Tableau, gpa: std.mem.Allocator) error{OutOfMemory}!*Row {
        try self.row_list.append(gpa, .empty);
        return &self.row_list.items[self.row_list.items.len - 1];
    }

    pub fn equals(self: Tableau, other: Tableau) bool {
        for (self.row_list.items) |row|
            if (!other.contains(row))
                return false;

        for (other.row_list.items) |row|
            if (!self.contains(row))
                return false;

        return true;
    }

    pub fn contains(self: Tableau, _row: Row) bool {
        for (self.row_list.items) |row| {
            if (row.equals(_row))
                return true;
        }
        return false;
    }

    pub fn format(self: Tableau, writer: *std.Io.Writer) !void {
        for (self.row_list.items) |row| {
            if (row.basis.?.kind != .external) continue;
            try writer.print("{f}\n", .{row});
        }

        try writer.writeAll("-----\n");

        for (self.row_list.items) |row| {
            if (row.basis.?.kind == .external) continue;
            try writer.print("{f}\n", .{row});
        }
    }
};

const Row = struct {
    // zig fmt: off

    basis:     ?*Variable = null,
    constant:    f32 = 0.0,
    term_list:   std.ArrayList(Term) = .empty,

    // zig fmt: on

    pub const empty = Row{};

    pub fn deinit(self: *Row, gpa: std.mem.Allocator) void {
        self.term_list.deinit(gpa);
    }

    pub fn clone(self: Row, gpa: std.mem.Allocator) error{OutOfMemory}!Row {
        var ret: Row = undefined;
        ret.basis = self.basis;
        ret.constant = self.constant;
        ret.term_list = try self.term_list.clone(gpa);
        return ret;
    }

    pub fn coefficientOf(self: Row, variable: *const Variable) f32 {
        for (self.term_list.items) |term| {
            if (term.variable != variable) continue;
            return term.coefficient;
        }
        return 0;
    }

    pub fn containsVariable(self: Row, variable: *const Variable) bool {
        return self.coefficientOf(variable) != 0.0;
    }

    pub fn containsTerm(self: Row, _term: Term) bool {
        for (self.term_list.items) |term| {
            if (term.variable != _term.variable) continue;
            if (term.coefficient != _term.coefficient)
                return false;
            return true;
        }

        return false;
    }

    pub fn insertRow(self: *Row, gpa: std.mem.Allocator, _row: *const Row, _coefficient: f32) error{OutOfMemory}!void {
        self.constant += _coefficient * _row.constant;

        for (_row.term_list.items) |term| {
            const coefficient = term.coefficient * _coefficient;
            const variable = term.variable;

            try self.insertTerm(gpa, Term.init(coefficient, variable));
        }
    }

    pub fn insertTerm(self: *Row, gpa: std.mem.Allocator, _term: Term) error{OutOfMemory}!void {
        if (nearEq(_term.coefficient, 0.0)) return;

        for (self.term_list.items, 0..) |*term, i| {
            if (term.variable != _term.variable) continue;
            term.coefficient += _term.coefficient;
            if (nearEq(term.coefficient, 0.0))
                _ = self.term_list.swapRemove(i);
            return;
        }

        // at this point, _term is not in term_list, so we simply add it.
        try self.term_list.append(gpa, _term);
    }

    pub fn substitute(
        self: *Row,
        gpa: std.mem.Allocator,
        _row: *const Row,
    ) error{OutOfMemory}!void {
        for (self.term_list.items, 0..) |term, i| {
            if (term.variable != _row.basis) continue;
            const coefficient = term.coefficient;
            _ = self.term_list.swapRemove(i);
            try self.insertRow(gpa, _row, coefficient);
            break;
        }
    }

    pub fn solveFor(self: *Row, gpa: std.mem.Allocator, variable: *Variable) error{OutOfMemory}!void {
        var coefficient: f32 = 0.0;

        for (self.term_list.items, 0..) |term, i| {
            if (term.variable != variable) continue;
            coefficient = term.coefficient;
            _ = self.term_list.swapRemove(i);
        }

        if (coefficient == 0.0)
            @panic("variable is not in the row");

        if (self.basis) |basic|
            try self.insertTerm(gpa, Term.init(-1.0, basic));
        self.basis = variable;

        coefficient = -1.0 / coefficient;

        self.constant *= coefficient;

        for (self.term_list.items) |*term|
            term.coefficient *= coefficient;

        var i = self.term_list.items.len - 1;
        while (true) : (i -= 1) {
            const term = self.term_list.items[i];

            if (nearEq(term.coefficient, 0.0))
                _ = self.term_list.swapRemove(i);

            if (i == 0)
                break;
        }
    }

    pub fn equals(self: Row, other: Row) bool {
        if (self.basis != other.basis)
            return false;

        if (!nearEq(self.constant, other.constant))
            return false;

        for (self.term_list.items) |term|
            if (!other.containsTerm(term))
                return false;

        for (other.term_list.items) |term|
            if (!self.containsTerm(term))
                return false;

        return true;
    }

    pub fn format(self: Row, writer: *std.Io.Writer) !void {
        if (self.basis) |basis| {
            try writer.print("{f} = ", .{basis});
        }

        try writer.print("{d}", .{self.constant});

        // zig fmt: off

        var low_id:   usize = 0;
        var min_id:   usize = undefined;
        var min_term: Term  = undefined;

        for (self.term_list.items) |_| {
            min_id = std.math.maxInt(usize);

            for (self.term_list.items) |term| {
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
        var entry_variable: ?*Variable = null;
        var exit_row:       ?*Row      = null;

        // select an entry variable for the pivot operation

        min_id = std.math.maxInt(usize);

        for (objective.term_list.items) |term| {
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

        for (tableau.row_list.items) |*row| {
            const basic = row.basis.?;
            const constant = row.constant;
            const coefficient = row.coefficientOf(entry_variable.?);

            // filter out unrestricted (external) variables + restricted variables
            // that don't meet the criteria
            if (basic.kind == .external or coefficient >= 0.0) continue;

            const ratio = -constant / coefficient;

            if (ratio < min_ratio) {
                min_id = basic.id();
                min_ratio = ratio;
                exit_row = row;

                continue;
            }

            // choose the lowest numbered variable to prevent cycling
            if (nearEq(ratio, min_ratio) and basic.id() < min_id) {
                min_id = basic.id();
                min_ratio = ratio;
                exit_row = row;

                continue;
            }
        }

        if (exit_row == null)
            return error.ObjectiveUnbound;

        // perform the pivot

        try exit_row.?.solveFor(gpa, entry_variable.?);
        for (tableau.row_list.items) |*row| try row.substitute(gpa, exit_row.?);
        try objective.substitute(gpa, exit_row.?);
    }
}

test "optimize()" {
    const gpa  = std.testing.allocator;
    var   row  = @as(*Row, undefined);

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

    expected_objective.basis = null;
    expected_objective.constant = 5;
    try expected_objective.insertTerm(gpa, Term.init(0.5, &s1));

    // xl = 90 - s1 - s3

    row = try expected_tableau.addRow(gpa);
    row.basis = &xl;
    row.constant = 90;
    try row.insertTerm(gpa, Term.init(-1.0, &s1));
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // xm = 95 - (1/2)s1 - s3

    row = try expected_tableau.addRow(gpa);
    row.basis = &xm;
    row.constant = 95;
    try row.insertTerm(gpa, Term.init(-0.5, &s1));
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // xr = 100 - s3

    row = try expected_tableau.addRow(gpa);
    row.basis = &xr;
    row.constant = 100;
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // s2 = 100 - s1 - s3

    row = try expected_tableau.addRow(gpa);
    row.basis = &s2;
    row.constant = 100;
    try row.insertTerm(gpa, Term.init(-1.0, &s1));
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // ------------ //
    //  Test input  //
    // ------------ //

    // 55 - (1/2) * s2 - (1/2) * s3

    actual_objective.basis = null;
    actual_objective.constant = 55;
    try actual_objective.insertTerm(gpa, Term.init(-0.5, &s2));
    try actual_objective.insertTerm(gpa, Term.init(-0.5, &s3));


    // xl = -10 + s2

    row = try actual_tableau.addRow(gpa);
    row.basis = &xl;
    row.constant = -10;
    try row.insertTerm(gpa, Term.init(1.0, &s2));

    // xm = 45 + (1/2)s2 - (1/2)s3

    row = try actual_tableau.addRow(gpa);
    row.basis = &xm;
    row.constant = 45;
    try row.insertTerm(gpa, Term.init( 0.5, &s2));
    try row.insertTerm(gpa, Term.init(-0.5, &s3));

    // xr = 100 - s3

    row = try actual_tableau.addRow(gpa);
    row.basis = &xr;
    row.constant = 100;
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // s1 = 100 - s2 - s3

    row = try actual_tableau.addRow(gpa);
    row.basis = &s1;
    row.constant = 100;
    try row.insertTerm(gpa, Term.init(-1.0, &s2));
    try row.insertTerm(gpa, Term.init(-1.0, &s3));

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
        var infeasible_row: ?*Row      = null;
        var entry_variable: ?*Variable = null;

        // find an infeasible row

        for (tableau.row_list.items) |*row| {
            // row is feasible. skipping ...
            if (row.basis.?.kind == .external or row.constant >= 0.0)
                continue;

            infeasible_row = row;
        }

        // all rows are feasible. we're good to go
        if (infeasible_row == null)
            return;

        // find an entry variable

        min_id    = std.math.maxInt(usize);
        min_ratio = std.math.floatMax(f32);

        for (infeasible_row.?.term_list.items) |term| {
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

        try infeasible_row.?.solveFor(gpa, entry_variable.?);
        for (tableau.row_list.items) |*row| try row.substitute(gpa, infeasible_row.?);
        try objective.substitute(gpa, infeasible_row.?);
    }
}

test "reoptimize()" {
    const gpa  = std.testing.allocator;
    var   row  = @as(*Row, undefined);

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

    expected_objective.basis = null;
    expected_objective.constant = Strength.init(0.0, 0.0, 60.0);

    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), &xmp));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), &xmm));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xlm));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xrm));

    // xm = 90 + xmp - xmm

    row = try expected_tableau.addRow(gpa);

    row.basis = &xm;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, &xmp));
    try row.insertTerm(gpa, Term.init(-1.0, &xmm));

    // xl = 80 + s3 + 2 * xmp - 2 * xmm

    row = try expected_tableau.addRow(gpa);

    row.basis = &xl;
    row.constant = 80;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));

    // xr = 100 - s3

    row = try expected_tableau.addRow(gpa);

    row.basis = &xr;
    row.constant = 100;

    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // s1 = 10 - 2 * s3 - 2 * xmp + 2 * xmm

    row = try expected_tableau.addRow(gpa);

    row.basis = &s1;
    row.constant = 10;

    try row.insertTerm(gpa, Term.init(-2.0, &s3));
    try row.insertTerm(gpa, Term.init(-2.0, &xmp));
    try row.insertTerm(gpa, Term.init( 2.0, &xmm));

    // xlp = 50 + s3 + 2 * xmp - 2 * xmm + xlm

    row = try expected_tableau.addRow(gpa);

    row.basis = &xlp;
    row.constant = 50;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));
    try row.insertTerm(gpa, Term.init( 1.0, &xlm));

    // xrp = 10 - s3 + xrm

    row = try expected_tableau.addRow(gpa);

    row.basis = &xrp;
    row.constant = 10;

    try row.insertTerm(gpa, Term.init(-1.0, &s3));
    try row.insertTerm(gpa, Term.init( 1.0, &xrm));

    // s2 = 90 + s3 + 2 * xmp - 2 * xmm

    row = try expected_tableau.addRow(gpa);

    row.basis = &s2;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));

    // ------------ //
    //  Test input  //
    // ------------ //

    // [0,60] + [1,2]xmp + [1,-2]xmm + [0,2]xl.err_mius + [0,2]xrm

    actual_objective.basis = null;
    actual_objective.constant = Strength.init(0.0, 0.0, 60.0);

    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), &xmp));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), &xmm));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xlm));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), &xrm));

    // xm = 90 + xmp - xmm

    row = try actual_tableau.addRow(gpa);

    row.basis = &xm;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, &xmp));
    try row.insertTerm(gpa, Term.init(-1.0, &xmm));

    // xl = 30 + xlp - xlm

    row = try actual_tableau.addRow(gpa);

    row.basis = &xl;
    row.constant = 30;

    try row.insertTerm(gpa, Term.init( 1.0, &xlp));
    try row.insertTerm(gpa, Term.init(-1.0, &xlm));

    // xr = 150 + 2 * xmp - 2 * xmm - xlp + xlm

    row = try actual_tableau.addRow(gpa);

    row.basis = &xr;
    row.constant = 150;

    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));
    try row.insertTerm(gpa, Term.init(-1.0, &xlp));
    try row.insertTerm(gpa, Term.init( 1.0, &xlm));

    // s1 = 110 + 2 * xmp - 2 * xmm - 2 * xlp + 2 * xlm

    row = try actual_tableau.addRow(gpa);

    row.basis = &s1;
    row.constant = 110;

    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));
    try row.insertTerm(gpa, Term.init(-2.0, &xlp));
    try row.insertTerm(gpa, Term.init( 2.0, &xlm));

    // s3 = -50 - 2 * xmp + 2 * xmm + xlp - xlm

    row = try actual_tableau.addRow(gpa);

    row.basis = &s3;
    row.constant = -50;

    try row.insertTerm(gpa, Term.init(-2.0, &xmp));
    try row.insertTerm(gpa, Term.init( 2.0, &xmm));
    try row.insertTerm(gpa, Term.init( 1.0, &xlp));
    try row.insertTerm(gpa, Term.init(-1.0, &xlm));

    // xrp = 60 + 2 * xmp - 2 * xmm - xlp + xlm + xrm

    row = try actual_tableau.addRow(gpa);

    row.basis = &xrp;
    row.constant = 60;

    try row.insertTerm(gpa, Term.init( 2.0, &xmp));
    try row.insertTerm(gpa, Term.init(-2.0, &xmm));
    try row.insertTerm(gpa, Term.init(-1.0, &xlp));
    try row.insertTerm(gpa, Term.init( 1.0, &xlm));
    try row.insertTerm(gpa, Term.init( 1.0, &xrm));

    // s2 = 40 + xlp - xlm

    row = try actual_tableau.addRow(gpa);

    row.basis = &s2;
    row.constant = 40;

    try row.insertTerm(gpa, Term.init( 1.0, &xlp));
    try row.insertTerm(gpa, Term.init(-1.0, &xlm));

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

// zig fmt: on

/// Returns true if two floating point values are equal within `TOLERANCE`
fn nearEq(lhs: f32, rhs: f32) bool {
    return @abs(lhs - rhs) <= TOLERANCE;
}

fn nearZero(num: f32) bool {
    return nearEq(num, 0.0);
}

// ------- //
//  Tests  //
// ------- //

// zig fmt: off

test {
    const gpa    = std.testing.allocator;
    var   system = System.empty;
    var   lhs    = Expression.empty;
    var   rhs    = Expression.empty;
    var   x      = Variable.init("x");

    defer system.deinit(gpa);
    defer lhs.deinit(gpa);
    defer rhs.deinit(gpa);

    // x >= 10

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 10.0;

    var   x_ge_10 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_10.deinit(gpa);

    // x >= 20

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 20.0;

    var   x_ge_20 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_20.deinit(gpa);

    // x >= 30

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 30.0;

    var   x_ge_30 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_30.deinit(gpa);

    //

    try system.addConstraint(gpa, &x_ge_10);

    system.refresh();

    try std.testing.expectEqual(10.0, x.value);

}

test {
    const gpa    = std.testing.allocator;
    var   system = System.empty;
    var   lhs    = Expression.empty;
    var   rhs    = Expression.empty;
    var   x      = Variable.init("x");

    defer system.deinit(gpa);
    defer lhs.deinit(gpa);
    defer rhs.deinit(gpa);

    // x >= 10

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 10.0;

    var   x_ge_10 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_10.deinit(gpa);

    // x >= 20

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 20.0;

    var   x_ge_20 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_20.deinit(gpa);

    // x >= 30

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 30.0;

    var   x_ge_30 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_30.deinit(gpa);

    //

    try system.addConstraint(gpa, &x_ge_10);
    try system.addConstraint(gpa, &x_ge_20);
    try system.addConstraint(gpa, &x_ge_30);

    system.refresh();

    try std.testing.expectEqual(30.0, x.value);
}

test {
    const gpa    = std.testing.allocator;
    var   system = System.empty;
    var   lhs    = Expression.empty;
    var   rhs    = Expression.empty;
    var   x      = Variable.init("x");

    defer system.deinit(gpa);
    defer lhs.deinit(gpa);
    defer rhs.deinit(gpa);

    // x >= 10

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 10.0;

    var   x_ge_10 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_10.deinit(gpa);

    // x >= 20

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 20.0;

    var   x_ge_20 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_20.deinit(gpa);

    // x >= 30

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 30.0;

    var   x_ge_30 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_30.deinit(gpa);

    //

    try system.addConstraint(gpa, &x_ge_10);
    try system.addConstraint(gpa, &x_ge_20);
    try system.addConstraint(gpa, &x_ge_30);

    try system.removeConstraint(gpa, &x_ge_30);

    system.refresh();

    try std.testing.expectEqual(20.0, x.value);
}

test {
    const gpa    = std.testing.allocator;
    var   system = System.empty;
    var   lhs    = Expression.empty;
    var   rhs    = Expression.empty;
    var   x      = Variable.init("x");

    defer system.deinit(gpa);
    defer lhs.deinit(gpa);
    defer rhs.deinit(gpa);

    // x >= 10

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 10.0;

    var   x_ge_10 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_10.deinit(gpa);

    // x >= 20

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 20.0;

    var   x_ge_20 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_20.deinit(gpa);

    // x >= 30

    lhs.clearAndRetainCapacity();
    rhs.clearAndRetainCapacity();

    try lhs.add(gpa, 1.0, &x);
    rhs.constant = 30.0;

    var   x_ge_30 = try Constraint.init(gpa, lhs, rhs, .ge, Strength.required);
    defer x_ge_30.deinit(gpa);

    //

    try system.addConstraint(gpa, &x_ge_10);
    try system.addConstraint(gpa, &x_ge_20);
    try system.addConstraint(gpa, &x_ge_30);

    try system.removeConstraint(gpa, &x_ge_20);
    try system.removeConstraint(gpa, &x_ge_30);

    system.refresh();

    try std.testing.expectEqual(10.0, x.value);
}
