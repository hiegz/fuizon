const std = @import("std");
const VariableKind = @import("variable_kind.zig").VariableKind;

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
