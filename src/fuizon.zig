pub const event = @import("event.zig");
pub const Event = event.Event;
pub const ResizeEvent = event.ResizeEvent;
pub const KeyEvent = event.KeyEvent;
pub const KeyModifiers = event.KeyModifiers;
pub const KeyCode = event.KeyCode;

pub const style = @import("style.zig");
pub const Style = style.Style;
pub const Color = style.Color;
pub const AnsiColor = style.AnsiColor;
pub const RgbColor = style.RgbColor;
pub const Attributes = style.Attributes;

pub const crossterm = @import("crossterm.zig");

pub const backend = crossterm;
