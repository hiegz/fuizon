// zig fmt: off

const mod = @This();
const std = @import("std");

const Shared = @import("shared.zig").Shared;
const Strong = @import("strong.zig").Strong;
const Weak = @import("weak.zig").Weak;
const SizePolicy = @import("size_policy.zig").SizePolicy;
const System = @import("system.zig").System;
const Expression = @import("expression.zig").Expression;
const Variable = @import("variable.zig").Variable;
const Constraint = @import("constraint.zig").Constraint;
const Partition = @import("partition.zig").Partition;
const Operator = @import("operator.zig").Operator;
const Strength = @import("strength.zig").Strength;

pub const Partitioner = struct {
    system: System,

    /// The partition that will be broken into multiple other partitions stored
    /// inside `partition_list`.
    root: Partition,

    /// List of segments of the root partition.
    partition_list: std.ArrayList(Partition),

    /// Active constraint IDs.
    constraint_id_list: std.ArrayList(Strong(usize)),

    /// Initializes a new partitioner.
    pub fn init(gpa: std.mem.Allocator) error{OutOfMemory}!Partitioner {
        var self = @as(Partitioner, undefined);

        self.system = .empty;
        self.partition_list = .empty;
        self.constraint_id_list = .empty;

        errdefer self.system.deinit(gpa);
        errdefer self.deinitPartitionList(gpa);
        errdefer self.deinitConstraintList(gpa);

        const start = try Shared(Variable).init(gpa);
        defer     _ = start.deinit();
        const   end = try Shared(Variable).init(gpa);
        defer     _ = end.deinit();

        start.ref.data = Variable.init("start");
          end.ref.data = Variable.init("end");

        self.root = try Partition.init(gpa, start.clone(), end.clone());
        errdefer self.root.deinit(gpa);

        try self.setMinSize(gpa, 0);

        return self;
    }

    pub fn deinit(self: *Partitioner, gpa: std.mem.Allocator) void {
        self.system.deinit(gpa);
        self.deinitConstraintList(gpa);
        self.deinitPartitionList(gpa);
        self.root.deinit(gpa);
    }

    fn deinitPartitionList(self: *Partitioner, gpa: std.mem.Allocator) void {
        for (self.partition_list.items) |*partition|
            partition.deinit(gpa);

        self.partition_list.deinit(gpa);
    }

    fn deinitConstraintList(self: *Partitioner, gpa: std.mem.Allocator) void {
        for (self.constraint_id_list.items) |id|
            _ = id.deinit();

        self.constraint_id_list.deinit(gpa);
    }

    /// Temporary reference to a partition.
    ///
    /// Moving or modifying the managing partitioner invalidates live entries.
    pub const Entry = struct {
        partitioner: *Partitioner,
        partition:   *Partition,
        index:        usize,
        strength:     f32,

        pub fn init(
            partitioner: *Partitioner,
            partition: *Partition,
            index: usize,
            strength: f32,
        ) Entry {
            return .{
                .partitioner = partitioner,
                .partition   = partition,
                .index       = index,
                .strength    = strength,
            };
        }

        /// Updates the size policy for the partition. The auto policy has no
        /// effect.
        pub fn setSizePolicy(
            self: Entry,
            gpa: std.mem.Allocator,
            policy: SizePolicy,
        ) error{OutOfMemory}!void {
            try mod.setSizePolicy(SIZE, gpa, self, policy);
        }

        /// Updates the minimal size policy for the partition. Auto and fill
        /// policies have no effect.
        pub fn setMinSizePolicy(
            self: Entry,
            gpa: std.mem.Allocator,
            policy: SizePolicy,
        ) error{OutOfMemory}!void {
            const actual_policy: SizePolicy =
                switch (policy) {
                    .auto, .fill => .Fixed(0),
                    else => policy,
                };

            try mod.setSizePolicy(MIN, gpa, self, actual_policy);
        }

        /// Updates the maximal size policy for the partition. Auto and fill
        /// policies have no effect.
        pub fn setMaxSizePolicy(
            self: Entry,
            gpa: std.mem.Allocator,
            policy: SizePolicy,
        ) error{OutOfMemory}!void {
            const actual_policy =
                switch (policy) {
                    .fill => .auto,
                    else => policy,
                };

            try mod.setSizePolicy(MAX, gpa, self, actual_policy);
        }

        pub fn previous(self: Entry) ?Entry {
            if (self.index == 0)
                return null;

            return self.partitioner.at(self.index - 1);
        }

        pub fn next(self: Entry) ?Entry {
            if (self.index == self.partitioner.length() - 1)
                return null;

            return self.partitioner.at(self.index + 1);
        }

        pub fn size(self: Entry) u16 {
            self.partitioner.system.refreshVariables(&.{
                &self.partition.start.ref.data,
                &self.partition.end.ref.data,
            });

            const start = @round(self.partition.start.ref.data.value);
            const end   = @round(self.partition.end.ref.data.value);

            return @intFromFloat(end - start);
        }

    };

    /// Interface for iterating over partitions.
    ///
    /// Modifying the partitioner invalidates live iterators and entries.
    pub const Iterator = struct {
        partitioner: *Partitioner,
        index: usize,

        pub fn next(self: *Iterator) ?Entry {
            if (self.index == self.partitioner.length())
                return null;

            defer  self.index += 1;
            return self.partitioner.at(self.index);
        }
    };

    pub fn iterator(self: *Partitioner) Iterator {
        return .{ .partitioner = self, .index = 0 };
    }

    /// Returns a pointer to the partition with the given index.
    ///
    /// The pointer becomes invalid if the managing partitioner is modified.
    pub fn at(self: *Partitioner, index: usize) Entry {
        if (index >= self.length())
            @panic("index out of bounds");

        return Entry.init(self, &self.partition_list.items[index], index, 0.0);
    }

    /// Returns a pointer to the first partition. Asserts that the
    /// partitioner is not empty.
    ///
    /// The pointer becomes invalid if the managing partitioner is modified.
    pub fn first(self: *Partitioner) Entry {
        if (self.empty())
            @panic("partitioner is empty");

        return self.at(0);
    }

    /// Returns a pointer to the last partition. Asserts that the
    /// partitioner is not empty.
    ///
    /// The pointer becomes invalid if the managing partitioner is modified.
    pub fn last(self: *Partitioner) Entry {
        if (self.empty())
            @panic("partitioner is empty");

        return self.at(self.length() - 1);
    }

    /// Returns the number of partitions inside the partitioner.
    pub fn length(self: Partitioner) usize {
        return self.partition_list.items.len;
    }

    /// Returns true if the partitioner does not contain any partitions.
    pub fn empty(self: Partitioner) bool {
        return self.length() == 0;
    }

    /// Returns the total size of the partitioner.
    pub fn size(self: Partitioner) u16 {
        self.system.refreshVariables(&.{
            &self.root.start.ref.data,
            &self.root.end.ref.data,
        });

        const start = @round(self.root.start.ref.data.value);
        const end   = @round(self.root.end.ref.data.value);

        return @intFromFloat(end - start);
    }

    /// Sets the total size of the partitioner. Partitions will add up to the
    /// specified value.
    pub fn setSize(
        self: *Partitioner,
        gpa: std.mem.Allocator,
        value: u16,
    ) error{OutOfMemory}!void {
        try Entry
            .init(self, &self.root, undefined, 100.0)
            .setSizePolicy(gpa, .Fixed(value));
    }

    /// Sets the minimal size of the partitioner. Partitions will add up to at
    /// least the specified value.
    pub fn setMinSize(
        self: *Partitioner,
        gpa: std.mem.Allocator,
        value: u16,
    ) error{OutOfMemory}!void {
        try Entry
            .init(self, &self.root, undefined, 100.0)
            .setMinSizePolicy(gpa, .Fixed(value));
    }

    /// Sets the maximum size of the partitioner. Partitions will add up to at
    /// most the specified value.
    pub fn setMaxSize(
        self: *Partitioner,
        gpa: std.mem.Allocator,
        value: u16,
    ) error{OutOfMemory}!void {
        try Entry
            .init(self, &self.root, undefined, 100.0)
            .setMaxSizePolicy(gpa, .Fixed(value));
    }

    /// Inserts a new partition at the given index. The partition can be
    /// retrieved with `at(index)`.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn insert(
        self: *Partitioner,
        gpa: std.mem.Allocator,
        index: usize,
    ) error{OutOfMemory}!void {
        if (index > self.length())
            @panic("out of bounds");

        if (index == self.length())
            return self.append(gpa);

        const end = try Shared(Variable).init(gpa);
        defer _ = end.deinit();
        end.ref.data = Variable.init("");

        // i for index
        // s for start
        // e for end
        // digits for point ids

        //    i - 1       i              i - 1          i
        // • ——————— • ——————— •  —>  • ——————— •  • ——————— •
        // 1         s         3      1         s  e         3
        const old   = self.at(index);
        const start = old.partition.start;
        try releaseSizePolicies(gpa, old);
        try old.partition.setStart(gpa, end.clone());
        try applySizePolicies(gpa, old);

        //    i - 1          i              i - 1      new        i
        // • ——————— •  • ——————— •  ->  • ——————— • ——————— • ——————— •
        // 1         s  e         3      1         s         e         3
        var new: ?Partition = try Partition.init(gpa, start.clone(), end.clone());
        defer if (new) |*some| some.deinit(gpa);
        try self.partition_list.insert(gpa, index, new.?);
        new = null;

        try self.at(index).setMinSizePolicy(gpa, .Fixed(0));
    }

    /// Appens a new partition. The partition can be retrieved with `last()`.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn append(
        self: *Partitioner,
        gpa: std.mem.Allocator
    ) error{OutOfMemory}!void {
        if (self.length() == 0) {
            var new: ?Partition = try Partition.init(gpa, self.root.start.clone(), self.root.end.clone());
            defer if (new) |*some| some.deinit(gpa);
            try self.partition_list.append(gpa, new.?);
            new = null;

            try self.first().setMinSizePolicy(gpa, .Fixed(0));

            return;
        }

        const point = try Shared(Variable).init(gpa);
        defer _ = point.deinit();
        point.ref.data = Variable.init("");

        // p for point
        // e for end
        //
        // digits for point ids

        //     old              old
        // • ——————— •  —>  • ——————— •  •
        // 1         e      1         p  e
        const old = self.last();
        try releaseSizePolicies(gpa, old);
        try old.partition.setEnd(gpa, point.clone());
        try applySizePolicies(gpa, old);

        //     old                 old       new
        // • ——————— •  •  ->  • ——————— • ——————— •
        // 1         p  e      1         p         e
        var new: ?Partition = try Partition.init(gpa, point.clone(), self.root.end.clone());
        defer if (new) |*some| some.deinit(gpa);
        try self.partition_list.append(gpa, new.?);
        new = null;

        try self.last().setMinSizePolicy(gpa, .Fixed(0));
    }

    /// Appens a new partition. The partition can be retrieved with `first()`.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn prepend(
        self: *Partitioner,
        gpa: std.mem.Allocator,
    ) error{OutOfMemory}!void {
         try self.insert(gpa, 0);
    }

    /// Removes the partition at a given index.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn remove(
        self: *Partitioner,
        gpa: std.mem.Allocator,
        index: usize,
    ) error{OutOfMemory}!void {
        if (index >= self.length())
            @panic("out of bounds");

        if (index == 0)
            return self.removeFirst(gpa);

        const current  = self.at(index);
        const previous = current.previous().?;

        try releaseSizePolicies(gpa, current);
        try releaseSizePolicies(gpa, previous);
        try previous.partition.setEnd(gpa, current.partition.end);
        try applySizePolicies(gpa, previous);

        current.partition.deinit(gpa);
        _ = self.partition_list.orderedRemove(index);
    }

    /// Removes the first partition.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn removeFirst(
        self: *Partitioner,
        gpa: std.mem.Allocator,
    ) error{OutOfMemory}!void {
        if (self.length() == 0)
            @panic("partitioner is empty");

        if (self.length() == 1) {
            const entry = self.first();
            try releaseSizePolicies(gpa, entry);
            entry.partition.deinit(gpa);
            _ = self.partition_list.orderedRemove(0);
            return;
        }

        const current = self.first();
        const next    = current.next().?;

        try releaseSizePolicies(gpa, current);
        try releaseSizePolicies(gpa, next);
        try next.partition.setStart(gpa, current.partition.start);
        try applySizePolicies(gpa, next);

        current.partition.deinit(gpa);
        _ = self.partition_list.orderedRemove(0);
    }

    /// Removes the last partition.
    ///
    /// Invalidates live iterators and partition pointers.
    pub fn removeLast(
        self: *Partitioner,
        gpa: std.mem.Allocator,
    ) error{OutOfMemory}!void {
        if (self.empty())
            @panic("partitioner is empty");

        try self.remove(gpa, self.length() - 1);
    }
};

fn addSatisfiableConstraint(
    gpa: std.mem.Allocator,
    system: *System,
    constraint: Constraint,
) error{OutOfMemory}!usize {
    return system.addConstraint(gpa, constraint)
        catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.UnsatisfiableConstraint => @panic("unsatisfiable constraint"),
            else => @panic("internal partitioning failure"),
        };
}

fn removeConstraint(
    gpa: std.mem.Allocator,
    system: *System,
    constraint_id: usize,
) error{OutOfMemory}!void {
    system.removeConstraint(gpa, constraint_id)
        catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => @panic("internal partitioning failure"),
        };
}

fn appendShared(
    gpa: std.mem.Allocator,
    id: anytype,
    list: *std.ArrayList(@TypeOf(id)),
) error{OutOfMemory}!void {
    errdefer _ = id.deinit();
    try list.append(gpa, id);
}

const SIZE  = 0;
const MIN   = 1;
const MAX   = 2;
const FIRST = SIZE;
const LAST  = MAX + 1;

/// Updates a size policy for the partition.
///
/// The `which` parameter determines the policy:
///   - `SIZE` for the standard size policy
///   -  `MIN` for the  minimal size policy
///   -  `MAX` for the  maximal size policy
///
/// Other values are not permitted.
fn setSizePolicy(
    comptime which: usize,
    gpa: std.mem.Allocator,
    entry: Partitioner.Entry,
    policy: SizePolicy,
) error{OutOfMemory}!void {
    try releaseSizePolicy(which, gpa, entry);
    entry.partition.policies[which] =
        switch (policy) {
            .percentage => |p| .Fraction(p, 100),
            else        => |p| p,
        };
    try applySizePolicy(which, gpa, entry);
}

/// Applies a given size policy to the partition by adding necessary
/// constraints to the partitioner.
///
/// The `which` parameter determines the policy:
///   - `SIZE` for the standard size policy
///   -  `MIN` for the  minimal size policy
///   -  `MAX` for the  maximal size policy
///
/// Other values are not permitted.
fn applySizePolicy(
    comptime which: usize,
    gpa: std.mem.Allocator,
    entry: Partitioner.Entry,
) error{OutOfMemory}!void {
    const partitioner = entry.partitioner;
    const partition   = entry.partition;
    const root        = partitioner.root;
    const system      = &partitioner.system;
    const op          = @as(Operator, @enumFromInt(which));
    const op_strength = switch (op) { .eq => 1.0, .le => 10.0, .ge => 10.0 };

    return switch (partition.policies[which]) {
        // The auto constraint has no meaning here; it's used by
        // higher-level layouts to automatically size items based on their
        // contents.
        .auto => {},

        .fixed => |value| {
            var   constraint = Constraint.empty;
            defer constraint.deinit(gpa);
            try   constraint.lhs.insertExpression(gpa, 1.0, partition.size);
                  constraint.rhs.add(@floatFromInt(value));
                  constraint.strength = Strength.init(entry.strength, op_strength, 0.0);
                  constraint.operator = op;

            const strong = try Shared(usize).init(gpa);
            const   weak = Strong(usize).downgrade(strong);
            defer      _ = strong.deinit();
            defer            weak.deinit();

            strong.ref.data = try addSatisfiableConstraint(gpa, system, constraint);

            try appendShared(gpa, strong.clone(), &partitioner.constraint_id_list);
            try appendShared(gpa,   weak.clone(),   &partition.constraint_id_lists[which]);
        },

        // percentages are saved as fractions
        .percentage => unreachable,
        .fraction   => |fraction| {
            const numerator   = @as(f32, @floatFromInt(fraction.numerator));
            const denominator = @as(f32, @floatFromInt(fraction.denominator));

            var   constraint = Constraint.empty;
            defer constraint.deinit(gpa);
            try   constraint.lhs.insertExpression(gpa, 1.0, partition.size);
            try   constraint.rhs.insertExpression(gpa, 1.0, root.size);
                  constraint.rhs.multiply(numerator);
                  constraint.rhs.divide(denominator);
                  constraint.strength = Strength.init(entry.strength, op_strength, 0.0);
                  constraint.operator = op;

            const strong = try Shared(usize).init(gpa);
            const   weak = Strong(usize).downgrade(strong);
            defer      _ = strong.deinit();
            defer            weak.deinit();

            strong.ref.data = try addSatisfiableConstraint(gpa, system, constraint);

            try appendShared(gpa, strong.clone(), &partitioner.constraint_id_list);
            try appendShared(gpa,   weak.clone(),   &partition.constraint_id_lists[which]);
        },

        .fill => |this_factor| {
            std.debug.assert(op == .eq);

            const this       = partition;
            const this_index = entry.index;

            var it = partitioner.iterator();
            while (it.next()) |other_entry| {
                if (other_entry.partition.policies[which] != .fill)
                    continue;

                const other        = other_entry.partition;
                const other_index  = other_entry.index;
                const other_factor = other.policies[which].fill;

                if (this_index == other_index)
                    continue;

                var   constraint: Constraint = .empty;
                defer constraint.deinit(gpa);
                try   constraint.lhs.insertExpression(gpa, 1.0, this.size);
                try   constraint.rhs.insertExpression(gpa, 1.0, other.size);
                      constraint.lhs.multiply(@floatFromInt(other_factor));
                      constraint.rhs.multiply(@floatFromInt(this_factor));
                      constraint.strength = Strength.init(entry.strength, op_strength, 0.0);
                      constraint.operator = op;

                const strong = try Shared(usize).init(gpa);
                const   weak = Strong(usize).downgrade(strong);
                defer      _ = strong.deinit();
                defer            weak.deinit();

                strong.ref.data = try addSatisfiableConstraint(gpa, system, constraint);

                try appendShared(gpa, strong.clone(), &partitioner.constraint_id_list);
                try appendShared(gpa,   weak.clone(),        &this.constraint_id_lists[which]);
                try appendShared(gpa,   weak.clone(),       &other.constraint_id_lists[which]);
            }
        },
    };
}

/// Applies all size policies specified in `policies` to the partition by
/// adding necessary constraints to the partitioner.
fn applySizePolicies(
    gpa: std.mem.Allocator,
    entry: Partitioner.Entry,
) error{OutOfMemory}!void {
    inline for (FIRST..LAST) |which|
        try applySizePolicy(which, gpa, entry);
}

/// Releases a given size policy to the partition by removing necessary
/// constraints from the partitioner.
///
/// The `which` parameter determines the policy:
///   - `SIZE` for the standard size policy
///   -  `MIN` for the  minimal size policy
///   -  `MAX` for the  maximal size policy
///
/// Other values are not permitted.
fn releaseSizePolicy(
    comptime which: usize,
    gpa: std.mem.Allocator,
    entry: Partitioner.Entry,
) error{OutOfMemory}!void {
    const partitioner = entry.partitioner;
    const partition   = entry.partition;

    for (partition.constraint_id_lists[which].items) |partition_constraint_id| {
        for (partitioner.constraint_id_list.items, 0..) |partitioner_constraint_id, i| {
            if (partitioner_constraint_id.ref == partition_constraint_id.ref) {
                try removeConstraint(gpa, &partitioner.system, partition_constraint_id.ref.data);
                _ = partitioner_constraint_id.deinit();
                _ = partitioner.constraint_id_list.swapRemove(i);
                break;
            }
        }

        partition_constraint_id.deinit();
    }

    partition.constraint_id_lists[which].clearRetainingCapacity();
 }

/// Releases all currently applied size policies by removing necessary
/// constraints from the partitioner.
pub fn releaseSizePolicies(
    gpa: std.mem.Allocator,
    entry: Partitioner.Entry,
) error{OutOfMemory}!void {
    inline for (FIRST..LAST) |which|
        try releaseSizePolicy(which, gpa, entry);
}

const Test = struct {
    pub const Action = union(enum) {
        append,
        prepend,
        remove_first,
        remove_last,
        insert: usize,
        remove: usize,

        set_size:     u16,
        set_min_size: u16,
        set_max_size: u16,

        set_size_policy:     struct { index: usize, policy: SizePolicy },
        set_min_size_policy: struct { index: usize, policy: SizePolicy },
        set_max_size_policy: struct { index: usize, policy: SizePolicy },

        expect_empty,
        expect_length: usize,
        expect_size:   u16,
        expect_sizeof:        struct { index: usize, size: u16 },
        expect_approx_sizeof: struct { index: usize, size: u16 },

        pub fn Append() Action {
            return .append;
        }

        pub fn Prepend() Action {
            return .prepend;
        }

        pub fn Insert(index: usize) Action {
            return .{ .insert = index };
        }

        pub fn RemoveFirst() Action {
            return .remove_first;
        }

        pub fn RemoveLast() Action {
            return .remove_last;
        }

        pub fn Remove(index: usize) Action {
            return .{ .remove = index };
        }

        pub fn SetSize(value: u16) Action {
            return .{ .set_size = value };
        }

        pub fn SetMinSize(value: u16) Action {
            return .{ .set_min_size = value };
        }

        pub fn SetMaxSize(value: u16) Action {
            return .{ .set_max_size = value };
        }

        pub fn SetSizePolicy(index: usize, policy: SizePolicy) Action {
            return .{ .set_size_policy = .{ .index = index, .policy = policy } };
        }

        pub fn SetMinSizePolicy(index: usize, policy: SizePolicy) Action {
            return .{ .set_min_size_policy = .{ .index = index, .policy = policy } };
        }

        pub fn SetMaxSizePolicy(index: usize, policy: SizePolicy) Action {
            return .{ .set_max_size_policy = .{ .index = index, .policy = policy } };
        }

        pub fn ExpectEmpty() Action {
            return .expect_empty;
        }

        pub fn ExpectLength(value: usize) Action {
            return .{ .expect_length = value };
        }

        pub fn ExpectSize(value: u16) Action {
            return .{ .expect_size = value };
        }

        pub fn ExpectSizeOf(index: usize, value: u16) Action {
            return .{ .expect_sizeof = .{ .index = index, .size = value } };
        }

        pub fn ExpectApproxSizeOf(index: usize, value: u16) Action {
            return .{ .expect_approx_sizeof = .{ .index = index, .size = value } };
        }
    };

    pub fn run(gpa: std.mem.Allocator, id: usize, actions: []const Action) !void {
        var   partitioner = try Partitioner.init(gpa);
        defer partitioner.deinit(gpa);

        for (actions) |action| switch (action) {
            .append              =>       try partitioner.append(gpa),
            .prepend             =>       try partitioner.prepend(gpa),
            .remove_first        =>       try partitioner.removeFirst(gpa),
            .remove_last         =>       try partitioner.removeLast(gpa),
            .insert              => |at|  try partitioner.insert(gpa, at),
            .remove              => |at|  try partitioner.remove(gpa, at),

            .set_size            => |val| try partitioner.setSize(gpa, val),
            .set_min_size        => |val| try partitioner.setMinSize(gpa, val),
            .set_max_size        => |val| try partitioner.setMaxSize(gpa, val),

            .set_size_policy     => |p|   try partitioner.at(p.index).setSizePolicy(gpa, p.policy),
            .set_min_size_policy => |p|   try partitioner.at(p.index).setMinSizePolicy(gpa, p.policy),
            .set_max_size_policy => |p|   try partitioner.at(p.index).setMaxSizePolicy(gpa, p.policy),

            .expect_empty => {
                std.testing.expect(true == partitioner.empty())
                    catch {
                        std.debug.print("(test case #{d}) expected an empty partitioner, but found a non-empty one\n", .{id});
                        return error.TestExpectedEmpty;
                    };
            },

            .expect_length => |value| {
                std.testing.expect(value == partitioner.length())
                    catch {
                        std.debug.print("(test case #{d}) expected length {d}, found {d}\n", .{id, value, partitioner.length()});
                        return error.TestExpectedLength;
                    };
            },

            .expect_size => |value| {
                std.testing.expect(value == partitioner.size())
                    catch {
                        std.debug.print("(test case #{d}) expected size {d}, found {d}\n", .{id, value, partitioner.size()});
                        return error.TestExpectedSize;
                    };
            },

            .expect_sizeof => |s| {
                const partition = partitioner.at(s.index);
                const value     = s.size;

                std.testing.expect(value == partition.size())
                    catch {
                        std.debug.print("(test case #{d}) expected size {d}, found {d}\n", .{id, value, partition.size()});
                        return error.TestExpectedSize;
                    };
            },

            .expect_approx_sizeof => |s| {
                const partition = partitioner.at(s.index);
                const value     = s.size;

                std.testing.expect(value + 1 >= partition.size() and value - 1 <= partition.size())
                    catch {
                        std.debug.print("(test case #{d}) expected approximate size {d}, found {d}\n", .{id, value, partition.size()});
                        return error.TestExpectedSize;
                    };
            },
        };
    }
};

test {
    inline for (
        &[_][]const Test.Action{
            // #0
            &[_]Test.Action{
                .ExpectEmpty(),
                .Append(),
                .ExpectLength(1),
            },

            // #1
            &[_]Test.Action{
                .ExpectEmpty(),
                .Prepend(),
                .ExpectLength(1),
            },

            // #2
            &[_]Test.Action{
                .ExpectEmpty(),
                .Insert(0),
                .ExpectLength(1),
            },

            // #3
            &[_]Test.Action{
                .ExpectEmpty(),
                .Insert(0),
                .ExpectLength(1),
                .Remove(0),
                .ExpectEmpty(),
            },

            // #4
            &[_]Test.Action{
                .ExpectEmpty(),
                .Insert(0),
                .ExpectLength(1),
                .RemoveFirst(),
                .ExpectEmpty(),
            },

            // #5
            &[_]Test.Action{
                .ExpectEmpty(),
                .Insert(0),
                .ExpectLength(1),
                .RemoveLast(),
                .ExpectEmpty(),
            },

            // #6
            &[_]Test.Action{
                .ExpectEmpty(),
                .Insert(0),
                .ExpectLength(1),
                .RemoveLast(),
                .ExpectEmpty(),
            },

            // #7
            &[_]Test.Action{
                .SetSize(100),
                .ExpectSize(100),
            },

            // #8
            &[_]Test.Action{
                .SetMinSize(100),
                .ExpectSize(100),
            },

            // #9
            &[_]Test.Action{
                .SetMaxSize(100),
                .ExpectSize(0),
            },

            // #10
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fixed(5915)),
                .ExpectSizeOf(0, 5915),
                .ExpectSize(5915),
            },

            // #11
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Percentage(100)),
                .ExpectSizeOf(0, 0),
                .ExpectSize(0),
            },

            // #12
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fraction(1, 1)),
                .ExpectSizeOf(0, 0),
                .ExpectSize(0),
            },

            // #13
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .ExpectSizeOf(0, 0),
                .ExpectSize(0),
            },

            // #14
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Auto()),
                .ExpectSizeOf(0, 0),
                .ExpectSize(0),
            },

            // #15
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #16
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Percentage(100)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #17
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Percentage(50)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #18
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Percentage(1000)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #19
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fixed(250)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #20
            &[_]Test.Action{
                .Append(),
                .SetSizePolicy(0, .Fixed(1500)),
                .SetSize(500),
                .ExpectSizeOf(0, 500),
                .ExpectSize(500),
            },

            // #21
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetSizePolicy(0, .Fixed(200)),
                .Append(),

                .ExpectSizeOf(0, 200),
                .ExpectSizeOf(1, 300),
            },

            // #22
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .Append(),
                .SetSizePolicy(0, .Fixed(200)),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 200),
                .ExpectSizeOf(1, 300),
            },

            // #23
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetSizePolicy(0, .Fixed(200)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 200),
                .ExpectSizeOf(1, 300),
            },

            // #24
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 250),
                .ExpectSizeOf(1, 250),
            },

            // #25
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetSizePolicy(0, .Percentage(50)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 250),
                .ExpectSizeOf(1, 250),
            },

            // #26
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetSizePolicy(0, .Fraction(1, 2)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 250),
                .ExpectSizeOf(1, 250),
            },

            // #27
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetMaxSizePolicy(0, .Fixed(300)),
                .SetSizePolicy(0, .Percentage(80)),
                .Append(),
                .SetSizePolicy(0, .Fill(1)),

                .ExpectSizeOf(0, 300),
                .ExpectSizeOf(1, 200),
            },

            // #28
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetMaxSizePolicy(0, .Fixed(300)),
                .SetSizePolicy(0, .Percentage(80)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 80),
                .ExpectSizeOf(1, 20),
            },

            // #29
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetMaxSizePolicy(0, .Percentage(80)),
                .SetSizePolicy(0, .Fixed(100)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 100),
                .ExpectSizeOf(1, 400),
            },

            // #30
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetMaxSizePolicy(0, .Percentage(80)),
                .SetSizePolicy(0, .Fixed(100)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 80),
                .ExpectSizeOf(1, 20),
            },

            // #31
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetMinSizePolicy(0, .Fixed(100)),
                .SetSizePolicy(0, .Percentage(80)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 400),
                .ExpectSizeOf(1, 100),
            },

            // #32
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetMinSizePolicy(0, .Fixed(100)),
                .SetSizePolicy(0, .Percentage(80)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 100),
                .ExpectSizeOf(1, 0),
            },

            // #33
            &[_]Test.Action{
                .SetSize(500),
                .Append(),
                .SetMinSizePolicy(0, .Percentage(80)),
                .SetSizePolicy(0, .Fixed(100)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 400),
                .ExpectSizeOf(1, 100),
            },

            // #34
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetMinSizePolicy(0, .Percentage(80)),
                .SetSizePolicy(0, .Fixed(100)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),

                .ExpectSizeOf(0, 100),
                .ExpectSizeOf(1, 0),
            },

            // #35
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .Append(),
                .SetSizePolicy(1, .Fill(1)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),

                .ExpectApproxSizeOf(0, 33),
                .ExpectApproxSizeOf(1, 33),
                .ExpectApproxSizeOf(2, 33),
                .ExpectSize(100),
            },

            // #36
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .Append(),
                .SetSizePolicy(1, .Fill(2)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),

                .ExpectSizeOf(0, 25),
                .ExpectSizeOf(1, 50),
                .ExpectSizeOf(2, 25),
            },

            // #37
            &[_]Test.Action{
                .SetSize(100),
                .Append(),
                .SetSizePolicy(0, .Fill(1)),
                .Append(),
                .SetSizePolicy(1, .Fill(3)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),

                .ExpectSizeOf(0, 20),
                .ExpectSizeOf(1, 60),
                .ExpectSizeOf(2, 20),
            },

            // #38
            &[_]Test.Action{
                .SetSize(1000),
                .Append(),
                .SetSizePolicy(0, .Fill(4)),
                .Append(),
                .SetSizePolicy(1, .Fill(3)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),

                .ExpectSizeOf(0, 500),
                .ExpectSizeOf(1, 375),
                .ExpectSizeOf(2, 125),
            },

            // #39
            &[_]Test.Action{
                .SetSize(1000),
                .Append(),
                .SetSizePolicy(0, .Fill(8)),
                .Append(),
                .SetSizePolicy(1, .Fill(3)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),

                .ExpectApproxSizeOf(0, 666),
                .ExpectSizeOf(1, 250),
                .ExpectApproxSizeOf(2, 83),
                .ExpectSize(1000),
            },

            // #40
            &[_]Test.Action{
                .SetSize(50000),
                .Append(),
                .SetSizePolicy(0, .Fill(10000)),
                .Append(),
                .SetSizePolicy(1, .Fill(10)),
                .Append(),
                .SetSizePolicy(2, .Fill(15000)),

                .ExpectApproxSizeOf(0, 19992),
                .ExpectApproxSizeOf(1, 20),
                .ExpectApproxSizeOf(2, 29988),
            },

            // #41
            &[_]Test.Action{
                .SetSize(1000),
                .Append(),
                .SetSizePolicy(0, .Percentage(30)),
                .Append(),
                .SetSizePolicy(1, .Fixed(200)),
                .Append(),
                .SetSizePolicy(2, .Fill(1)),
                .Append(),
                .SetSizePolicy(3, .Fill(4)),
                .Append(),
                .SetSizePolicy(4, .Fraction(1, 4)),

                .ExpectSizeOf(0, 300),
                .ExpectSizeOf(1, 200),
                .ExpectSizeOf(2, 50),
                .ExpectSizeOf(3, 200),
                .ExpectSizeOf(4, 250),
            },
        },
        0..,
    ) |actions, id| {
        try std.testing.checkAllAllocationFailures(
            std.testing.allocator,
            Test.run,
            .{id, actions},
        );
    }
}
