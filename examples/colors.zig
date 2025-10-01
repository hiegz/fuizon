const std = @import("std");
const fuizon = @import("fuizon");

// zig fmt: off

fn gap(n: u16) fuizon.StackItem {
    return .item(&fuizon.Void, .Fixed(n));
}

fn row(arena: std.mem.Allocator, label_text: []const u8, color: fuizon.Color) error{OutOfMemory}!fuizon.StackItem {
    const stack = try arena.create(fuizon.Stack);
    const label = try arena.create(fuizon.Text);
    const  demo = try arena.create(fuizon.Text);

    label.* = try    .raw(arena, label_text);
     demo.* = try .styled(arena, "this text should be invisible", .init(color, color, .none));

    label.alignment = .right;
     demo.alignment = .left;

    stack.* = try .horizontal(arena, &.{
        .item(label, .Fill(1)),
          gap(2),
        .item(demo, .Auto()),
    });

    return .item(stack, fuizon.StackConstraint.Auto());
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    try fuizon.init();
    defer fuizon.deinit() catch unreachable;

    var stack = fuizon.Stack.empty(.vertical);

    try stack.push(allocator,     gap(1));
    try stack.push(allocator, try row(allocator, "Black:",   .black));
    try stack.push(allocator, try row(allocator, "White:",   .white));
    try stack.push(allocator, try row(allocator, "Red:",     .red));
    try stack.push(allocator, try row(allocator, "Green:",   .green));
    try stack.push(allocator, try row(allocator, "Blue:",    .blue));
    try stack.push(allocator, try row(allocator, "Yellow:",  .yellow));
    try stack.push(allocator, try row(allocator, "Magenta:", .magenta));
    try stack.push(allocator, try row(allocator, "Cyan:",    .cyan));
    try stack.push(allocator,     gap(1));

    try fuizon.printWidget(
        &fuizon.Container{
            .margin_left  = .Fixed(2),
            .margin_right = .auto,
            .child = stack.widget(),
        },
    );
}
