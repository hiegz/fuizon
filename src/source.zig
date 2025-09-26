const std = @import("std");

pub const Source = union(enum) {
    stdin,
    file: std.fs.File,

    pub fn File(file: std.fs.File) Source {
        return .{ .file = file };
    }
};
