const std = @import("std");

// zig fmt: off

/// used for comparing float values.
const  TOLERANCE = 1.0e-8;

/// assigned to new variables that are not yet assigned to a solver.
const INVALID_ID = std.math.maxInt(usize);
const   FIRST_ID = 1;

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

    pub fn rows(self: anytype) switch (@TypeOf(self)) {
               Tableau => []const Row,
              *Tableau => []Row,
        *const Tableau => []const Row,

                  else => @compileError("expected Tableau"),
    } {
        return self.row_list.items;
    }

    pub fn numberOfRows(self: Tableau) usize {
        return self.row_list.items.len;
    }

    pub fn equals(self: Tableau, other: Tableau) bool {
        for (self.rows()) |row|
            if (!other.contains(row))
                return false;

        for (other.rows()) |row|
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
        for (self.rows()) |row| {
            if (row.basis.?.kind != .external) continue;
            try writer.print("{f}\n", .{row});
        }

        try writer.writeAll("-----\n");

        for (self.rows()) |row| {
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
                if (variable.id > low_id and variable.id < min_id) {
                    min_id   = variable.id;
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
    // solver: ?*Solver = null,
    id: usize = INVALID_ID,
    kind: VariableKind = .external,
    name: []const u8 = "",
    value: f32 = 0.0,

    pub fn init(name: []const u8) Variable {
        return .{ .name = name };
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
    while (selectEnteringVariable(objective)) |entering_variable| {
        const leaving_row = try selectLeavingRow(tableau, entering_variable);
        try leaving_row.solveFor(gpa, entering_variable);
        std.debug.assert(leaving_row.basis != null);
        for (tableau.rows()) |*row| try row.substitute(gpa, leaving_row);
        try objective.substitute(gpa, leaving_row);
    }
}

/// Selects the entry variable for a pivot operation.
///
/// Returns the variable that meets the criteria. If no variable is found,
/// the optimum has been reached.
fn selectEnteringVariable(objective: *const Row) ?*Variable {
    var min_id: usize = std.math.maxInt(usize);
    var entering_variable: ?*Variable = null;

    for (objective.term_list.items) |term| {
        const coefficient = term.coefficient;
        const variable = term.variable;

        if (variable.kind == .dummy or coefficient >= 0.0)
            continue;

        // choose the lowest numbered variable to prevent cycling.
        if (variable.id < min_id) {
            min_id = variable.id;
            entering_variable = variable;
        }
    }

    return entering_variable;
}

/// Select the row that contains the exit variable for a pivot.
///
/// Returns the row that meets the criteria. If no row is found, the objective
/// function is unbounded.
fn selectLeavingRow(
    tableau: *Tableau,
    entering_variable: *const Variable,
) error{ObjectiveUnbound}!*Row {
    var min_id: usize = std.math.maxInt(usize);
    var min_ratio: f32 = std.math.floatMax(f32);
    var leaving_row: ?*Row = null;

    for (tableau.rows()) |*row| {
        const basic = row.basis.?;
        const constant = row.constant;
        const coefficient = row.coefficientOf(entering_variable);

        // filter out unrestricted (external) variables + restricted variables
        // that don't meet the criteria.
        if (basic.kind == .external or coefficient >= 0.0) continue;

        const ratio = -constant / coefficient;

        if (ratio < min_ratio) {
            min_id = basic.id;
            min_ratio = ratio;
            leaving_row = row;

            continue;
        }

        // choose the lowest numbered variable to prevent cycling.
        if (nearEq(ratio, min_ratio) and basic.id < min_id) {
            min_id = basic.id;
            min_ratio = ratio;
            leaving_row = row;

            continue;
        }
    }

    if (leaving_row == null)
        return error.ObjectiveUnbound;
    return leaving_row.?;
}

// zig fmt: off

test "optimize()" {
    const inc = struct {
        pub fn function(n: *usize) usize {
            defer  n.* += 1;
            return n.*;
        }
    }.function;

    const gpa  = std.testing.allocator;
    var   tick = @as(usize, FIRST_ID);
    var   row  = @as(*Row, undefined);

    var   actual_objective   = Row.empty;
    var   expected_objective = Row.empty;
    var   actual_tableau     = Tableau.empty;
    var   expected_tableau   = Tableau.empty;

    defer actual_objective.deinit(gpa);
    defer expected_objective.deinit(gpa);
    defer actual_tableau.deinit(gpa);
    defer expected_tableau.deinit(gpa);

    var xl: Variable = .{ .name = "xl", .kind = .external, .id = inc(&tick) };
    var xm: Variable = .{ .name = "xm", .kind = .external, .id = inc(&tick) };
    var xr: Variable = .{ .name = "xr", .kind = .external, .id = inc(&tick) };
    var s1: Variable = .{ .name = "s1", .kind = .slack,    .id = inc(&tick) };
    var s2: Variable = .{ .name = "s2", .kind = .slack,    .id = inc(&tick) };
    var s3: Variable = .{ .name = "s3", .kind = .slack,    .id = inc(&tick) };

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

// zig fmt: on

/// Returns true if two floating point values are equal within `TOLERANCE`
fn nearEq(lhs: f32, rhs: f32) bool {
    return @abs(lhs - rhs) <= TOLERANCE;
}
