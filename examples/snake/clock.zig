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

    pub fn reset(self: *Clock) void {
        self.startTimer();
    }

    pub fn run(self: *Clock) void {
        if (self.live())
            return;
        self.state = .live;
        self.startTimer();
    }

    pub fn pause(self: *Clock) void {
        if (self.idle())
            return;
        self.state = .idle;
        self.cancelTimer();
    }

    pub fn live(self: Clock) bool {
        return self.state == .live;
    }

    pub fn idle(self: Clock) bool {
        return self.state == .idle;
    }

    fn startTimer(self: *Clock) void {
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
                    _ = r catch |err| {
                        std.debug.assert(err == error.Canceled);
                        ud.?.state = .idle;
                        return .disarm;
                    };
                    std.debug.assert(ud.?.state == .live);
                    ud.?.startTimer();
                    ud.?.callback();
                    return .disarm;
                }
            }).callback,
        );
    }

    fn cancelTimer(self: *Clock) void {
        self.timer.cancel(
            self.loop,
            &self.c,
            &self.c_cancel,
            Clock,
            self,
            (struct {
                fn callback(
                    ud: ?*Clock,
                    l: *xev.Loop,
                    c: *xev.Completion,
                    r: xev.Timer.CancelError!void,
                ) xev.CallbackAction {
                    _ = l;
                    _ = c;
                    _ = r catch unreachable;
                    std.debug.assert(ud.?.state == .idle);
                    return .disarm;
                }
            }).callback,
        );
    }
};

pub const ClockCallback = *const fn () void;
