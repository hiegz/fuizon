const fuizon = @import("fuizon.zig");
const c = @import("headers.zig").c;

pub const event = struct {
    /// Checks if events are available for reading.
    pub fn poll() error{BackendError}!bool {
        var ret: c_int = undefined;
        var is_available: c_int = undefined;
        ret = c.crossterm_event_poll(&is_available);
        if (0 != ret) return error.BackendError;

        if (is_available == 1) {
            return true;
        } else if (is_available == 0) {
            return false;
        } else {
            return error.BackendError;
        }
    }

    /// Reads a single event from standard input.
    pub fn read() error{BackendError}!fuizon.Event {
        var ret: c_int = undefined;
        var ev: c.crossterm_event = undefined;
        ret = c.crossterm_event_read(&ev);
        if (0 != ret) return error.BackendError;

        if (fuizon.Event.fromCrosstermEvent(ev)) |e| {
            return e;
        } else {
            return error.BackendError;
        }
    }
};
