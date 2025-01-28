const std = @import("std");
const fuizon = @import("fuizon");

const EventStatus = enum { skipped, consumed };

fn Demo(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        backend: fuizon.crossterm.Backend(WriterType),
        is_running: bool,
        is_polling: bool,
        is_cursor_visible: bool,
        is_cursor_moving: bool,
        in_alternate_screen: bool,

        fn init(backend: fuizon.crossterm.Backend(WriterType)) Self {
            return .{
                .backend = backend,
                .is_running = false,
                .is_polling = false,
                .is_cursor_visible = true,
                .is_cursor_moving = false,
                .in_alternate_screen = false,
            };
        }

        fn deinit(self: *Self) void {
            if (self.in_alternate_screen) {
                self.in_alternate_screen = false;
                self.backend.leaveAlternateScreen() catch {};
            }
            if (!self.is_cursor_visible) {
                self.is_cursor_visible = true;
                self.backend.showCursor() catch {};
            }
            if (self.is_cursor_moving) {
                self.is_cursor_moving = false;
                self.backend.restoreCursorPosition() catch {};
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
            if (try self.handleEvent(event) == .skipped)
                std.debug.print("{}\n\r", .{event});
        }

        pub fn handleEvent(self: *Self, event: fuizon.Event) !EventStatus {
            return switch (event) {
                .key => switch (event.key.code) {
                    .char => try self.handleCharacter(event),
                    .up_arrow => try self.jumpTop(),
                    .left_arrow => try self.jumpLeft(),

                    else => if (self.is_cursor_moving)
                        .consumed
                    else
                        .skipped,
                },
                else => if (self.is_cursor_moving)
                    .consumed
                else
                    .skipped,
            };
        }

        pub fn handleCharacter(self: *Self, event: fuizon.Event) !EventStatus {
            return switch (event.key.code.char) {
                'a' => try self.toggleAlternateScreen(),

                't' => try self.getCursorPosition(),
                'c' => try self.toggleCursorVisibility(),
                'm' => try self.toggleCursorMovement(),

                's' => try self.jumpTopLeft(),
                'h' => try self.moveLeft(),
                'j' => try self.moveDown(),
                'J' => try self.moveToNextLine(),
                'k' => try self.moveUp(),
                'K' => try self.moveToPreviousLine(),
                'l' => try self.moveRight(),

                'p' => self.togglePolling(),
                'q' => self.quit(),

                else => if (self.is_cursor_moving)
                    .consumed
                else
                    .skipped,
            };
        }

        pub fn toggleAlternateScreen(self: *Self) !EventStatus {
            if (self.is_cursor_moving) return .consumed;

            if (!self.in_alternate_screen) {
                self.in_alternate_screen = true;
                try self.backend.enterAlternateScreen();
            } else {
                self.in_alternate_screen = false;
                try self.backend.leaveAlternateScreen();
            }
            return .consumed;
        }

        pub fn getCursorPosition(self: *Self) !EventStatus {
            const pos = try fuizon.crossterm.getCursorPosition();
            try self.backend.restoreCursorPosition();
            std.debug.print("x={}, y={}\n\r", .{ pos.x, pos.y });
            try self.backend.moveCursorTo(pos.x, pos.y);
            return .consumed;
        }

        pub fn toggleCursorVisibility(self: *Self) !EventStatus {
            if (!self.is_cursor_visible) {
                self.is_cursor_visible = true;
                try self.backend.showCursor();
            } else {
                self.is_cursor_visible = false;
                try self.backend.hideCursor();
            }
            return .consumed;
        }

        pub fn toggleCursorMovement(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) {
                self.is_cursor_moving = true;
                try self.backend.saveCursorPosition();
            } else {
                self.is_cursor_moving = false;
                try self.backend.restoreCursorPosition();
            }
            return .consumed;
        }

        pub fn jumpTopLeft(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorTo(0, 0);
            return .consumed;
        }

        pub fn jumpTop(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorToRow(0);
            return .consumed;
        }

        pub fn jumpLeft(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorToCol(0);
            return .consumed;
        }

        pub fn moveUp(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorUp(1);
            return .consumed;
        }

        pub fn moveToPreviousLine(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorToPreviousLine(1);
            return .consumed;
        }

        pub fn moveDown(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorDown(1);
            return .consumed;
        }

        pub fn moveToNextLine(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorToNextLine(1);
            return .consumed;
        }

        pub fn moveLeft(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorLeft(1);
            return .consumed;
        }

        pub fn moveRight(self: *Self) !EventStatus {
            if (!self.is_cursor_moving) return .skipped;
            try self.backend.moveCursorRight(1);
            return .consumed;
        }

        pub fn togglePolling(self: *Self) EventStatus {
            if (self.is_cursor_moving) return .consumed;

            if (!self.is_polling) {
                self.is_polling = true;
                std.debug.print("Polling has been enabled\n\r", .{});
            } else {
                self.is_polling = false;
                std.debug.print("Polling has been disabled\n\r", .{});
            }

            return .consumed;
        }

        pub fn quit(self: *Self) EventStatus {
            if (self.is_cursor_moving) return .consumed;
            std.debug.print("Quitting...\n\r", .{});
            self.is_running = false;
            return .consumed;
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
    std.debug.print("\n\r", .{});
    std.debug.print("      't' to get current cursor position,\n\r", .{});
    std.debug.print("      'c' to toggle cursor visibility,\n\r", .{});
    std.debug.print("      'm' to toggle cursor movement,\n\r", .{});
    std.debug.print("      's' to move to the top left corner,\n\r", .{});
    std.debug.print("      '↑' to move to the top corner,\n\r", .{});
    std.debug.print("      '←' to move to the left corner,\n\r", .{});
    std.debug.print("      'h' to move left,\n\r", .{});
    std.debug.print("      'j' to move down,\n\r", .{});
    std.debug.print("      'J' to move down (alternative),\n\r", .{});
    std.debug.print("      'k' to move up,\n\r", .{});
    std.debug.print("      'K' to move up (alternative),\n\r", .{});
    std.debug.print("      'l' to move right,\n\r", .{});
    std.debug.print("\n\r", .{});
    std.debug.print("      or any other key to see info about it\n\r", .{});

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
