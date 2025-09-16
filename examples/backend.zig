const std = @import("std");
const fuizon = @import("fuizon");

// zig fmt: off
var state:            enum { terminated, running                 } = .terminated;
var mode:             enum { normal, debug, move, scroll, insert } = .normal;
var alternate_screen: enum { disabled, enabled                   } = .disabled;
var polling:          enum { disabled, enabled                   } = .disabled;
var cursor:           enum { hidden,   visible                   } = .visible;
var cursor_position:  fuizon.Coordinate                            = .{ .x = 0, .y = 0 };
var attributes:       fuizon.Attributes                            = fuizon.Attributes.none;
// zig fmt: on

fn run() !void {
    state = .running;
    if (polling == .enabled and !try fuizon.event.poll()) return;
    const event = try fuizon.event.read();

    switch (mode) {
        // zig fmt: off
        .normal => try handleNormalEvent(event),
        .debug  => try handleDebugEvent(event),
        .move   => try handleMoveEvent(event),
        .scroll => try handleScrollEvent(event),
        .insert => try handleInsertMode(event),
        // zig fmt: on
    }
}

fn handleNormalEvent(event: fuizon.Event) !void {
    switch (event) {
        .key => switch (event.key.code) {
            .char => switch (event.key.code.char) {
                'q' => state = .terminated,
                't' => try printScreenSize(),
                'a' => try toggleAlternateScreen(),
                'p' => try togglePolling(),
                'd' => try enableDebugMode(),
                'm' => try enableMoveMode(),
                's' => try enableScrollMode(),
                'i' => try enableInsertMode(),
                else => {},
            },
            else => {},
        },
        else => {},
    }
}

fn handleDebugEvent(event: fuizon.Event) !void {
    if (event == .key and event.key.code == .escape) {
        try enableNormalMode();
        return;
    }
    try fuizon.getWriter().print("{}\n\r", .{event});
}

fn handleMoveEvent(event: fuizon.Event) !void {
    switch (event) {
        .key => switch (event.key.code) {
            // zig fmt: off
            .escape     => try enableNormalMode(),
            .char       => try handleCharCode(event.key.code.char),
            // zig fmt: on

            else => {},
        },

        else => {},
    }
}

fn handleCharCode(char: u21) !void {
    switch (char) {
        // zig fmt: off
        'c' => try toggleCursorVisiblity(),
        's' => try fuizon.moveCursorTo(0, 0),
        'h' => try moveCursorLeft(),
        'j' => try moveCursorDown(),
        'k' => try moveCursorUp(),
        'l' => try moveCursorRight(),
        'p' => try printCursorPosition(),
        // zig fmt: on

        else => {},
    }
}

fn handleScrollEvent(event: fuizon.Event) !void {
    switch (event) {
        .key => switch (event.key.code) {
            // zig fmt: off
            .escape => try enableNormalMode(),
            .char   => switch (event.key.code.char) {
                'k' => try scrollUp(),
                'j' => try scrollDown(),

                else => {},
            },
            // zig fmt: on

            else => {},
        },

        else => {},
    }
}

fn handleInsertMode(event: fuizon.Event) !void {
    switch (event) {
        .key => switch (event.key.code) {
            // zig fmt: off
            .escape => try enableNormalMode(),
            .enter  => try fuizon.getWriter().print("\n\r", .{}),
            .char   => {
                if (!event.key.modifiers.contain(&.{.control})) {
                    try fuizon.getWriter().print("{u}", .{event.key.code.char});
                    return;
                }

                switch (event.key.code.char) {
                    'b' => try toggleBoldAttribute(),
                    'd' => try toggleDimAttribute(),
                    'u' => try toggleUnderlineAttribute(),
                    'r' => try toggleReverseAttribute(),
                    'h' => try toggleHiddenAttribute(),
                    else => {},
                }
            },
            // zig fmt: on

            else => {},
        },
        else => {},
    }
}

fn enableNormalMode() !void {
    if (mode == .move)
        try restoreCursorPosition();
    if (mode == .insert) {
        var iterator = attributes.iterator();
        while (iterator.next()) |attribute| {
            try fuizon.resetAttribute(attribute);
        }
        attributes = fuizon.Attributes.none;
        try fuizon.getWriter().print("\n\r", .{});
    }
    mode = .normal;

    try fuizon.getWriter().print("Normal mode enabled\n\r", .{});
    try fuizon.getWriter().print("Press 'q' to quit,\n\r", .{});
    try fuizon.getWriter().print("      't' to get terminal size,\n\r", .{});
    try fuizon.getWriter().print("      'a' to toggle alternate screen,\n\r", .{});
    try fuizon.getWriter().print("      'p' to toggle polling,\n\r", .{});
    try fuizon.getWriter().print("      'd' to enable debug mode,\n\r", .{});
    try fuizon.getWriter().print("      'm' to enable move/clear mode,\n\r", .{});
    try fuizon.getWriter().print("      's' to enable scroll mode\n\r", .{});
    try fuizon.getWriter().print("      'i' to enable insert mode\n\r", .{});
}

fn enableDebugMode() !void {
    mode = .debug;
    try fuizon.getWriter().print("Debug mode enabled\n\r", .{});
    try fuizon.getWriter().print("Press 'escape' to switch back to the normal mode,\n\r", .{});
    try fuizon.getWriter().print("      or any other key to see its debug information\n\r", .{});
}

fn enableMoveMode() !void {
    mode = .move;
    try fuizon.getWriter().print("Move mode enabled\n\r", .{});
    try fuizon.getWriter().print("Press 'escape' to switch back to the normal mode,\n\r", .{});
    try fuizon.getWriter().print("      'p' to get current cursor position,\n\r", .{});
    try fuizon.getWriter().print("      'c' to toggle cursor visibility,\n\r", .{});
    try fuizon.getWriter().print("      's' to move to the top left corner,\n\r", .{});
    try fuizon.getWriter().print("      'h' to move left,\n\r", .{});
    try fuizon.getWriter().print("      'j' to move down,\n\r", .{});
    try fuizon.getWriter().print("      'k' to move up,\n\r", .{});
    try fuizon.getWriter().print("      'l' to move right\n\r", .{});
    try saveCursorPosition();
}

fn enableScrollMode() !void {
    mode = .scroll;
    try fuizon.getWriter().print("Scroll mode enabled\n\r", .{});
    try fuizon.getWriter().print("Press 'escape' to switch back to the normal mode,\n\r", .{});
    try fuizon.getWriter().print("      'j' to scroll down,\n\r", .{});
    try fuizon.getWriter().print("      'k' to scroll up\n\r", .{});
}

fn enableInsertMode() !void {
    mode = .insert;
    try fuizon.getWriter().print("Insert mode enabled\n\r", .{});
    try fuizon.getWriter().print("Press 'escape' to switch back to the normal mode,\n\r", .{});
    try fuizon.getWriter().print("      'Ctrl-b' to toggle the attribute 'bold'\n\r", .{});
    try fuizon.getWriter().print("      'Ctrl-d' to toggle the attribute 'dim'\n\r", .{});
    try fuizon.getWriter().print("      'Ctrl-u' to toggle the attribute 'underline'\n\r", .{});
    try fuizon.getWriter().print("      'Ctrl-r' to toggle the attribute 'reverse'\n\r", .{});
    try fuizon.getWriter().print("      'Ctrl-h' to toggle the attribute 'hidden'\n\r", .{});
    try fuizon.getWriter().print("      or any other key that can be displayed as readable text\n\r", .{});
}

fn toggleAlternateScreen() !void {
    switch (alternate_screen) {
        .enabled => {
            alternate_screen = .disabled;
            try fuizon.leaveAlternateScreen();
        },
        .disabled => {
            alternate_screen = .enabled;
            try fuizon.enterAlternateScreen();
            try fuizon.moveCursorTo(0, 0);
            // Duplicate hints.
            try enableNormalMode();
        },
    }
}

fn togglePolling() !void {
    switch (polling) {
        .disabled => {
            polling = .enabled;
            try fuizon.getWriter().print("Enabled polling\n\r", .{});
        },
        .enabled => {
            polling = .disabled;
            try fuizon.getWriter().print("Disabled polling\n\r", .{});
        },
    }
}

fn toggleCursorVisiblity() !void {
    switch (cursor) {
        .hidden => {
            cursor = .visible;
            try fuizon.showCursor();
        },
        .visible => {
            cursor = .hidden;
            try fuizon.hideCursor();
        },
    }
}

fn toggleBoldAttribute() !void {
    if (attributes.contain(&.{.bold})) {
        attributes.reset(&.{.bold});
        try fuizon.resetAttribute(.bold);
    } else {
        attributes.set(&.{.bold});
        try fuizon.setAttribute(.bold);
    }

    if (attributes.contain(&.{.dim})) {
        try fuizon.setAttribute(.dim);
    }
}

fn toggleDimAttribute() !void {
    if (attributes.contain(&.{.dim})) {
        attributes.reset(&.{.dim});
        try fuizon.resetAttribute(.dim);
    } else {
        attributes.set(&.{.dim});
        try fuizon.setAttribute(.dim);
    }

    if (attributes.contain(&.{.bold})) {
        try fuizon.setAttribute(.bold);
    }
}

fn toggleUnderlineAttribute() !void {
    if (attributes.contain(&.{.underline})) {
        attributes.reset(&.{.underline});
        try fuizon.resetAttribute(.underline);
    } else {
        attributes.set(&.{.underline});
        try fuizon.setAttribute(.underline);
    }
}

fn toggleReverseAttribute() !void {
    if (attributes.contain(&.{.reverse})) {
        attributes.reset(&.{.reverse});
        try fuizon.resetAttribute(.reverse);
    } else {
        attributes.set(&.{.reverse});
        try fuizon.setAttribute(.reverse);
    }
}

fn toggleHiddenAttribute() !void {
    if (attributes.contain(&.{.hidden})) {
        attributes.reset(&.{.hidden});
        try fuizon.resetAttribute(.hidden);
    } else {
        attributes.set(&.{.hidden});
        try fuizon.setAttribute(.hidden);
    }
}

fn printScreenSize() !void {
    const screen = try fuizon.getScreenSize();
    try fuizon.getWriter().print("{}x{}\n\r", .{ screen.width, screen.height });
}

fn printCursorPosition() !void {
    try fuizon.hideCursor();
    const pos = try getCursorPosition();
    try restoreCursorPosition();
    try fuizon.getWriter().print("x={}, y={}\n\r", .{ pos.x, pos.y });
    try saveCursorPosition();
    try fuizon.moveCursorTo(pos.x, pos.y);
    try fuizon.showCursor();
}

fn saveCursorPosition() !void {
    const _cursor = try getCursorPosition();
    cursor_position.x = _cursor.x;
    cursor_position.y = _cursor.y;
}

fn restoreCursorPosition() !void {
    try fuizon.moveCursorTo(cursor_position.x, cursor_position.y);
}

fn getCursorPosition() !fuizon.Coordinate {
    try fuizon.getWriter().flush();
    const _cursor = try fuizon.getCursorPosition();
    return .{ .x = _cursor.x, .y = _cursor.y };
}

fn moveCursorUp() !void {
    const _cursor = try getCursorPosition();
    if (_cursor.y == 0) return;
    try fuizon.moveCursorTo(_cursor.x, _cursor.y - 1);
}

fn moveCursorDown() !void {
    const _cursor = try getCursorPosition();
    const screen = try fuizon.getScreenSize();
    if (_cursor.y + 1 == screen.height) return;
    try fuizon.moveCursorTo(_cursor.x, _cursor.y + 1);
}

fn moveCursorLeft() !void {
    const _cursor = try getCursorPosition();
    if (_cursor.x == 0) return;
    try fuizon.moveCursorTo(_cursor.x - 1, _cursor.y);
}

fn moveCursorRight() !void {
    const _cursor = try getCursorPosition();
    const screen = try fuizon.getScreenSize();
    if (_cursor.x + 1 == screen.width) return;
    try fuizon.moveCursorTo(_cursor.x + 1, _cursor.y);
}

fn scrollUp() !void {
    try fuizon.scrollUp(1);
    try moveCursorUp();
}

fn scrollDown() !void {
    const _cursor = try getCursorPosition();
    const screen = try fuizon.getScreenSize();

    if (_cursor.y + 1 == screen.height)
        return;

    try fuizon.scrollDown(1);
    try moveCursorDown();
}

pub fn main() !void {
    try fuizon.init(std.heap.page_allocator, 1024, .stdout);
    defer fuizon.deinit(std.heap.page_allocator);

    defer fuizon.getWriter().flush() catch {};

    try fuizon.enableRawMode();
    defer fuizon.disableRawMode() catch {};

    try saveCursorPosition();

    state = .running;
    try enableNormalMode();
    try fuizon.getWriter().flush();
    while (state == .running) {
        try run();
        try fuizon.getWriter().flush();
    }
}
