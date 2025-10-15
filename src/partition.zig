// zig fmt: off

const std = @import("std");

const SizePolicy = @import("size_policy.zig").SizePolicy;
const Variable = @import("variable.zig").Variable;
const Expression = @import("expression.zig").Expression;
const Constraint = @import("constraint.zig").Constraint;
const Strong = @import("strong.zig").Strong;
const Weak = @import("weak.zig").Weak;

/// This structure is used internally and is not part of the public
/// partitioning API.
pub const Partition = struct {
    /// Start of the partition.
    ///
    /// Should not be modified directly; use `setStart()` instead.
    start: Strong(Variable) = undefined,

    /// End of the partition.
    ///
    /// Should not be modified directly; use `setEnd()` instead.
    end: Strong(Variable) = undefined,

    /// Linear expression representing `end - start`.
    ///
    /// Should not be modified directly; use `setStart()` and `setEnd()` instead.
    size: Expression = .empty,

    /// Size policies currently applied to the partition.
    ///
    /// Items:
    ///  - `[0]` —  target size policy
    ///  - `[1]` — minimal size policy
    ///  - `[2]` — maximal size policy
    policies: [3]SizePolicy = .{ .auto,  .auto,  .auto  },

    /// Constraint ID lists for this partition.
    ///
    /// Items:
    ///  - `[0]` —  target size constraint ids
    ///  - `[1]` — minimal size constraint ids
    ///  - `[2]` — maximal size constraint ids
    constraint_id_lists: [3]std.ArrayList(Weak(usize)) = .{ .empty, .empty, .empty },

    pub fn init(
        gpa: std.mem.Allocator,
        start: Strong(Variable),
        end: Strong(Variable),
    ) error{OutOfMemory}!Partition {
        errdefer _ = start.deinit();
        errdefer _ = end.deinit();

        var self: Partition = Partition{};

        self.start = start;
        self.end   = end;

        try self.size.insert(gpa,  1.0, &self.end.ref.data);
        try self.size.insert(gpa, -1.0, &self.start.ref.data);

        return self;
    }

    /// Frees partition resources.
    ///
    /// This function frees the shared size constraints by which it is affected
    /// but does not remove them from the partitioner.
    pub fn deinit(self: *Partition, gpa: std.mem.Allocator) void {
        for (&self.constraint_id_lists) |*constraint_id_list| {
            for (constraint_id_list.items) |constraint_id|
                constraint_id.deinit();
            constraint_id_list.deinit(gpa);
        }
        self.size.deinit(gpa);
        _ = self.start.deinit();
        _ = self.end.deinit();
    }

    /// Updates the partition's start variable.
    pub fn setStart(
        self: *Partition,
        gpa: std.mem.Allocator,
        start: Strong(Variable),
    ) error{OutOfMemory}!void {
        errdefer _ = start.deinit();

        self.size.remove(self.size.find(&self.start.ref.data).?);

        try self.size.insert(gpa, -1.0, &start.ref.data);
        _ = self.start.deinit();
        self.start = start;
    }

    /// Updates the partition's end variable.
    pub fn setEnd(
        self: *Partition,
        gpa: std.mem.Allocator,
        end: Strong(Variable),
    ) error{OutOfMemory}!void {
        errdefer _ = end.deinit();

        self.size.remove(self.size.find(&self.end.ref.data).?);

        try self.size.insert(gpa, 1.0, &end.ref.data);
        _ = self.end.deinit();
        self.end = end;
    }
};
