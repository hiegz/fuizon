const std = @import("std");
const fuizon = @import("fuizon.zig");

pub fn Queue(comptime T: type) type {
    return struct {
        const Node = struct {
            value: T,
            next: ?*Node,
        };

        head: ?*Node,
        tail: ?*Node,

        pub fn init() Queue(T) {
            return .{ .head = null, .tail = null };
        }

        pub fn enqueue(
            self: *Queue(T),
            allocator: std.mem.Allocator,
            value: T,
        ) error{OutOfMemory}!void {
            const node = try allocator.create(Node);
            errdefer allocator.destroy(node);
            node.value = value;
            node.next = null;
            if (self.tail) |tail| tail.next = node //
            else self.head = node;
            self.tail = node;
        }

        pub fn dequeue(
            self: *Queue(T),
            allocator: std.mem.Allocator,
        ) ?T {
            const head = self.head orelse return null;
            if (head.next) |node| {
                self.head = node;
            } else {
                self.head = null;
                self.tail = null;
            }
            const value = head.value;
            allocator.destroy(head);
            return value;
        }

        pub fn deinit(self: *Queue(T), allocator: std.mem.Allocator) void {
            while (self.head != null and self.tail != null) {
                _ = self.dequeue(allocator);
            }
        }
    };
}
