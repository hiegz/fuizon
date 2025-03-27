const std = @import("std");
const fuizon = @import("fuizon");

const Frame = fuizon.frame.Frame;

pub const Screen = struct {
    frames: [2]Frame,
    buffer: @TypeOf(std.io.bufferedWriter(std.io.getStdOut().writer())),

    pub fn init(allocator: std.mem.Allocator) !Screen {
        var screen: Screen = undefined;
        screen.frames[0] = Frame.init(allocator);
        screen.frames[1] = Frame.init(allocator);

        screen.buffer = std.io.bufferedWriter(std.io.getStdOut().writer());
        defer screen.buffer.flush() catch {};
        const writer = screen.buffer.writer();

        try fuizon.backend.raw_mode.enable();
        errdefer fuizon.backend.raw_mode.disable() catch {};
        try fuizon.backend.alternate_screen.enter(writer);
        errdefer fuizon.backend.alternate_screen.leave(writer) catch {};
        try fuizon.backend.cursor.hide(writer);
        errdefer fuizon.backend.cursor.show(writer) catch {};

        const render_area = try fuizon.backend.area.fullscreen().render(writer);
        const render_frame: *Frame = screen.frame();
        try render_frame.resize(render_area.width, render_area.height);
        render_frame.moveTo(render_area.origin.x, render_area.origin.y);

        return screen;
    }

    pub fn deinit(self: *Screen) void {
        defer self.buffer.flush() catch {};
        const writer = self.buffer.writer();

        fuizon.backend.raw_mode.disable() catch {};
        fuizon.backend.alternate_screen.leave(writer) catch {};
        fuizon.backend.cursor.show(writer) catch {};

        self.frames[0].deinit();
        self.frames[1].deinit();
    }

    pub fn frame(self: anytype) switch (@TypeOf(self)) {
        *const Screen => *const Frame,
        *Screen => *Frame,
        else => unreachable,
    } {
        return &self.frames[0];
    }

    pub fn clear(self: *Screen) !void {
        try fuizon.backend.screen.clearAll(self.buffer.writer());
        self.frames[0].reset();
        self.frames[1].reset();
    }

    pub fn render(self: *Screen) !void {
        const writer = self.buffer.writer();
        try fuizon.backend.frame.render(writer, self.frames[0], self.frames[1]);
        try self.frames[1].copy(self.frames[0]);
    }

    pub fn flush(self: *Screen) !void {
        try self.buffer.flush();
    }
};
