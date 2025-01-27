const std = @import("std");
const fuizon = @import("fuizon");

pub fn Demo(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        backend: fuizon.crossterm.Backend(WriterType),
        is_running: bool,
        is_polling: bool,
        in_alternate_screen: bool,

        fn init(backend: fuizon.crossterm.Backend(WriterType)) Self {
            return .{
                .backend = backend,
                .is_running = false,
                .is_polling = false,
                .in_alternate_screen = false,
            };
        }

        fn deinit(self: *Self) void {
            if (self.in_alternate_screen) {
                self.in_alternate_screen = false;
                self.backend.leaveAlternateScreen() catch {};
            }
            self.backend.deinit();
        }

        fn run(self: *Self) !void {
            self.is_running = true;
            while (self.is_running)
                try self.runOnce();
        }

        fn runOnce(self: *Self) !void {
            self.is_running = true;
            if (self.is_polling and !try fuizon.crossterm.event.poll()) return;
            const event = try fuizon.crossterm.event.read();
            switch (event) {
                .key => switch (event.key.code) {
                    .char => switch (event.key.code.char) {
                        'a' => {
                            if (!self.in_alternate_screen) {
                                self.in_alternate_screen = true;
                                try self.backend.enterAlternateScreen();
                            } else {
                                self.in_alternate_screen = false;
                                try self.backend.leaveAlternateScreen();
                            }
                            return;
                        },
                        'q' => {
                            std.debug.print("Quitting...\n\r", .{});
                            self.is_running = false;
                            return;
                        },
                        'p' => {
                            if (!self.is_polling) {
                                self.is_polling = true;
                                std.debug.print("Polling has been enabled\n\r", .{});
                            } else {
                                self.is_polling = false;
                                std.debug.print("Polling has been disabled\n\r", .{});
                            }
                            return;
                        },
                        else => {},
                    },
                    else => {},
                },
                .resize => {},
            }
            std.debug.print("{}\n\r", .{event});
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Press 'q' to quit,\n\r", .{});
    std.debug.print("      'p' to toggle polling,\n\r", .{});
    std.debug.print("      'a' to toggle alternate screen,\n\r", .{});
    std.debug.print("       or any other key to see info about it\n\r", .{});

    std.debug.assert((try fuizon.crossterm.isRawModeEnabled()) == false);
    try fuizon.crossterm.enableRawMode();
    std.debug.assert((try fuizon.crossterm.isRawModeEnabled()) == true);
    defer std.debug.assert((fuizon.crossterm.isRawModeEnabled() catch unreachable) == false);
    defer fuizon.crossterm.disableRawMode() catch {};

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var demo = Demo(@TypeOf(writer)).init(
        try fuizon.crossterm.Backend(@TypeOf(writer)).init(
            allocator,
            writer,
        ),
    );
    defer demo.deinit();
    try demo.run();
}
