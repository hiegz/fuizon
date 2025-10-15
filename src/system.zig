//! Implementation of The Cassowary Linear Arithmetic Constraint Solving Algorithm
//!
//! Authors of the Algorithm:
//!   - Greg J. Badros
//!   - Alan Borning, University of Washington
//!   - Peter J. Stuckey, University of Melbourne
//!
//! For a deeper understanding of the algorithm, refer to the original paper:
//!   - https://constraints.cs.washington.edu/solvers/cassowary-tochi.pdf

const std = @import("std");
const float32 = @import("float32.zig");

const Tableau = @import("tableau.zig").Tableau;
const Constraint = @import("constraint.zig").Constraint;
const Expression = @import("expression.zig").Expression;
const Row = @import("row.zig").Row;
const Variable = @import("variable.zig").Variable;
const Term = @import("term.zig").Term;
const Operator = @import("operator.zig").Operator;
const Strength = @import("strength.zig").Strength;

// zig fmt: off

/// Linear Constraint System
///
/// This struct manages a set of linear constraints and variables optimized for
/// efficient incremental addition and removal of linear constraints.
pub const System = struct {
    tableau:   Tableau    = .empty,
    objective: Expression = .empty,

    /// Maps constraint ids to their markers
    ///
    /// If constraint is an inequality, then the first marker is always a slack
    /// variable. The second marker is an error variable when the constraint is
    /// also non-required.
    ///
    /// If constraint is an equation, then the markers are plus and minus error
    /// variables when the constraint is also non-required. For required
    /// equality constraints, the first marker is a "dummy" variable.
    constraint_marker_map: std.AutoArrayHashMapUnmanaged(usize, ConstraintInfo) = .empty,

    const ConstraintInfo = struct {
        strength: f32,
        markers: [2]?*Variable,
    };

    pub const empty = System{};

    /// Releases all memory allocated by the system.
    ///
    /// This function frees any internal data structures and memory
    /// used by the System. After calling `deinit`, the `System` instance
    /// must not be used unless re-initialized.
    pub fn deinit(self: *System, gpa: std.mem.Allocator) void {
        self.tableau.deinit(gpa);
        self.objective.deinit(gpa);

        var marker_it = self.constraint_marker_map.iterator();
        while (marker_it.next()) |entry| {
            const info = entry.value_ptr.*;
            const id = entry.key_ptr.*;
            gpa.destroy(@as(*u8, @ptrFromInt(id)));
            const markers = info.markers;
            for (markers) |marker| {
                if (marker == null)
                    continue;
                gpa.destroy(marker.?);
            }
        }
        self.constraint_marker_map.deinit(gpa);
    }

    /// Adds a constraint to the system.
    ///
    /// Returns a constraint id that can be used to remove it from the system.
    ///
    /// If the constraint cannot be satisfied given the current state of the
    /// system, it returns `error.UnsatisfiableConstraint`. Other error values
    /// indicate internal system failures.
    pub fn addConstraint(
        self: *System,
        gpa: std.mem.Allocator,
        constraint: Constraint,
    ) error{ OutOfMemory, UnsatisfiableConstraint, ObjectiveUnbound }!usize {
        // Too lazy to make a real ID allocator, so I just grab a byte of
        // memory and use its address as the ID.
        const    id_address = try gpa.create(u8);
        errdefer gpa.destroy(id_address);
        const id = @intFromPtr(id_address);

        var   expression    = try constraint.lhs.clone(gpa);
        defer expression.deinit(gpa);
        try   expression.insertExpression(gpa, -1.0, constraint.rhs);
        var   markers       = @as([2]?*Variable, .{ null, null });
        var   row_iterator  = @as(Tableau.RowIterator, undefined);
        var   term_iterator = @as(Expression.TermIterator, undefined);

        defer if (markers[0]) |marker| gpa.destroy(marker);
        defer if (markers[1]) |marker| gpa.destroy(marker);

        // use the current tableau to substitute out all the basic variables
        row_iterator = self.tableau.rowIterator();
        while (row_iterator.next()) |row_entry|
            try expression.substitute(gpa, row_entry.basis(), row_entry.expression.*);

        // add slack and error variables
        switch (constraint.operator) {
            .le, .ge => {
                const coefficient: f32 = switch (constraint.operator) { .le => 1.0, .ge => -1.0, .eq => unreachable };

                const slack = try gpa.create(Variable);
                slack.name  = "";
                slack.kind  = .slack;

                markers[0] = slack;

                try expression.insert(gpa, coefficient, slack);

                if (constraint.strength < Strength.required) {
                    const err = try gpa.create(Variable);
                    err.name  = "";
                    err.kind  = .err;

                    markers[1] = err;

                    try expression.insert(gpa, -coefficient, err);
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

                    try expression.insert(gpa, 1.0, dummy);

                    break :this;
                }

                const err_plus  = try gpa.create(Variable);
                err_plus.name   = "";
                err_plus.kind   = .err;

                markers[0] = err_plus;

                try expression.insert(gpa, -1.0, err_plus);
                try self.objective.insert(gpa, constraint.strength, err_plus);

                const err_minus = try gpa.create(Variable);
                err_minus.name  = "";
                err_minus.kind  = .err;

                markers[1] = err_minus;

                try expression.insert(gpa, 1.0, err_minus);
                try self.objective.insert(gpa, constraint.strength, err_minus);
            },
        }

        // multiply the entire row with -1 so that the constant becomes
        // non-negative.
        //
        // this is possible because the row is of the form l = 0
        if (expression.constant < 0.0 and !float32.nearZero(expression.constant))
            expression.multiply(-1);

        // choose the subject to enter the basis

        var subject: ?*Variable = null;

        // this block chooses a subject variable which is either an external
        // variable or a new negative slack/error variable.
        //
        // the chosen subject will be assigned to `subject`. Otherwise,
        // `subject` is null.
        selection: {
            term_iterator = expression.termIterator();

            while (term_iterator.next()) |term_entry| {
                const variable = term_entry.variable();

                if (variable.kind != .external)
                    continue;

                subject = variable;

                break :selection;
            }

            for (markers) |marker| {
                if  (marker == null) continue;
                if ((marker.?.kind == .slack or marker.?.kind == .err) and
                    expression.getCoefficientFor(marker.?) < 0.0)
                {
                    subject = marker.?;
                    break :selection;
                }
            }
        }

        if (subject != null) {
            try expression.solveFor(gpa, subject.?);
            try self.tableau.substitute(gpa, subject.?, expression);
            try self.objective.substitute(gpa, subject.?, expression);
            try self.tableau.insert(gpa, subject.?, expression);
            expression.release();
        }

        // no subject was found, use an artificial variable
        else {
            var artificial_variable: Variable = undefined;
            artificial_variable.name = "";
            artificial_variable.kind = .slack;

            var artificial_objective = try expression.clone(gpa);
            defer artificial_objective.deinit(gpa);

            try self.tableau.insert(gpa, &artificial_variable, expression);
            expression.release();

            try optimize(gpa, &self.tableau, &artificial_objective);
            if (!float32.nearZero(artificial_objective.constant))
                return error.UnsatisfiableConstraint;

            // artificial variable is basic
            if (self.tableau.find(&artificial_variable)) |row_entry| {
                expression = self.tableau.fetchRemove(row_entry).expression;
                defer expression.deinit(gpa);
                defer expression.release();

                // since we were able to achieve a value of zero for our
                // artificial objective function which is equal to
                // `artificial_variable`, the constant of this row must
                // also be zero
                std.debug.assert(float32.nearZero(expression.constant));

                // find a variable to enter the basis

                var entry_variable: ?*Variable = null;

                term_iterator = expression.termIterator();
                while (term_iterator.next()) |term_entry| {
                    const variable = term_entry.variable();

                    if (variable.kind == .dummy)
                        continue;

                    entry_variable = variable;

                    break;
                }

                // If an entering variable is found, perform the pivot using
                // that variable. Otherwise, the row is either empty or
                // contains only dummy variables, so no further action is
                // needed.
                if (entry_variable) |entry| {
                    try expression.solveFor(gpa, entry);
                    try self.tableau.substitute(gpa, entry, expression);
                    try self.objective.substitute(gpa, entry, expression);
                    try self.tableau.insert(gpa, entry, expression);
                    expression.release();
                }
            }

            // remove any occurrence of the artificial variable from the system

            var tableau_iterator = self.tableau.rowIterator();
            while (tableau_iterator.next()) |row_entry|
                if (row_entry.expression.find(&artificial_variable)) |term_entry|
                    row_entry.expression.remove(term_entry);

            if (self.objective.find(&artificial_variable)) |term_entry|
                self.objective.remove(term_entry);
        }

        try optimize(gpa, &self.tableau, &self.objective);

        try self.constraint_marker_map.putNoClobber(
            gpa,
            id,
            .{ .strength = constraint.strength, .markers = markers },
        );
        markers[0] = null;
        markers[1] = null;

        return id;
    }

    /// Removes a constraint with the given id from the system.
    ///
    /// If the constraint is not in the system, this function returns
    /// `error.UnknownConstraint`. Other error values indicate internal system
    /// failures.
    pub fn removeConstraint(
        self: *System,
        gpa: std.mem.Allocator,
        id: usize,
    ) error{ OutOfMemory, UnknownConstraint, ConstraintMarkerNotFound, ObjectiveUnbound }!void {
        const info = self.constraint_marker_map.get(id) orelse @panic("no constraint with the provided id");
        const strength = info.strength;
        const markers = info.markers;

        // remove error variable effects from the objective function
        for (markers) |marker| {
            if (marker == null or marker.?.kind != .err)
                continue;

            // here, we assume the marker error variable or its equivalent
            // substitution are all part of the objective function so the
            // following just removes these terms from the objective without
            // allocating new memory. Hence, no allocator is needed and no
            // memory errors are anticipated.
            if (self.tableau.find(marker.?)) |row| {
                self.objective.insertExpression(
                    undefined,
                    -strength,
                    row.expression.*,
                ) catch unreachable;
            } else {
                self.objective.insert(
                    undefined,
                    -strength,
                    marker.?,
                ) catch unreachable;
            }
        }

        std.debug.assert(markers[0] != null);
        const marker = markers[0].?;

        // if the marker is already in the basis, just drop that row
        if (self.tableau.find(marker)) |row|
            self.tableau.remove(gpa, row)

        // otherwise determine the most restrictive row with the marker
        // variable to be dropped
        else {
            var min_ratio:   [2]f32            = undefined;
            var candidates:  [3]?Tableau.RowEntry = .{ null, null, null };

            min_ratio[0] = std.math.floatMax(f32);
            min_ratio[1] = std.math.floatMax(f32);

            var row_iterator = self.tableau.rowIterator();
            while (row_iterator.next()) |row| {
                const basis      = row.basis();
                const expression = row.expression;

                const constant    = expression.constant;
                const coefficient = expression.getCoefficientFor(marker);

                if (coefficient == 0.0)
                    continue;

                if (basis.kind == .external) {
                    candidates[2] = row;
                    continue;
                }

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

            const exit_row: Tableau.RowEntry =
                if      (candidates[0]) |candidate| candidate
                else if (candidates[1]) |candidate| candidate
                else if (candidates[2]) |candidate| candidate
                else return error.ConstraintMarkerNotFound;

            var   row = self.tableau.fetchRemove(exit_row);
            defer row.deinit(gpa);

            try row.solveFor(gpa, marker);
            try self.tableau.substitute(gpa, row.basis, row.expression);
            try self.objective.substitute(gpa, row.basis, row.expression);
        }

        try optimize(gpa, &self.tableau, &self.objective);

        for (markers) |_marker| {
            if (_marker == null)
                continue;
            gpa.destroy(_marker.?);
        }
        _ = self.constraint_marker_map.swapRemove(id);
        gpa.destroy(@as(*u8, @ptrFromInt(id)));
    }

    // zig fmt: on

    /// Updates the value of a given variable to reflect the current state of
    /// the system.
    ///
    /// In debug builds, additional checks may be added to detect anomalies or
    /// inconsistencies in the system.
    pub fn refreshVariable(self: System, variable: *Variable) void {
        // TODO: check for system anomalies when in debug mode

        if (self.tableau.find(variable)) |entry|
            variable.value = entry.expression.constant
        else
            variable.value = 0.0;
    }

    /// Updates the values of a given set of variables to reflect the current
    /// state of the system.
    ///
    /// In debug builds, additional checks may be added to detect anomalies or
    /// inconsistencies in the system.
    pub fn refreshVariables(self: System, variables: []const *Variable) void {
        for (variables) |variable|
            self.refreshVariable(variable);
    }
};

test "System" {
    _ = System;
}

// zig fmt: off

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
    objective: *Expression,
) error{ OutOfMemory, ObjectiveUnbound }!void {
    var min_id:    usize = undefined;
    var min_ratio: f32   = undefined;

    while (true) {
        var entry_variable: ?*Variable         = null;
        var exit_entry:     ? Tableau.RowEntry = null;

        // select an entry variable for the pivot operation

        min_id = std.math.maxInt(usize);

        var term_iterator = objective.termIterator();
        while (term_iterator.next()) |term_entry| {
            const coefficient = term_entry.coefficient();
            const variable    = term_entry.variable();

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

        var row_iterator = tableau.rowIterator();
        while (row_iterator.next()) |row_entry| {
            const basis       = row_entry.basis();
            const expression  = row_entry.expression;
            const constant    = row_entry.expression.constant;
            const coefficient = expression.getCoefficientFor(entry_variable.?);

            // filter out unrestricted (external) variables + restricted variables
            // that don't meet the criteria
            if (basis.kind == .external or coefficient >= 0.0) continue;

            const ratio = -constant / coefficient;

            if (ratio < min_ratio) {
                min_id = basis.id();
                min_ratio = ratio;
                exit_entry = row_entry;

                continue;
            }

            // choose the lowest numbered variable to prevent cycling
            if (float32.nearEq(ratio, min_ratio) and basis.id() < min_id) {
                min_id = basis.id();
                min_ratio = ratio;
                exit_entry = row_entry;

                continue;
            }
        }

        if (exit_entry == null)
            return error.ObjectiveUnbound;

        // perform the pivot

        var   row = tableau.fetchRemove(exit_entry.?);
        defer row.deinit(gpa);

        try row.solveFor(gpa, entry_variable.?);
        try tableau.substitute(gpa, row.basis, row.expression);
        try objective.substitute(gpa, row.basis, row.expression);
        try tableau.insertRow(gpa, row);
        row.release();
    }
}

test "optimize()" {
    const testFn = struct {
        pub fn testFn(gpa: std.mem.Allocator) !void {
            var   row  = @as(Row, .empty);
            defer row.deinit(gpa);

            var   actual_objective   = Expression.empty;
            var   expected_objective = Expression.empty;
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
            try expected_objective.insert(gpa, 0.5, &s1);

            // xl = 90 - s1 - s3

            row.basis = &xl;
            row.expression.constant = 90;

            try row.expression.insert(gpa, -1.0, &s1);
            try row.expression.insert(gpa, -1.0, &s3);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xm = 95 - (1/2)s1 - s3

            row.basis = &xm;
            row.expression.constant = 95;

            try row.expression.insert(gpa, -0.5, &s1);
            try row.expression.insert(gpa, -1.0, &s3);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xr = 100 - s3

            row.basis = &xr;
            row.expression.constant = 100;

            try row.expression.insert(gpa, -1.0, &s3);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // s2 = 100 - s1 - s3

            row.basis = &s2;
            row.expression.constant = 100;

            try row.expression.insert(gpa, -1.0, &s1);
            try row.expression.insert(gpa, -1.0, &s3);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // ------------ //
            //  Test input  //
            // ------------ //

            // 55 - (1/2) * s2 - (1/2) * s3

            actual_objective.constant = 55;

            try actual_objective.insert(gpa, -0.5, &s2);
            try actual_objective.insert(gpa, -0.5, &s3);

            // xl = -10 + s2

            row.basis = &xl;
            row.expression.constant = -10;

            try row.expression.insert(gpa, 1.0, &s2);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // xm = 45 + (1/2)s2 - (1/2)s3

            row.basis = &xm;
            row.expression.constant = 45;

            try row.expression.insert(gpa, 0.5, &s2);
            try row.expression.insert(gpa,-0.5, &s3);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // xr = 100 - s3

            row.basis = &xr;
            row.expression.constant = 100;

            try row.expression.insert(gpa, -1.0, &s3);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // s1 = 100 - s2 - s3

            row.basis = &s1;
            row.expression.constant = 100;

            try row.expression.insert(gpa, -1.0, &s2);
            try row.expression.insert(gpa, -1.0, &s3);

            try actual_tableau.insertRow(gpa, row);

            row.release();

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
    objective: *Expression,
) error{ OutOfMemory, EntryVariableNotFound }!void {
    var min_id:    usize = undefined;
    var min_ratio: f32   = undefined;

    while (true) {
        var infeasible_entry: ? Tableau.RowEntry = null;
        var entry_variable:   ?*Variable         = null;

        // find an infeasible row

        var row_iterator = tableau.rowIterator();
        while (row_iterator.next()) |row_entry| {
            const constant = row_entry.expression.constant;
            const basis    = row_entry.basis();

            // row is feasible. skipping ...
            if (basis.kind == .external or constant >= 0.0)
                continue;

            infeasible_entry = row_entry;
        }

        // all rows are feasible. we're good to go
        if (infeasible_entry == null)
            return;

        // find an entry variable

        min_id    = std.math.maxInt(usize);
        min_ratio = std.math.floatMax(f32);

        var term_iterator = infeasible_entry.?.expression.termIterator();
        while (term_iterator.next()) |term_entry| {
            const variable = term_entry.variable();
            const a        = term_entry.coefficient();
            const d        = objective.getCoefficientFor(variable);

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
            if (float32.nearEq(ratio, min_ratio) and variable.id() < min_id) {
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

        var   row = tableau.fetchRemove(infeasible_entry.?);
        defer row.deinit(gpa);

        try row.solveFor(gpa, entry_variable.?);
        try tableau.substitute(gpa, row.basis, row.expression);
        try objective.substitute(gpa, row.basis, row.expression);
        try tableau.insertRow(gpa, row);
        row.release();
    }
}

test "reoptimize()" {
    const testFn = struct {
        pub fn testFn(gpa: std.mem.Allocator) !void {
            var   row  = @as(Row, .empty);
            defer row.deinit(gpa);

            var actual_objective   = Expression.empty;
            var expected_objective = Expression.empty;
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

            try expected_objective.insert(gpa, Strength.init(0.0, 1.0,  2.0), &xmp);
            try expected_objective.insert(gpa, Strength.init(0.0, 1.0, -2.0), &xmm);
            try expected_objective.insert(gpa, Strength.init(0.0, 0.0,  2.0), &xlm);
            try expected_objective.insert(gpa, Strength.init(0.0, 0.0,  2.0), &xrm);

            // xm = 90 + xmp - xmm

            row.basis = &xm;
            row.expression.constant = 90;

            try row.expression.insert(gpa,  1.0, &xmp);
            try row.expression.insert(gpa, -1.0, &xmm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xl = 80 + s3 + 2 * xmp - 2 * xmm

            row.basis = &xl;
            row.expression.constant = 80;

            try row.expression.insert(gpa,  1.0, &s3);
            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xr = 100 - s3

            row.basis = &xr;
            row.expression.constant = 100;

            try row.expression.insert(gpa, -1.0, &s3);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // s1 = 10 - 2 * s3 - 2 * xmp + 2 * xmm

            row.basis = &s1;
            row.expression.constant = 10;

            try row.expression.insert(gpa, -2.0, &s3);
            try row.expression.insert(gpa, -2.0, &xmp);
            try row.expression.insert(gpa,  2.0, &xmm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xlp = 50 + s3 + 2 * xmp - 2 * xmm + xlm

            row.basis = &xlp;
            row.expression.constant = 50;

            try row.expression.insert(gpa,  1.0, &s3);
            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);
            try row.expression.insert(gpa,  1.0, &xlm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // xrp = 10 - s3 + xrm

            row.basis = &xrp;
            row.expression.constant = 10;

            try row.expression.insert(gpa, -1.0, &s3);
            try row.expression.insert(gpa,  1.0, &xrm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // s2 = 90 + s3 + 2 * xmp - 2 * xmm

            row.basis = &s2;
            row.expression.constant = 90;

            try row.expression.insert(gpa,  1.0, &s3);
            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);

            try expected_tableau.insertRow(gpa, row);

            row.release();

            // ------------ //
            //  Test input  //
            // ------------ //

            // [0,60] + [1,2]xmp + [1,-2]xmm + [0,2]xl.err_mius + [0,2]xrm

            actual_objective.constant = Strength.init(0.0, 0.0, 60.0);

            try actual_objective.insert(gpa, Strength.init(0.0, 1.0,  2.0), &xmp);
            try actual_objective.insert(gpa, Strength.init(0.0, 1.0, -2.0), &xmm);
            try actual_objective.insert(gpa, Strength.init(0.0, 0.0,  2.0), &xlm);
            try actual_objective.insert(gpa, Strength.init(0.0, 0.0,  2.0), &xrm);

            // xm = 90 + xmp - xmm

            row.basis = &xm;
            row.expression.constant = 90;

            try row.expression.insert(gpa,  1.0, &xmp);
            try row.expression.insert(gpa, -1.0, &xmm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // xl = 30 + xlp - xlm

            row.basis = &xl;
            row.expression.constant = 30;

            try row.expression.insert(gpa,  1.0, &xlp);
            try row.expression.insert(gpa, -1.0, &xlm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // xr = 150 + 2 * xmp - 2 * xmm - xlp + xlm

            row.basis = &xr;
            row.expression.constant = 150;

            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);
            try row.expression.insert(gpa, -1.0, &xlp);
            try row.expression.insert(gpa,  1.0, &xlm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // s1 = 110 + 2 * xmp - 2 * xmm - 2 * xlp + 2 * xlm

            row.basis = &s1;
            row.expression.constant = 110;

            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);
            try row.expression.insert(gpa, -2.0, &xlp);
            try row.expression.insert(gpa,  2.0, &xlm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // s3 = -50 - 2 * xmp + 2 * xmm + xlp - xlm

            row.basis = &s3;
            row.expression.constant = -50;

            try row.expression.insert(gpa, -2.0, &xmp);
            try row.expression.insert(gpa,  2.0, &xmm);
            try row.expression.insert(gpa,  1.0, &xlp);
            try row.expression.insert(gpa, -1.0, &xlm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // xrp = 60 + 2 * xmp - 2 * xmm - xlp + xlm + xrm

            row.basis = &xrp;
            row.expression.constant = 60;

            try row.expression.insert(gpa,  2.0, &xmp);
            try row.expression.insert(gpa, -2.0, &xmm);
            try row.expression.insert(gpa, -1.0, &xlp);
            try row.expression.insert(gpa,  1.0, &xlm);
            try row.expression.insert(gpa,  1.0, &xrm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

            // s2 = 40 + xlp - xlm

            row.basis = &s2;
            row.expression.constant = 40;

            try row.expression.insert(gpa,  1.0, &xlp);
            try row.expression.insert(gpa, -1.0, &xlm);

            try actual_tableau.insertRow(gpa, row);

            row.release();

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
    constraint_string: []const u8,
    strength: f32,
    variables: *VariableStore,
) error{OutOfMemory}!Constraint {
    var   constraint   = Constraint.empty;
    defer constraint.deinit(gpa);
    var   expression   = &constraint.lhs;
    var   sign         = @as(f32, 1.0);
    var   relation     = @as(?u8, null);
    var   coefficient  = @as(f32, 0.0);
    var   name         = std.ArrayList(u8).empty;
    defer name.deinit(gpa);
    const tokens = try tokenizeConstraintString(gpa, constraint_string);
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

            try expression.insert(gpa, k, try variables.getOrPut(gpa, v));

            if (token == '=') {
                if (relation == null)
                    constraint.operator = .eq
                else if (relation != null and relation.? == '>')
                    constraint.operator = .ge
                else if (relation != null and relation.? == '<')
                    constraint.operator = .le
                else
                    unreachable;

                expression = &constraint.rhs;
            }
        },

        else => continue,
    };


    constraint.strength = strength;

    defer  constraint.release();
    return constraint;
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
        var   constraint_list = std.ArrayList(usize).empty;
        defer constraint_list.deinit(gpa);

        for (actions) |action| switch (action) {
            .log => |message|
                std.debug.print("{s}\n", .{message}),

            .inspect => {
                std.debug.print("f: {f}\n\n", .{system.objective});
                std.debug.print("{f}\n", .{system.tableau});
            },

            .add => |structure| {
                const unsatisfiable     = structure.unsatisfiable;
                const constraint_string = structure.constraint;
                const strength          = structure.strength;
                var   failed            = false;
                var   constraint        = try parseConstraint(gpa, constraint_string, strength, &variable_store);
                defer constraint.deinit(gpa);
                const constraint_id =
                    system.addConstraint(gpa, constraint) catch |err| {
                        if (unsatisfiable != true or err != error.UnsatisfiableConstraint)
                            return err;
                        failed = true;
                        continue;
                    };

                if (unsatisfiable == true and failed == false) {
                    std.debug.print("(test case #{d}) expected unsatisfiable constraint was satisfiable\n", .{id});
                    return error.TestExpectedUnsatisfiable;
                }

                try constraint_list.append(gpa, constraint_id);
            },

            .remove => |index| {
                const constraint_id = constraint_list.orderedRemove(index);
                try system.removeConstraint(gpa, constraint_id);
            },

            .expect_equal => |_variable| {
                const name     = _variable.name;
                const value    = _variable.value;
                const variable = variable_store.get(name) orelse @panic("Unknown Variable");

                system.refreshVariable(variable);

                std.testing.expect(float32.nearEq(value, variable.value)) catch |err| {
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

            // #4
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .Remove(2),
                .Remove(1),

                .ExpectEqual("x", 10.0),
            },

            // #5
            &[_]Test.Action{
                .Add("x >= 10", Strength.required),
                .Add("x >= 20", Strength.required),
                .Add("x >= 30", Strength.required),

                .Remove(2),
                .Remove(1),
                .Remove(0),

                .ExpectEqual("x", 0.0),
            },

            // #6
            &[_]Test.Action{
                .Add("x = 10", Strength.required),
                .AddUnsatisfiable("x >= 20", Strength.required),
            },

            // #7
            &[_]Test.Action{
                .Add("x >= 20", Strength.required),
                .AddUnsatisfiable("x = 10", Strength.required),
            },

            // #8
            &[_]Test.Action{
                .Add("x = 10", Strength.required),
                .AddUnsatisfiable("x = 30", Strength.required),
            },

            // #9
            &[_]Test.Action{
                .Add("x <= 10", Strength.required),
                .AddUnsatisfiable("x = 20", Strength.required),
            },

            // #10
            &[_]Test.Action{
                .Add("x  =  5", Strength.strong),
                .Add("x >= 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #11
            &[_]Test.Action{
                .Add("x  = 15", Strength.strong),
                .Add("x <= 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #12
            &[_]Test.Action{
                .Add("x  =  5", Strength.medium),
                .Add("x >= 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #13
            &[_]Test.Action{
                .Add("x  = 15", Strength.medium),
                .Add("x <= 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #14
            &[_]Test.Action{
                .Add("x  =  5", Strength.weak),
                .Add("x >= 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #15
            &[_]Test.Action{
                .Add("x  = 15", Strength.weak),
                .Add("x <= 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #16
            &[_]Test.Action{
                .Add("x = 15", Strength.weak),
                .Add("x = 10", Strength.medium),

                .ExpectEqual("x", 10.0),
            },

            // #17
            &[_]Test.Action{
                .Add("x = 15", Strength.medium),
                .Add("x = 10", Strength.strong),

                .ExpectEqual("x", 10.0),
            },

            // #18
            &[_]Test.Action{
                .Add("x = 15", Strength.strong),
                .Add("x = 10", Strength.required),

                .ExpectEqual("x", 10.0),
            },

            // #19
            &[_]Test.Action{
                .Add("x  = 15", Strength.medium),
                .ExpectEqual("x", 15.0),

                .Add("x  = 10", Strength.strong),
                .ExpectEqual("x", 10.0),

                .Remove(1),
                .ExpectEqual("x", 15.0),
            },

            // #20
            &[_]Test.Action{
                .Add("x  >= 10", Strength.medium),
                .ExpectEqual("x", 10.0),

                .Add("x  >= 15", Strength.strong),
                .ExpectEqual("x", 15.0),

                .Remove(1),
                .ExpectEqual("x", 10.0),
            },

            // #21
            &[_]Test.Action{
                .Add("x  <= 15", Strength.medium),
                .ExpectEqual("x", 15.0),

                .Add("x  <= 10", Strength.strong),
                .ExpectEqual("x", 10.0),

                .Remove(1),
                .ExpectEqual("x", 15.0),
            },

            // #22
            &[_]Test.Action{
                .Add("t <= 100", Strength.required),

                .Add("x = 50", Strength.weak),
                .ExpectEqual("x", 50.0),

                .Add("y = 2x", Strength.required),
                .ExpectEqual("y", 100.0),

                .Add("x + y = t", Strength.required),

                .ExpectEqual("x", 33.33333),
                .ExpectEqual("y", 66.66666),

                .Remove(0),

                .ExpectEqual("x", 50.0),
                .ExpectEqual("y", 100.0),
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
