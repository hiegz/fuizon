const std = @import("std");
const fuizon = @import("fuizon.zig");

const KeyCode = fuizon.keyboard.KeyCode;
const KeyModifiers = fuizon.keyboard.KeyModifiers;

pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: KeyModifiers,
};

pub const ResizeEvent = struct {
    width: u16,
    height: u16,
};

pub const Event = union(enum) {
    key: KeyEvent,
    resize: ResizeEvent,
};

/// Checks if events are available for reading.
pub fn poll() !bool {
    // Not implemented
    return false;
}

/// Reads a single event from standard input.
pub fn read() !Event {
    // Not implemented
    return undefined;
}
