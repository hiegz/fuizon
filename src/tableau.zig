const std = @import("std");

const Row = @import("row.zig").Row;
const Variable = @import("variable.zig").Variable;

/// Represents the internal tableau of the linear constraint system.
pub const Tableau = struct {
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

    /// Inserts a row into the tableau.
    ///
    /// The tableau takes ownership of the provided row. After insertion, the
    /// caller must not use, modify, or deinitialize the row, as the tableau
    /// now manages its memory and state.
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

    /// Replaces all occurrences of a variable in the tableau with a given row.
    ///
    /// This method iterates over every row in the tableau and substitutes the
    /// specified `variable` with the provided `row`. After this operation, the
    /// variable will no longer appear in any row
    pub fn substitute(
        self: *Tableau,
        gpa: std.mem.Allocator,
        variable: *Variable,
        row: Row,
    ) error{OutOfMemory}!void {
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
