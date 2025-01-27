const std = @import("std");
const fuizon = @import("fuizon");

const Demo = struct {
    is_running: bool,
    is_polling: bool,

    fn run(self: *Demo) !void {
        self.is_running = true;
        while (self.is_running)
            try self.runOnce();
    }

    fn runOnce(self: *Demo) !void {
        self.is_running = true;
        if (self.is_polling and !try fuizon.crossterm.event.poll()) return;
        const event = try fuizon.crossterm.event.read();
        switch (event) {
            .key => switch (event.key.code) {
                .char => switch (event.key.code.char) {
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

pub fn main() !void {
    std.debug.print("Press 'q' to quit, 'p' to toggle polling, or any other key to see info about it\n\r", .{});
    var demo = Demo{ .is_running = true, .is_polling = false };
    try demo.run();
}
