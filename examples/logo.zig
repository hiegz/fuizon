const std = @import("std");
const fuizon = @import("fuizon");

const Logo = struct {
    // zig fmt: off

    const WIDTH:  u16 = 7 * 2;
    const HEIGHT: u16 = 10;

    const red:         fuizon.Character = .init(' ', .init(.default, .Rgb(250,  22, 50), .none));
    const light_red:   fuizon.Character = .init(' ', .init(.default, .Rgb(250,  81, 50), .none));
    const dark_yellow: fuizon.Character = .init(' ', .init(.default, .Rgb(250, 207, 14), .none));
    const yellow:      fuizon.Character = .init(' ', .init(.default, .Rgb(250, 227, 13), .none));
    const orange:      fuizon.Character = .init(' ', .init(.default, .Rgb(250, 130,  8), .none));

    // zig fmt: on

    canvas: fuizon.Buffer,

    pub fn init(gpa: std.mem.Allocator) error{OutOfMemory}!Logo {
        var self: Logo = undefined;
        self.canvas = try fuizon.Buffer.initDimensions(gpa, .init(Logo.WIDTH, Logo.HEIGHT));

        self.draw(2, 0, red);
        self.draw(0, 1, red);
        self.draw(6, 2, red);

        self.draw(3, 2, red);
        self.draw(3, 3, red);
        self.draw(4, 3, red);
        self.draw(2, 4, red);
        self.draw(1, 5, red);
        self.draw(0, 6, red);
        self.draw(0, 7, red);
        self.draw(0, 8, red);
        self.draw(1, 9, red);
        self.draw(5, 5, red);
        self.draw(5, 6, red);
        self.draw(5, 7, red);
        self.draw(4, 8, red);
        self.draw(3, 9, red);

        self.draw(4, 7, light_red);
        self.draw(4, 6, light_red);
        self.draw(4, 5, light_red);
        self.draw(4, 4, light_red);
        self.draw(3, 4, light_red);
        self.draw(2, 5, light_red);
        self.draw(1, 6, light_red);

        self.draw(2, 6, orange);
        self.draw(1, 7, orange);
        self.draw(3, 8, orange);

        self.draw(1, 8, dark_yellow);
        self.draw(2, 9, dark_yellow);
        self.draw(3, 5, dark_yellow);
        self.draw(3, 6, dark_yellow);

        self.draw(3, 7, yellow);
        self.draw(2, 7, yellow);
        self.draw(2, 8, yellow);

        return self;
    }

    pub fn deinit(
        self: Logo,
        gpa: std.mem.Allocator,
    ) void {
        self.canvas.deinit(gpa);
    }

    pub fn measure(
        self: Logo,
        opts: fuizon.Widget.MeasureOptions,
    ) anyerror!fuizon.Dimensions {
        _ = self;

        return .init(
            @min(opts.max_width, Logo.WIDTH),
            @min(opts.max_height, Logo.HEIGHT),
        );
    }

    pub fn render(
        self: Logo,
        buffer: *fuizon.Buffer,
        area: fuizon.Area,
    ) anyerror!void {
        var container = fuizon.Container.empty;
        container.child = self.canvas.widget();
        try container.render(buffer, area);
    }

    fn draw(self: *Logo, x: anytype, y: anytype, character: fuizon.Character) void {
        self.canvas.set(x * 2, y, character);
        self.canvas.set(x * 2 + 1, y, character);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try fuizon.init();
    defer fuizon.deinit() catch {};

    try fuizon.enterAlternateScreen();
    defer fuizon.leaveAlternateScreen() catch {};

    const logo = try Logo.init(allocator);
    defer logo.deinit(allocator);

    while (true) {
        try fuizon.render(&logo, .fullscreen, .{});

        const event = try fuizon.readInput(.{});
        if (event == null)
            break;
        switch (event.?) {
            .key => |k| if (k.code == .char and k.code.char == 'q') break,
            .eof => break,
            .resize => continue,
        }
    }

    try fuizon.clear();
}
