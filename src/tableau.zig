const std = @import("std");

const Row = @import("row.zig").Row;
const RowMap = std.AutoHashMapUnmanaged(*Variable, Expression);
const Expression = @import("expression.zig").Expression;
const Variable = @import("variable.zig").Variable;

// zig fmt: off

/// Represents the internal tableau of the linear constraint system.
pub const Tableau = struct {
    row_map: RowMap = .empty,

    pub const empty = Tableau{};

    pub fn deinit(self: *Tableau, gpa: std.mem.Allocator) void {
        var tableau_iterator = self.rowIterator();
        while (tableau_iterator.next()) |row|
            row.expression.deinit(gpa);
        self.row_map.deinit(gpa);
    }

    /// Non-owning view of a row inside a Tableau's hash map. Backing memory is
    /// owned by the respective Tableau instance. The pointers must not be
    /// reassigned, but the data they reference may be modified.
    ///
    /// Insertions or removals of rows in the tableau invalidate the
    /// pointers.
    pub const RowEntry = struct {
        basis_ptr:  **Variable,
        expression:  *Expression,

        pub fn basis(self: RowEntry) *Variable {
            return self.basis_ptr.*;
        }

        pub fn fromHashMapEntry(entry: RowMap.Entry) RowEntry {
            return .{
                .basis_ptr      = entry.key_ptr,
                .expression = entry.value_ptr,
            };
        }
    };

    /// Provides an interface for iterating over rows in a tableau. Insertions
    /// and removals of rows invalidate live iterators.
    ///
    /// Insertions or removals of rows in the tableau invalidate live
    /// iterators.
    pub const RowIterator = struct {
        iterator: RowMap.Iterator,

        pub fn next(self: *RowIterator) ?RowEntry {
            if (self.iterator.next()) |entry|
                return RowEntry.fromHashMapEntry(entry);

            return null;
        }
    };

    pub fn rowIterator(self: *const Tableau) RowIterator {
        return .{ .iterator = self.row_map.iterator() };
    }

    /// Returns a non-owning view of a row (if any) with the provided variable
    /// in its basis.
    pub fn find(self: *const Tableau, basis: *Variable) ?RowEntry {
        if (self.row_map.getEntry(basis)) |entry|
            return RowEntry.fromHashMapEntry(entry);

        return null;
    }

    /// Inserts a row with the given basis and expression into the tableau.
    ///
    /// The tableau takes ownership of the expression. Using or modifying the
    /// expression after insertion leads to undefined behavior.
    pub fn insert(
        self: *Tableau,
        gpa: std.mem.Allocator,
        basis: *Variable,
        expression: Expression,
    ) error{OutOfMemory}!void {
        try self.row_map.putNoClobber(gpa, basis, expression);
    }

    /// Inserts a given row into the tableau.
    ///
    /// The tableau takes ownership of the row. Using or modifying the row
    /// after insertion leads to undefined behavior.
    pub fn insertRow(
        self: *Tableau,
        gpa: std.mem.Allocator,
        row: Row,
    ) error{OutOfMemory}!void {
        try self.insert(gpa, row.basis, row.expression);
    }

    /// Removes the row from the tableau.
    pub fn remove(self: *Tableau, gpa: std.mem.Allocator, entry: RowEntry) void {
        var row = self.fetchRemove(entry);
        row.deinit(gpa);
    }

    /// Removes the row from the tableau and returns it to the caller. The
    /// caller takes ownership of the row and is responsible for freeing its
    /// memory. The caller must use the allocator that was used with the
    /// tableau.
    pub fn fetchRemove(self: *Tableau, entry: RowEntry) Row {
        var row: Row   = undefined;
        row.basis      = entry.basis();
        row.expression = entry.expression.*;

        self.row_map.removeByPtr(entry.basis_ptr);

        return row;
    }

    /// Replaces all occurrences of a variable in the tableau with a given
    /// expression.
    ///
    /// This method iterates over every row in the tableau and substitutes the
    /// specified `variable` with the provided `expression`
    pub fn substitute(
        self: *Tableau,
        gpa: std.mem.Allocator,
        variable: *Variable,
        expression: Expression,
    ) error{OutOfMemory}!void {
        var tableau_iterator = self.rowIterator();
        while (tableau_iterator.next()) |row|
            try row.expression.substitute(gpa, variable, expression);
    }

    pub fn equals(self: Tableau, other: Tableau) bool {
        var iterator: Tableau.RowIterator = undefined;

        iterator = self.rowIterator();
        while (iterator.next()) |row_entry|
            if (!other.contains(row_entry))
                return false;

        iterator = other.rowIterator();
        while (iterator.next()) |row|
            if (!self.contains(row))
                return false;

        return true;
    }

    pub fn contains(self: Tableau, other_entry: RowEntry) bool {
        if (self.find(other_entry.basis())) |this_entry|
            return this_entry.expression.equals(other_entry.expression.*);

        return false;
    }

    pub fn format(self: Tableau, writer: *std.Io.Writer) !void {
        var iterator: Tableau.RowIterator = undefined;

        iterator = self.rowIterator();
        while (iterator.next()) |row_entry| {
            const basis = row_entry.basis();
            if (basis.kind != .external) continue;
            try writer.print("{f} = {f}\n", .{ basis, row_entry.expression });
        }

        try writer.writeAll("-----\n");

        iterator = self.rowIterator();
        while (iterator.next()) |row_entry| {
            const basis = row_entry.basis();
            if (basis.kind == .external) continue;
            try writer.print("{f} = {f}\n", .{ basis, row_entry.expression });
        }
    }
};
