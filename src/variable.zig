const std = @import("std");
const VariableKind = @import("variable_kind.zig").VariableKind;

pub const Variable = struct {
    kind: VariableKind = .external,
    name: []const u8 = "",
    value: f32 = 0.0,

    pub fn init(name: []const u8) Variable {
        return .{ .name = name };
    }

    /// Allocates and initializes a new `Variable` using the given allocator.
    /// The caller owns the returned instance and must call `Variable.destroy`
    /// to free it.
    pub fn create(gpa: std.mem.Allocator, name: []const u8) error{OutOfMemory}!*Variable {
        const self: *Variable = try gpa.create(Variable);
        self.* = .init(name);
        return self;
    }

    /// Frees all resources allocated by `Variable.create` using the given allocator.
    pub fn destroy(self: *Variable, gpa: std.mem.Allocator) void {
        gpa.destroy(self);
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
