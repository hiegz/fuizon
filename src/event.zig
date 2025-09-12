const std = @import("std");
const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

const KeyCode = fuizon.keyboard.KeyCode;
const KeyModifiers = fuizon.keyboard.KeyModifiers;

pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers,

    pub fn fromCrosstermKeyEvent(event: c.crossterm_key_event) ?KeyEvent {
        return .{
            .code = KeyCode.fromCrosstermKeyCode(event.type, event.code) orelse return null,
            .modifiers = KeyModifiers.fromCrosstermKeyModifiers(event.modifiers),
        };
    }
};

pub const ResizeEvent = struct {
    width: u16,
    height: u16,

    pub fn fromCrosstermResizeEvent(event: c.crossterm_resize_event) ResizeEvent {
        return .{
            .width = event.width,
            .height = event.height,
        };
    }
};

pub const Event = union(enum) {
    key: KeyEvent,
    resize: ResizeEvent,

    pub fn fromCrosstermEvent(event: c.crossterm_event) ?Event {
        switch (event.type) {
            c.CROSSTERM_KEY_EVENT => return .{ .key = KeyEvent.fromCrosstermKeyEvent(event.unnamed_0.key) orelse return null },
            c.CROSSTERM_RESIZE_EVENT => return .{ .resize = ResizeEvent.fromCrosstermResizeEvent(event.unnamed_0.resize) },
            else => return null,
        }
    }
};

/// Checks if events are available for reading.
pub fn poll() error{TerminalError}!bool {
    var ret: c_int = undefined;
    var is_available: c_int = undefined;
    ret = c.crossterm_event_poll(&is_available);
    if (0 != ret) return error.TerminalError;

    if (is_available == 1) {
        return true;
    } else if (is_available == 0) {
        return false;
    } else {
        return error.TerminalError;
    }
}

/// Reads a single event from standard input.
pub fn read() error{TerminalError}!fuizon.event.Event {
    var ret: c_int = undefined;
    var ev: c.crossterm_event = undefined;
    ret = c.crossterm_event_read(&ev);
    if (0 != ret) return error.TerminalError;

    if (fuizon.event.Event.fromCrosstermEvent(ev)) |e| {
        return e;
    } else {
        return error.TerminalError;
    }
}

//
// Tests
//

test "from-crossterm-to-fuizon-resize-event" {
    try std.testing.expectEqual(
        Event{
            .resize = .{
                .width = 59,
                .height = 15,
            },
        },
        Event.fromCrosstermEvent(c.crossterm_event{
            .type = c.CROSSTERM_RESIZE_EVENT,
            .unnamed_0 = .{
                .resize = .{
                    .width = 59,
                    .height = 15,
                },
            },
        }),
    );
}

test "from-crossterm-to-fuizon-key-event" {
    try std.testing.expectEqual(
        Event{
            .key = .{
                .code = .{ .char = 59 },
                .modifiers = KeyModifiers.all,
            },
        },
        Event.fromCrosstermEvent(c.crossterm_event{
            .type = c.CROSSTERM_KEY_EVENT,
            .unnamed_0 = .{
                .key = c.crossterm_key_event{
                    .type = c.CROSSTERM_CHAR_KEY,
                    .code = 59,
                    // zig fmt: off
                    .modifiers = c.CROSSTERM_SHIFT_KEY_MODIFIER 
                               | c.CROSSTERM_CONTROL_KEY_MODIFIER 
                               | c.CROSSTERM_ALT_KEY_MODIFIER 
                               | c.CROSSTERM_SUPER_KEY_MODIFIER 
                               | c.CROSSTERM_HYPER_KEY_MODIFIER 
                               | c.CROSSTERM_META_KEY_MODIFIER 
                               | c.CROSSTERM_KEYPAD_KEY_MODIFIER 
                               | c.CROSSTERM_CAPS_LOCK_KEY_MODIFIER 
                               | c.CROSSTERM_NUM_LOCK_KEY_MODIFIER,
                    // zig fmt: on
                },
            },
        }),
    );
}

test "from-crossterm-to-fuizon-event-with-invalid-event-type" {
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = std.math.maxInt(u32),
            .unnamed_0 = undefined,
        }),
    );
}

test "from-crossterm-to-fuizon-key-event-with-invalid-key-code-type" {
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = c.CROSSTERM_KEY_EVENT,
            .unnamed_0 = .{
                .key = c.crossterm_key_event{
                    .type = std.math.maxInt(u32),
                    .code = undefined,
                    .modifiers = undefined,
                },
            },
        }),
    );
}

test "from-crossterm-to-fuizon-key-event-with-invalid-key-code" {
    try std.testing.expectEqual(
        null,
        Event.fromCrosstermEvent(.{
            .type = c.CROSSTERM_KEY_EVENT,
            .unnamed_0 = .{
                .key = .{
                    .type = c.CROSSTERM_CHAR_KEY,
                    .code = std.math.maxInt(u21) + 1,
                    .modifiers = undefined,
                },
            },
        }),
    );
}
