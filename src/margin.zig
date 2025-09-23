// zig fmt: off

pub const Margin = struct {
    top:    u16 = 0,
    bottom: u16 = 0,
    left:   u16 = 0,
    right:  u16 = 0,

    pub const none: Margin = .{};

    pub fn init(top: u16, bottom: u16, left: u16, right: u16) Margin {
        var margin: Margin = undefined;
        margin.top = top;
        margin.bottom = bottom;
        margin.left = left;
        margin.right = right;
        return margin;
    }

    pub fn set(self: *Margin, top: u16, bottom: u16, left: u16, right: u16) void {
        self.top    = top;
        self.bottom = bottom;
        self.left   = left;
        self.right  = right;
    }
};
