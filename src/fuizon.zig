pub const event = @import("event.zig");
pub const Event = event.Event;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyEvent = event.KeyEvent;

pub const keyboard = @import("keyboard.zig");
pub const KeyModifiers = keyboard.KeyModifiers;
pub const KeyModifier = keyboard.KeyModifier;
pub const KeyCode = keyboard.KeyCode;

pub const style = @import("style.zig");
pub const Style = style.Style;
pub const Color = style.Color;
pub const AnsiColor = style.AnsiColor;
pub const RgbColor = style.RgbColor;
pub const Attributes = style.Attributes;

pub const crossterm = @import("backend.zig");

pub const backend = crossterm;

test "fuizon" {
    @import("std").testing.refAllDecls(@This());
}
