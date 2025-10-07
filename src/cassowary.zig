const std = @import("std");

// zig fmt: off

/// used for comparing float values.
const TOLERANCE = 1.0e-8;

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

    pub fn numberOfRows(self: Tableau) usize {
        return self.row_list.items.len;
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
            try writer.print("{s} = ", .{basis.name});
        }

        if (self.constant != 0.0) {
            try writer.print("{d}", .{self.constant});
        }

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
            try writer.print(
                "{d} * {s}",
                .{ @abs(min_term.coefficient), min_term.variable.name },
            );
        }
    }
};

// zig fmt: on

pub const Variable = struct {
    kind: VariableKind = .external,
    name: []const u8 = "",
    value: f32 = 0.0,

    // zig fmt: off

    err_plus:  ?*Variable = null,
    err_minus: ?*Variable = null,

    // zig fmt: on

    pub fn init(name: []const u8) Variable {
        return .{ .name = name };
    }

    pub fn id(self: *const Variable) usize {
        return @intFromPtr(self);
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

pub const Expression = struct {
    pub const VarMap = std.AutoHashMap(*Variable, f32);
};

// zig fmt: off

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
            if (row.constant >= 0.0)
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

            if (a <= 0.0)
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

    xl.err_plus  = &xlp;
    xl.err_minus = &xlm;

    var xm:  Variable = .{ .name = "xm",  .kind = .external };
    var xmp: Variable = .{ .name = "xmp", .kind = .err      };
    var xmm: Variable = .{ .name = "xmm", .kind = .err      };

    xm.err_plus  = &xmp;
    xm.err_minus = &xmm;

    var xr:  Variable = .{ .name = "xr",  .kind = .external };
    var xrp: Variable = .{ .name = "xrp", .kind = .err      };
    var xrm: Variable = .{ .name = "xrm", .kind = .err      };

    xr.err_plus  = &xrp;
    xr.err_minus = &xrm;

    // ------------ //
    //   Expected   //
    // ------------ //

    // [0,60] + [1,2]xm.err_plus + [1,-2]xm.err_minus + [0,2]xl.err_minus + [0,2]xr.err_minus

    expected_objective.basis = null;
    expected_objective.constant = Strength.init(0.0, 0.0, 60.0);

    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), xm.err_plus.?));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), xm.err_minus.?));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), xl.err_minus.?));
    try expected_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), xr.err_minus.?));

    // xm = 90 + xm.err_plus - xm.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = &xm;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xm.err_minus.?));

    // xl = 80 + s3 + 2 * xm.err_plus - 2 * xm.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = &xl;
    row.constant = 80;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));

    // xr = 100 - s3

    row = try expected_tableau.addRow(gpa);

    row.basis = &xr;
    row.constant = 100;

    try row.insertTerm(gpa, Term.init(-1.0, &s3));

    // s1 = 10 - 2 * s3 - 2 * xm.err_plus + 2 * xm.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = &s1;
    row.constant = 10;

    try row.insertTerm(gpa, Term.init(-2.0, &s3));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init( 2.0, xm.err_minus.?));

    // xl.err_plus = 50 + s3 + 2 * xm.err_plus - 2 * xm.err_minus + xl.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = xl.err_plus.?;
    row.constant = 50;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));
    try row.insertTerm(gpa, Term.init( 1.0, xl.err_minus.?));

    // xr.err_plus = 10 - s3 + xr.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = xr.err_plus.?;
    row.constant = 10;

    try row.insertTerm(gpa, Term.init(-1.0, &s3));
    try row.insertTerm(gpa, Term.init( 1.0, xr.err_minus.?));

    // s2 = 90 + s3 + 2 * xm.err_plus - 2 * xm.err_minus

    row = try expected_tableau.addRow(gpa);

    row.basis = &s2;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, &s3));
    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));

    // ------------ //
    //  Test input  //
    // ------------ //

    // [0,60] + [1,2]xm.err_plus + [1,-2]xm.err_minus + [0,2]xl.err_mius + [0,2]xr.err_minus

    actual_objective.basis = null;
    actual_objective.constant = Strength.init(0.0, 0.0, 60.0);

    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0,  2.0), xm.err_plus.?));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 1.0, -2.0), xm.err_minus.?));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), xl.err_minus.?));
    try actual_objective.insertTerm(gpa, Term.init(Strength.init(0.0, 0.0,  2.0), xr.err_minus.?));

    // xm = 90 + xm.err_plus - xm.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &xm;
    row.constant = 90;

    try row.insertTerm(gpa, Term.init( 1.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xm.err_minus.?));

    // xl = 30 + xl.err_plus - xl.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &xl;
    row.constant = 30;

    try row.insertTerm(gpa, Term.init( 1.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xl.err_minus.?));

    // xr = 150 + 2 * xm.err_plus - 2 * xm.err_minus - xl.err_plus + xl.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &xr;
    row.constant = 150;

    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init( 1.0, xl.err_minus.?));

    // s1 = 110 + 2 * xm.err_plus - 2 * xm.err_minus - 2 * xl.err_plus + 2 * xl.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &s1;
    row.constant = 110;

    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init( 2.0, xl.err_minus.?));

    // s3 = -50 - 2 * xm.err_plus + 2 * xm.err_minus + xl.err_plus - xl.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &s3;
    row.constant = -50;

    try row.insertTerm(gpa, Term.init(-2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init( 2.0, xm.err_minus.?));
    try row.insertTerm(gpa, Term.init( 1.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xl.err_minus.?));

    // xr.err_plus = 60 + 2 * xm.err_plus - 2 * xm.err_minus - xl.err_plus + xl.err_minus + xr.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = xr.err_plus.?;
    row.constant = 60;

    try row.insertTerm(gpa, Term.init( 2.0, xm.err_plus.?));
    try row.insertTerm(gpa, Term.init(-2.0, xm.err_minus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init( 1.0, xl.err_minus.?));
    try row.insertTerm(gpa, Term.init( 1.0, xr.err_minus.?));

    // s2 = 40 + xl.err_plus - xl.err_minus

    row = try actual_tableau.addRow(gpa);

    row.basis = &s2;
    row.constant = 40;

    try row.insertTerm(gpa, Term.init( 1.0, xl.err_plus.?));
    try row.insertTerm(gpa, Term.init(-1.0, xl.err_minus.?));

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
