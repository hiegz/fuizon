const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const posix = std.posix;
const alignment = @import("alignment.zig");
const area = @import("area.zig");
const attribute = @import("attribute.zig");
const color = @import("color.zig");
const coordinate = @import("coordinate.zig");
const dimensions = @import("dimensions.zig");
const Buffer = @import("buffer.zig");
const key = @import("key.zig");
const style = @import("style.zig");
const queue = @import("queue.zig");
const Queue = queue.Queue;
const terminal = @import("terminal.zig");
const input = @import("input.zig");

pub const Alignment = alignment.Alignment;
pub const Area = area.Area;
pub const Attribute = attribute.Attribute;
pub const Attributes = attribute.Attributes;
pub const Color = color.Color;
pub const AnsiColor = color.AnsiColor;
pub const RgbColor = color.RgbColor;
pub const Coordinate = coordinate.Coordinate;
pub const Dimensions = dimensions.Dimensions;
pub const Input = input.Input;
pub const InputParser = @import("input_parser.zig");
pub const Key = key.Key;
pub const KeyCode = key.KeyCode;
pub const KeyModifier = key.KeyModifier;
pub const KeyModifiers = key.KeyModifiers;
pub const Style = style.Style;

pub fn init() error{ NotATerminal, Unexpected }!void {
    try terminal.enableRawMode();
}

pub fn deinit() error{ NotATerminal, Unexpected }!void {
    try terminal.disableRawMode();
}

test "fuizon" {
    @import("std").testing.refAllDeclsRecursive(@This());
}

// test "init(.stdout) should write to stdout" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stdout().handle, state.instance.?.file.handle);
// }
//
// test "init(.stderr) should write to stderr" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try std.testing.expectEqual(std.fs.File.stderr().handle, state.instance.?.file.handle);
// }
//
// test "useStdout() should switch to stdout" {
//     try init(std.testing.allocator, 1024, .stderr);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStdout();
//     try std.testing.expectEqual(std.fs.File.stdout().handle, state.instance.?.file.handle);
// }
//
// test "useStderr() should switch to stderr" {
//     try init(std.testing.allocator, 1024, .stdout);
//     defer deinit(std.testing.allocator) catch unreachable;
//     try useStderr();
//     try std.testing.expectEqual(std.fs.File.stderr().handle, state.instance.?.file.handle);
// }
