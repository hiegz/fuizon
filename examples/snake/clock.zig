const std = @import("std");
const xev = @import("xev");
const fuizon = @import("fuizon");

pub const Clock = struct {
    loop: *xev.Loop,
    timer: xev.Timer,
    c: xev.Completion,
    c_cancel: xev.Completion,

    freq: u64,
    state: enum { live, idle },

    callback: ClockCallback,

    pub fn init(loop: *xev.Loop, freq: u16, callback: ClockCallback) !Clock {
        var clock: Clock = undefined;

        clock.loop = loop;
        clock.timer = try xev.Timer.init();
        errdefer clock.timer.deinit();

        clock.freq = freq;
        clock.state = .idle;
        clock.callback = callback;

        return clock;
    }

    pub fn deinit(self: Clock) void {
        self.timer.deinit();
    }

    pub fn pause(self: *Clock) void {
        self.state = .idle;
    }

    pub fn run(self: *Clock) void {
        self.state = .live;
        self.timer.reset(
            self.loop,
            &self.c,
            &self.c_cancel,
            self.freq,
            Clock,
            self,
            (struct {
                fn callback(
                    ud: ?*Clock,
                    l: *xev.Loop,
                    c: *xev.Completion,
                    r: xev.Timer.RunError!void,
                ) xev.CallbackAction {
                    _ = l;
                    _ = c;
                    _ = r catch
                        return .disarm;
                    if (ud.?.state == .idle)
                        return .disarm;
                    ud.?.run();
                    ud.?.callback();
                    return .disarm;
                }
            }).callback,
        );
    }

    pub fn live(self: Clock) bool {
        return self.state == .live;
    }

    pub fn idle(self: Clock) bool {
        return self.state == .idle;
    }
};

pub const ClockCallback = *const fn () void;
