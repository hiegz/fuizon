const std = @import("std");
const fuizon = @import("fuizon");

fn Demo(comptime WriterType: type) type {
    return struct {
        const Self = @This();

        writer: WriterType,
        state: enum { terminated, running },
        mode: enum { normal, debug, move, scroll, insert },
        alternate_screen: enum { disabled, enabled },
        polling: enum { disabled, enabled },
        cursor: enum { hidden, visible },

        attributes: fuizon.Attributes,

        fn init(writer: WriterType) !Self {
            var self: Self = undefined;
            errdefer self.deinit() catch {};

            try fuizon.crossterm.raw_mode.enable();
            std.debug.assert(try fuizon.crossterm.raw_mode.isEnabled() == true);

            self.writer = writer;
            self.state = .terminated;
            self.mode = .normal;
            self.alternate_screen = .disabled;
            self.polling = .disabled;
            self.cursor = .visible;
            self.attributes = fuizon.Attributes.none;

            return self;
        }

        fn deinit(self: *Self) !void {
            if (self.alternate_screen == .enabled)
                try fuizon.crossterm.alternate_screen.leave(self.writer);
            if (self.cursor == .hidden)
                try fuizon.crossterm.cursor.show(self.writer);
            if (self.mode == .move)
                try fuizon.crossterm.cursor.restore(self.writer);
            try fuizon.crossterm.raw_mode.disable();
            std.debug.assert(try fuizon.crossterm.raw_mode.isEnabled() == false);
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
                .insert => try self.handleInsertMode(event),
            }
        }

        fn handleNormalEvent(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .char => switch (event.key.code.char) {
                        'q' => self.state = .terminated,
                        't' => {
                            const size = try fuizon.crossterm.screen.size();
                            try self.writer.print("{}x{}\n\r", .{ size.width, size.height });
                        },
                        'a' => try self.toggleAlternateScreen(),
                        'p' => try self.togglePolling(),
                        'd' => try self.enableDebugMode(),
                        'm' => try self.enableMoveMode(),
                        's' => try self.enableScrollMode(),
                        'i' => try self.enableInsertMode(),
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
            try self.writer.print("{}\n\r", .{event});
        }

        fn handleMoveEvent(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .escape => try self.enableNormalMode(),
                    .left_arrow => try fuizon.crossterm.cursor.moveToCol(self.writer, 0),
                    .up_arrow => try fuizon.crossterm.cursor.moveToRow(self.writer, 0),
                    .char => switch (event.key.code.char) {
                        'c' => try self.toggleCursorVisiblity(),
                        'a' => try fuizon.crossterm.screen.clearAll(self.writer),
                        'A' => try fuizon.crossterm.screen.clearPurge(self.writer),
                        'J' => try fuizon.crossterm.screen.clearFromCursorDown(self.writer),
                        'K' => try fuizon.crossterm.screen.clearFromCursorUp(self.writer),
                        'd' => try fuizon.crossterm.screen.clearCurrentLine(self.writer),
                        'n' => try fuizon.crossterm.screen.clearUntilNewLine(self.writer),
                        's' => try fuizon.crossterm.cursor.moveTo(self.writer, 0, 0),
                        'h' => try fuizon.crossterm.cursor.moveLeft(self.writer, 1),
                        'j' => try fuizon.crossterm.cursor.moveDown(self.writer, 1),
                        'k' => try fuizon.crossterm.cursor.moveUp(self.writer, 1),
                        'l' => try fuizon.crossterm.cursor.moveRight(self.writer, 1),
                        'p' => {
                            const pos = try fuizon.crossterm.cursor.position();
                            try fuizon.crossterm.cursor.restore(self.writer);
                            try self.writer.print("x={}, y={}\n\r", .{ pos.x, pos.y });
                            try fuizon.crossterm.cursor.save(self.writer);
                            try fuizon.crossterm.cursor.moveTo(self.writer, pos.x, pos.y);
                        },
                        else => {},
                    },
                    .enter => try fuizon.crossterm.cursor.moveToNextLine(self.writer, 1),
                    .backspace => try fuizon.crossterm.cursor.moveToPreviousLine(self.writer, 1),
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
                            if ((try fuizon.crossterm.cursor.position()).y + 1 ==
                                (try fuizon.crossterm.screen.size()).height)
                                return;
                            try fuizon.crossterm.screen.scrollDown(self.writer, 1);
                            try fuizon.crossterm.cursor.moveDown(self.writer, 1);
                        },
                        'k' => {
                            try fuizon.crossterm.screen.scrollUp(self.writer, 1);
                            try fuizon.crossterm.cursor.moveUp(self.writer, 1);
                        },
                        else => {},
                    },
                    else => {},
                },

                else => {},
            }
        }

        fn handleInsertMode(self: *Self, event: fuizon.Event) !void {
            switch (event) {
                .key => switch (event.key.code) {
                    .escape => try self.enableNormalMode(),
                    .char => {
                        if (!event.key.modifiers.contain(&.{.control})) {
                            try self.writer.print("{u}", .{event.key.code.char});
                            return;
                        }

                        switch (event.key.code.char) {
                            'b' => try self.toggleBoldAttribute(),
                            'd' => try self.toggleDimAttribute(),
                            'u' => try self.toggleUnderlinedAttribute(),
                            'r' => try self.toggleReverseAttribute(),
                            'h' => try self.toggleHiddenAttribute(),
                            else => {},
                        }
                    },
                    .enter => try self.writer.print("\n\r", .{}),
                    else => {},
                },
                else => {},
            }
        }

        fn enableNormalMode(self: *Self) !void {
            if (self.mode == .move)
                try fuizon.crossterm.cursor.restore(self.writer);
            if (self.mode == .insert) {
                self.attributes = fuizon.Attributes.none;
                try fuizon.crossterm.text.attributes.reset(self.writer);
                try self.writer.print("\n\r", .{});
            }
            self.mode = .normal;

            try self.writer.print("Normal mode enabled\n\r", .{});
            try self.writer.print("Press 'q' to quit,\n\r", .{});
            try self.writer.print("      't' to get terminal size,\n\r", .{});
            try self.writer.print("      'a' to toggle alternate screen,\n\r", .{});
            try self.writer.print("      'p' to toggle polling,\n\r", .{});
            try self.writer.print("      'd' to enable debug mode,\n\r", .{});
            try self.writer.print("      'm' to enable move/clear mode,\n\r", .{});
            try self.writer.print("      's' to enable scroll mode\n\r", .{});
            try self.writer.print("      'i' to enable insert mode\n\r", .{});
        }

        fn enableDebugMode(self: *Self) !void {
            self.mode = .debug;
            try self.writer.print("Debug mode enabled\n\r", .{});
            try self.writer.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            try self.writer.print("      or any other key to see its debug information\n\r", .{});
        }

        fn enableMoveMode(self: *Self) !void {
            self.mode = .move;
            try self.writer.print("Move mode enabled\n\r", .{});
            try self.writer.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            try self.writer.print("      'p' to get current cursor position,\n\r", .{});
            try self.writer.print("      'c' to toggle cursor visibility,\n\r", .{});
            try self.writer.print("      'd' to clear the current line,\n\r", .{});
            try self.writer.print("      'n' to clear from the cursor position until the new line,\n\r", .{});
            try self.writer.print("      'J' to clear the terminal screen from the cursor position downwards,\n\r", .{});
            try self.writer.print("      'K' to clear the terminal screen from the cursor position upwards,\n\r", .{});
            try self.writer.print("      'A' to clear the terminal screen and history,\n\r", .{});
            try self.writer.print("      'a' to clear the terminal screen,\n\r", .{});
            try self.writer.print("      's' to move to the top left corner,\n\r", .{});
            try self.writer.print("      '↑' to move to the top corner,\n\r", .{});
            try self.writer.print("      '←' to move to the left corner,\n\r", .{});
            try self.writer.print("      'h' to move left,\n\r", .{});
            try self.writer.print("      'j' to move down,\n\r", .{});
            try self.writer.print("      'k' to move up,\n\r", .{});
            try self.writer.print("      'l' to move right\n\r", .{});
            try self.writer.print("      'enter' to move to the next line,\n\r", .{});
            try self.writer.print("      'backspace' to move to the previous line,\n\r", .{});
            try fuizon.crossterm.cursor.save(self.writer);
        }

        fn enableScrollMode(self: *Self) !void {
            self.mode = .scroll;
            try self.writer.print("Scroll mode enabled\n\r", .{});
            try self.writer.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            try self.writer.print("      'j' to scroll down,\n\r", .{});
            try self.writer.print("      'k' to scroll up\n\r", .{});
        }

        fn enableInsertMode(self: *Self) !void {
            self.mode = .insert;
            try self.writer.print("Insert mode enabled\n\r", .{});
            try self.writer.print("Press 'escape' to switch back to the normal mode,\n\r", .{});
            try self.writer.print("      'Ctrl-b' to toggle the attribute 'bold'\n\r", .{});
            try self.writer.print("      'Ctrl-d' to toggle the attribute 'dim'\n\r", .{});
            try self.writer.print("      'Ctrl-u' to toggle the attribute 'underlined'\n\r", .{});
            try self.writer.print("      'Ctrl-r' to toggle the attribute 'reverse'\n\r", .{});
            try self.writer.print("      'Ctrl-h' to toggle the attribute 'hidden'\n\r", .{});
            try self.writer.print("      or any other key that can be displayed as readable text\n\r", .{});
        }

        fn toggleAlternateScreen(self: *Self) !void {
            switch (self.alternate_screen) {
                .enabled => {
                    self.alternate_screen = .disabled;
                    try fuizon.crossterm.alternate_screen.leave(self.writer);
                },
                .disabled => {
                    self.alternate_screen = .enabled;
                    try fuizon.crossterm.alternate_screen.enter(self.writer);
                    try fuizon.crossterm.cursor.moveTo(self.writer, 0, 0);
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
                    try fuizon.crossterm.cursor.show(self.writer);
                },
                .visible => {
                    self.cursor = .hidden;
                    try fuizon.crossterm.cursor.hide(self.writer);
                },
            }
        }

        fn toggleBoldAttribute(self: *Self) !void {
            if (self.attributes.contain(&.{.bold})) {
                self.attributes.reset(&.{.bold});
                try fuizon.crossterm.text.attribute.bold.reset(self.writer);
            } else {
                self.attributes.set(&.{.bold});
                try fuizon.crossterm.text.attribute.bold.set(self.writer);
            }

            if (self.attributes.contain(&.{.dim})) {
                try fuizon.crossterm.text.attribute.dim.set(self.writer);
            }
        }

        fn toggleDimAttribute(self: *Self) !void {
            if (self.attributes.contain(&.{.dim})) {
                self.attributes.reset(&.{.dim});
                try fuizon.crossterm.text.attribute.dim.reset(self.writer);
            } else {
                self.attributes.set(&.{.dim});
                try fuizon.crossterm.text.attribute.dim.set(self.writer);
            }

            if (self.attributes.contain(&.{.bold})) {
                try fuizon.crossterm.text.attribute.bold.set(self.writer);
            }
        }

        fn toggleUnderlinedAttribute(self: *Self) !void {
            if (self.attributes.contain(&.{.underlined})) {
                self.attributes.reset(&.{.underlined});
                try fuizon.crossterm.text.attribute.underline.reset(self.writer);
            } else {
                self.attributes.set(&.{.underlined});
                try fuizon.crossterm.text.attribute.underline.set(self.writer);
            }
        }

        fn toggleReverseAttribute(self: *Self) !void {
            if (self.attributes.contain(&.{.reverse})) {
                self.attributes.reset(&.{.reverse});
                try fuizon.crossterm.text.attribute.reverse.reset(self.writer);
            } else {
                self.attributes.set(&.{.reverse});
                try fuizon.crossterm.text.attribute.reverse.set(self.writer);
            }
        }

        fn toggleHiddenAttribute(self: *Self) !void {
            if (self.attributes.contain(&.{.hidden})) {
                self.attributes.reset(&.{.hidden});
                try fuizon.crossterm.text.attribute.hidden.reset(self.writer);
            } else {
                self.attributes.set(&.{.hidden});
                try fuizon.crossterm.text.attribute.hidden.set(self.writer);
            }
        }
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var demo = try Demo(@TypeOf(writer)).init(writer);
    defer demo.deinit() catch {};
    try demo.enableNormalMode();

    try demo.run();
}
