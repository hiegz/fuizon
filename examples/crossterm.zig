const std = @import("std");
const fuizon = @import("fuizon");

fn Demo(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        backend: fuizon.crossterm.Backend(WriterType),

        state: enum { terminated, running },
        mode: enum { normal, debug, move, scroll },
        alternate_screen: enum { disabled, enabled },
        polling: enum { disabled, enabled },
        cursor: enum { hidden, visible },

        fn init(allocator: std.mem.Allocator, writer: WriterType) !Self {
            var self: Self = undefined;
            self.backend = try fuizon.crossterm.Backend(WriterType)
                .init(allocator, writer);
            errdefer self.backend.deinit();

            self.state = .terminated;
            self.mode = .normal;
            self.alternate_screen = .disabled;
            self.polling = .disabled;
            self.cursor = .visible;

            return self;
        }

        fn deinit(self: *Self) !void {
            if (self.alternate_screen == .enabled)
                try self.backend.leaveAlternateScreen();
            if (self.cursor == .hidden)
                try self.backend.showCursor();
            if (self.mode == .move)
                try self.backend.restoreCursorPosition();
            self.backend.deinit();
        }

        fn run(self: *Self) !void {
            self.state = .running;
            while (self.state != .terminated)
                try self.runOnce();
        }

        fn runOnce(self: *Self) !void {
            self.state = .running;
            if (self.polling == .enabled and !try fuizon.crossterm.event.poll()) return;
            const event = try fuizon.crossterm.event.read();

            switch (self.mode) {
                .normal => try self.handleNormalEvent(event),
                .debug => try self.handleDebugEvent(event),
                .move => try self.handleMoveEvent(event),
                .scroll => try self.handleScrollEvent(event),
            }
        }

        fn handleNormalEvent(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .char => switch (event.key.code.char) {
                        'q' => self.state = .terminated,
                        'a' => try self.toggleAlternateScreen(),
                        'p' => try self.togglePolling(),
                        'd' => self.enableDebugMode(),
                        'm' => try self.enableMoveMode(),
                        's' => self.enableScrollMode(),
                        else => {},
                    },
                    else => {},
                },
                else => {},
            }
        }

        fn handleDebugEvent(self: *Self, event: fuizon.Event) !void {
            if (event == .key and event.key.code == .escape) {
                try self.enableNormalMode();
                return;
            }
            std.debug.print("{}\n\r", .{event});
        }

        fn handleMoveEvent(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .escape => try self.enableNormalMode(),
                    .left_arrow => try self.backend.moveCursorToCol(0),
                    .up_arrow => try self.backend.moveCursorToRow(0),
                    .char => switch (event.key.code.char) {
                        'c' => try self.toggleCursorVisiblity(),
                        's' => try self.backend.moveCursorTo(0, 0),
                        'h' => try self.backend.moveCursorLeft(1),
                        'j' => try self.backend.moveCursorDown(1),
                        'k' => try self.backend.moveCursorUp(1),
                        'l' => try self.backend.moveCursorRight(1),
                        'p' => {
                            const pos = try fuizon.crossterm.getCursorPosition();
                            try self.backend.restoreCursorPosition();
                            std.debug.print("x={}, y={}\n\r", .{ pos.x, pos.y });
                            try self.backend.saveCursorPosition();
                            try self.backend.moveCursorTo(pos.x, pos.y);
                        },
                        else => {},
                    },
                    .enter => try self.backend.moveCursorToNextLine(1),
                    .backspace => try self.backend.moveCursorToPreviousLine(1),
                    else => {},
                },

                else => {},
            }
        }

        fn handleScrollEvent(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .escape => try self.enableNormalMode(),
                    .char => switch (event.key.code.char) {
                        'j' => {
                            try self.backend.scrollDown(1);
                            try self.backend.moveCursorDown(1);
                        },
                        'k' => {
                            try self.backend.scrollUp(1);
                            try self.backend.moveCursorUp(1);
                        },
                        else => {},
                    },
                    else => {},
                },

                else => {},
            }
        }

        fn enableNormalMode(self: *Self) !void {
            if (self.mode == .move)
                try self.backend.restoreCursorPosition();
            self.mode = .normal;

            std.debug.print("Normal mode enabled\n\r", .{});
            std.debug.print("Press 'q' to quit,\n\r", .{});
            std.debug.print("      'a' to toggle alternate screen,\n\r", .{});
            std.debug.print("      'p' to toggle polling,\n\r", .{});
            std.debug.print("      'd' to enable debug mode,\n\r", .{});
            std.debug.print("      'm' to enable move mode,\n\r", .{});
            std.debug.print("      's' to enable scroll mode\n\r", .{});
        }

        fn enableDebugMode(self: *Self) void {
            self.mode = .debug;
            std.debug.print("Debug mode enabled\n\r", .{});
            std.debug.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            std.debug.print("      or any other key to see its debug information\n\r", .{});
        }

        fn enableMoveMode(self: *Self) !void {
            self.mode = .move;
            std.debug.print("Move mode enabled\n\r", .{});
            std.debug.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            std.debug.print("      'p' to get current cursor position,\n\r", .{});
            std.debug.print("      'c' to toggle cursor visibility,\n\r", .{});
            std.debug.print("      's' to move to the top left corner,\n\r", .{});
            std.debug.print("      '↑' to move to the top corner,\n\r", .{});
            std.debug.print("      '←' to move to the left corner,\n\r", .{});
            std.debug.print("      'h' to move left,\n\r", .{});
            std.debug.print("      'j' to move down,\n\r", .{});
            std.debug.print("      'k' to move up,\n\r", .{});
            std.debug.print("      'l' to move right\n\r", .{});
            std.debug.print("      'enter' to move to the next line,\n\r", .{});
            std.debug.print("      'backspace' to move to the previous line,\n\r", .{});
            try self.backend.saveCursorPosition();
        }

        fn enableScrollMode(self: *Self) void {
            self.mode = .scroll;
            std.debug.print("Scroll mode enabled\n\r", .{});
            std.debug.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            std.debug.print("      'j' to scroll down,\n\r", .{});
            std.debug.print("      'k' to scroll up\n\r", .{});
        }

        fn toggleAlternateScreen(self: *Self) !void {
            switch (self.alternate_screen) {
                .enabled => {
                    self.alternate_screen = .disabled;
                    try self.backend.leaveAlternateScreen();
                },
                .disabled => {
                    self.alternate_screen = .enabled;
                    try self.backend.enterAlternateScreen();
                    try self.backend.moveCursorTo(0, 0);
                    // Duplicate hints.
                    try self.enableNormalMode();
                },
            }
        }

        fn togglePolling(self: *Self) !void {
            switch (self.polling) {
                .disabled => {
                    self.polling = .enabled;
                    std.debug.print("Enabled polling\n\r", .{});
                },
                .enabled => {
                    self.polling = .disabled;
                    std.debug.print("Disabled polling\n\r", .{});
                },
            }
        }

        fn toggleCursorVisiblity(self: *Self) !void {
            switch (self.cursor) {
                .hidden => {
                    self.cursor = .visible;
                    try self.backend.showCursor();
                },
                .visible => {
                    self.cursor = .hidden;
                    try self.backend.hideCursor();
                },
            }
        }
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.assert((try fuizon.crossterm.isRawModeEnabled()) == false);
    try fuizon.crossterm.enableRawMode();
    std.debug.assert((try fuizon.crossterm.isRawModeEnabled()) == true);
    defer std.debug.assert((fuizon.crossterm.isRawModeEnabled() catch unreachable) == false);
    defer fuizon.crossterm.disableRawMode() catch {};

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var demo = try Demo(@TypeOf(writer)).init(allocator, writer);
    defer demo.deinit() catch {};
    try demo.enableNormalMode();

    try demo.run();
}
