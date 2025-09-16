const std = @import("std");

pub var buffer: []u8 = &.{};
pub var instance: ?std.fs.File.Writer = null;
