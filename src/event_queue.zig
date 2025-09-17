const std = @import("std");
const fuizon = @import("fuizon.zig");
const Event = fuizon.Event;
const Self = @This();

const EventNode = struct {
    event: Event,
    next: ?*EventNode,
};

head: ?*EventNode,
tail: ?*EventNode,

pub fn init() Self {
    return .{ .head = null, .tail = null };
}

pub fn enqueue(
    self: *Self,
    allocator: std.mem.Allocator,
    event: Event,
) error{OutOfMemory}!void {
    const node = try allocator.create(EventNode);
    errdefer allocator.destroy(node);
    node.event = event;
    node.next = null;
    if (self.tail) |tail| tail.next = node //
    else self.head = node;
    self.tail = node;
}

pub fn dequeue(
    self: *Self,
    allocator: std.mem.Allocator,
) ?Event {
    const head = self.head orelse return null;
    if (head.next) |node| {
        self.head = node;
    } else {
        self.head = null;
        self.tail = null;
    }
    const ev = head.event;
    allocator.destroy(head);
    return ev;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    while (self.head != null and self.tail != null) {
        _ = self.dequeue(allocator);
    }
}
