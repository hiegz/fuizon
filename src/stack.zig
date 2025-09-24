const std = @import("std");
const Area = @import("area.zig").Area;
const Buffer = @import("buffer.zig").Buffer;
const Text = @import("text.zig").Text;
const Dimensions = @import("dimensions.zig").Dimensions;
const StackConstraint = @import("stack_constraint.zig").StackConstraint;
const StackDirection = @import("stack_direction.zig").StackDirection;
const StackItem = @import("stack_item.zig").StackItem;
const Widget = @import("widget.zig").Widget;

pub const Stack = struct {
    direction: StackDirection,
    item_list: std.ArrayList(StackItem),

    pub fn empty(direction: StackDirection) Stack {
        return .{ .direction = direction, .item_list = .empty };
    }

    pub fn init(
        direction: StackDirection,
        gpa: std.mem.Allocator,
        items: []const StackItem,
    ) error{OutOfMemory}!Stack {
        var self: Stack = empty(direction);
        for (items) |item|
            try self.push(gpa, item);
        return self;
    }

    pub fn horizontal(
        gpa: std.mem.Allocator,
        items: []const StackItem,
    ) error{OutOfMemory}!Stack {
        return .init(.horizontal, gpa, items);
    }

    pub fn vertical(
        gpa: std.mem.Allocator,
        items: []const StackItem,
    ) error{OutOfMemory}!Stack {
        return .init(.vertical, gpa, items);
    }

    pub fn deinit(
        self: *Stack,
        gpa: std.mem.Allocator,
    ) void {
        self.item_list.deinit(gpa);
    }

    pub fn push(
        self: *Stack,
        gpa: std.mem.Allocator,
        item: StackItem,
    ) error{OutOfMemory}!void {
        try self.item_list.append(gpa, item);
    }

    pub fn pop(self: *Stack) ?StackItem {
        return self.item_list.pop();
    }

    // zig fmt: off

    fn selectPrimarySize(self: Stack, width: u16, height: u16) u16 {
        return switch (self.direction) {
            .horizontal => width,
            .vertical   => height,
        };
    }

    fn selectSecondarySize(self: Stack, width: u16, height: u16) u16 {
        return switch (self.direction) {
            .horizontal => height,
            .vertical   => width,
        };
    }

    fn selectWidth(self: Stack, primary: u16, secondary: u16) u16 {
        return switch (self.direction) {
            .horizontal => primary,
            .vertical   => secondary,
        };
    }

    fn selectHeight(self: Stack, primary: u16, secondary: u16) u16 {
        return switch (self.direction) {
            .horizontal => secondary,
            .vertical   => primary,
        };
    }

    fn distribute(self: Stack, space: u16) void {
        var remaining:    u16 = space;
        var total_factor: u16 = 0;

        for (self.item_list.items) |*item| {
            item._value = switch (item.constraint) {
                .auto       => item._value,
                .fixed      => |value|    value,
                .percentage => |value|    percentageOf(space, value),
                .fraction   => |fraction|
                    fractionOf(
                        space,
                        fraction.numerator,
                        fraction.denominator,
                    ),

                // These constraints depend on remaining space from other widgets.
                // Since none have been processed yet, we only sum the fill factors for now.
                .fill => |factor| {
                    total_factor += factor;
                    continue;
                },
            };

            if (item._value > remaining) {
                item._value = remaining;
                remaining   = 0;
                break;
            }
            remaining -= item._value;
        }

        const space_to_fill = remaining;

        for (self.item_list.items) |*item| {
            if (item.constraint != .fill)
                continue;

            const factor = item.constraint.fill;
            item._value  = fractionOf(space_to_fill, factor, total_factor);
            remaining   -= item._value;
        }

        if (remaining > 0) {
            self.item_list.items[self.item_list.items.len - 1]._value += remaining;
        }
    }

    pub fn measure(self: Stack, opts: Widget.MeasureOptions) anyerror!Dimensions {
        // primary size of the layout
        //
        // - width for horizontal
        // - height for vertical
        var primary: u16 = 0;

        // secondary size of the layut
        //
        // - width for vertical
        // - height for horizontal
        var secondary: u16 = 0;

        // sum of all fixed item sizes + the minimal space required to
        // represent the fill constraints.
        var fixed_space: u16 = 0;

        // sum of all fractions and percentages.
        var fraction_sum: f32 = 0;

        // sum of all fill factors.
        var factor_sum: u16 = 0;

        // measure items, gather some of the above info, and select optimal
        // secondary size.
        for (self.item_list.items) |*item| {
            item._dimensions = try item.widget.measure(opts);

            const w = item._dimensions.width;
            const h = item._dimensions.height;

            switch (item.constraint) {
                .auto       =>     fixed_space  += self.selectPrimarySize(w, h),
                .fixed      => |v| fixed_space  += v,
                .fill       => |v| factor_sum   += v,
                .percentage => |v| fraction_sum += @as(f32, @floatFromInt(v)) / 100.0,
                .fraction   => |v| {
                    const numerator:   f32 = @floatFromInt(v.numerator);
                    const denominator: f32 = @floatFromInt(v.denominator);

                    fraction_sum += numerator / denominator;
                },
            }

            secondary = @max(secondary, self.selectSecondarySize(w, h));
        }

        if (fraction_sum > 1.0)
            @panic("Unsatisfiable constraints");

        // find an optimal space for fill constraints
        // and add it to |fixed_space|
        fixed_space +=
            fill_space: {
                const ffactor_sum: f32 = @floatFromInt(factor_sum);
                var   fspace:      f32 = 0;

                for (self.item_list.items) |item| {
                    if (item.constraint != .fill) continue;

                    const  w = item._dimensions.width;
                    const  h = item._dimensions.height;
                    const  p = self.selectPrimarySize(w, h);

                    const fp = @as(f32, @floatFromInt(p));
                    const ff = @as(f32, @floatFromInt(item.constraint.fill));
                    const fs = (ffactor_sum / ff) * fp;

                    fspace = @max(fspace, fs);
                }

                break :fill_space @intFromFloat(fspace);
            };

        // fixed space is already a good candidate for the primary size
        primary = @intFromFloat(1 / (1.0 - fraction_sum) * @as(f32, @floatFromInt(fixed_space)));

        // find another candiate for the primary size (if any)
        for (self.item_list.items) |item| {
            const  w = item._dimensions.width;
            const  h = item._dimensions.height;
            const  p = self.selectPrimarySize(w, h);
            const fp = @as(f32, @floatFromInt(p));

            const candidate: f32 =
                switch (item.constraint) {
                    .percentage => |v|
                        (100.0 / @as(f32, @floatFromInt(v))) * fp,

                    .fraction => |v| tag: {
                        const numerator:   f32  = @floatFromInt(v.numerator);
                        const denominator: f32  = @floatFromInt(v.denominator);

                        break :tag (denominator / numerator) * fp;
                    },

                    else => 0,
                };

            primary = @max(primary, @as(u16, @intFromFloat(candidate)));
        }

        return .init(
            @min(opts.max_width,  self.selectWidth(primary,  secondary)),
            @min(opts.max_height, self.selectHeight(primary, secondary)),
        );
    }

    pub fn render(
        self: Stack,
        buffer: *Buffer,
        area: Area,
    ) anyerror!void {
        for (self.item_list.items) |*item| {
            if (item.constraint != .auto)
                continue;

            const max_width  = area.width;
            const max_height = area.height;
            const dimensions = try item.widget.measure(.opts(max_width, max_height));

            item._value = self.selectPrimarySize(dimensions.width, dimensions.height);
        }

        self.distribute(self.selectPrimarySize(area.width, area.height));

        var coord = switch (self.direction) {
            .horizontal => area.left(),
            .vertical   => area.top(),
        };

        for (self.item_list.items) |item| {
            try switch (self.direction) {
                .horizontal => item.widget.render(buffer, Area.init(item._value, area.height, coord, area.y)),
                .vertical   => item.widget.render(buffer, Area.init( area.width, item._value, area.x, coord)),
            };
            coord += item._value;
        }
    }

    // zig fmt: on

    pub fn widget(self: *const Stack) Widget {
        return Widget.impl(self);
    }
};

fn percentageOf(total: u16, percentage: u8) u16 {
    const ftotal: f32 = @floatFromInt(total);
    const fpercentage: f32 = @floatFromInt(percentage);

    return @intFromFloat(ftotal * fpercentage / 100.0);
}

fn fractionOf(total: u16, numerator: u16, denominator: u16) u16 {
    const ftotal: f32 = @floatFromInt(total);
    const fnumerator: f32 = @floatFromInt(numerator);
    const fdenominator: f32 = @floatFromInt(denominator);

    return @intFromFloat(ftotal * fnumerator / fdenominator);
}

// zig fmt: off

test "render()" {
    const TestCase = struct {
        const Self = @This();

        measure:   bool = false,   // rely on the measure function to choose buffer dimensions
        direction: StackDirection,
        text:      []const u8,
        left:      StackConstraint,
        center:    StackConstraint,
        right:     StackConstraint,
        max:       u16 = std.math.maxInt(u16),
        expected:  []const []const u8,

        pub fn test_fn(self: Self, id: usize) type {
            return struct {
                test {
                    const gpa = std.testing.allocator;

                    const expected = try Buffer.initContent(gpa, self.expected, .{});
                    defer expected.deinit(gpa);

                    var left = try Text.styled(gpa, self.text, .{});
                    defer left.deinit();
                    left.alignment = .left;
                    left.wrap = true;

                    var center = try Text.styled(gpa, self.text, .{});
                    defer center.deinit();
                    center.alignment = .center;
                    center.wrap = true;

                    var right = try Text.styled(gpa, self.text, .{});
                    defer right.deinit();
                    right.alignment = .right;
                    right.wrap = true;

                    var stack = try Stack.init(self.direction, gpa, &.{
                        .item(left.widget(),   self.left),
                        .item(center.widget(), self.center),
                        .item(right.widget(),  self.right),
                    });
                    defer stack.deinit(gpa);

                    const dimensions: Dimensions =
                        if (self.measure)
                            try stack.measure(switch(self.direction) {
                                .horizontal => .{ .max_width  = expected.width(),  .max_height = self.max },
                                .vertical   => .{ .max_height = expected.height(), .max_width  = self.max },
                            })
                        else
                            Dimensions.init(expected.width(), expected.height());

                    var actual = try Buffer.initDimensions(gpa, dimensions);
                    defer actual.deinit(gpa);

                    try stack.render(&actual, Area.init(actual.width(), actual.height(), 0, 0));

                    std.testing.expect(
                        expected.equals(actual),
                    ) catch |err| {
                        std.debug.print("\t\n", .{});
                        std.debug.print("test case #{d} failed\n", .{id});
                        std.debug.print("expected:\n{f}\n\n", .{expected});
                        std.debug.print("found:\n{f}\n", .{actual});
                        return err;
                    };
                }
            };
        }
    };

    inline for ([_]TestCase{
        // Test Case #0
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fraction(1, 3),
            .center    = comptime .Fraction(1, 3),
            .right     = comptime .Fraction(1, 3),
            .expected  = &[_][]const u8{
                "Hello world. Here" ++ "Hello world. Here" ++ "Hello world. Here",
                " is some text for" ++ " is some text for" ++ " is some text for",
                " testing the stac" ++ " testing the stac" ++ " testing the stac",
                "k layout         " ++ "    k layout     " ++ "         k layout",
            },
        },

        // Test Case #1
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Fill(1),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello world. Here" ++ "Hello world. Here" ++ "Hello world. Here",
                " is some text for" ++ " is some text for" ++ " is some text for",
                " testing the stac" ++ " testing the stac" ++ " testing the stac",
                "k layout         " ++ "    k layout     " ++ "         k layout",
            },
        },

        // Test Case #2
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Fraction(1, 3),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello world. Here" ++ "Hello world. Here" ++ "Hello world. Here",
                " is some text for" ++ " is some text for" ++ " is some text for",
                " testing the stac" ++ " testing the stac" ++ " testing the stac",
                "k layout         " ++ "    k layout     " ++ "         k layout",
            },
        },

        // Test Case #3
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Fraction(1, 3),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello world. Here" ++ "Hello world. Here" ++ "Hello world. Here",
                " is some text for" ++ " is some text for" ++ " is some text for",
                " testing the stac" ++ " testing the stac" ++ " testing the stac",
                "k layout         " ++ "    k layout     " ++ "         k layout",
            },
        },

        // Test Case #4
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Fixed(10),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello world. Here" ++ "Hello worl" ++ "Hello world. Here",
                " is some text for" ++ "d. Here is" ++ " is some text for",
                " testing the stac" ++ " some text" ++ " testing the stac",
                "k layout         " ++ " for testi" ++ "         k layout",
                "                 " ++ "ng the sta" ++ "                 ",
                "                 " ++ "ck layout " ++ "                 ",
            },
        },

        // Test Case #5
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Percentage(25),
            .center    = comptime .Fill(1),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello wor" ++  "Hello world. " ++ "Hello world. H",
                "ld. Here " ++  "Here is some " ++ "ere is some te",
                "is some t" ++  "text for test" ++ "xt for testing",
                "ext for t" ++  "ing the stack" ++ " the stack lay",
                "esting th" ++  "    layout   " ++ "           out",
                "e stack l" ++  "             " ++ "              ",
                "ayout    " ++  "             " ++ "              ",
            },
        },

        // Test Case #6
        .{
            .direction = .horizontal,
            .text      = "Hello world",
            .left      = comptime .Fill(1),
            .center    = comptime .Auto(),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello " ++ "Hello world" ++ "Hello ",
                "world " ++ "           " ++ " world",
            },
        },

        // Test Case #7
        .{
            .direction = .horizontal,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Fill(2),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello " ++ "Hello world." ++ "Hello ",
                "world." ++ " Here is som" ++ "world.",
                " Here " ++ "e text for t" ++ " Here ",
                "is som" ++ "esting the s" ++ "is som",
                "e text" ++ "tack layout " ++ "e text",
                " for t" ++ "            " ++ " for t",
                "esting" ++ "            " ++ "esting",
                " the s" ++ "            " ++ " the s",
                "tack l" ++ "            " ++ "tack l",
                "ayout " ++ "            " ++ " ayout",
            },
        },

        // Test Case #8
        .{
            .direction = .vertical,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fraction(1, 3),
            .center    = comptime .Fraction(1, 3),
            .right     = comptime .Fraction(1, 3),
            .max       = 13,
            .expected  = &[_][]const u8{
                "Hello world. ",
                "Here is some ",
                "text for test",
                "Hello world. ",
                "Here is some ",
                "text for test",
                "Hello world. ",
                "Here is some ",
                "text for test",
            },
        },

        // Test Case #9
        .{
            .direction = .vertical,
            .text      = "Hello world. Here is some text for testing the stack layout",
            .left      = comptime .Fill(1),
            .center    = comptime .Auto(),
            .right     = comptime .Fill(1),
            .max       = 13,
            .expected  = &[_][]const u8{
                "Hello world. ",
                "Here is some ",
                "text for test",
                "Hello world. ",
                "Here is some ",
                "text for test",
                "ing the stack",
                "    layout   ",
                "Hello world. ",
                "Here is some ",
                "text for test",
            },
        },

        // Test Case #10
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fill(1),
            .center    = comptime .Fill(2),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello world." ++ "      Hello world.      " ++ "Hello world.",
            },
        },

        // Test Case #11
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Percentage(50),
            .center    = comptime .Auto(),
            .right     = comptime .Auto(),
            .expected  = &[_][]const u8{
                "Hello world.            " ++ "Hello world." ++ "Hello world.",
            },
        },

        // Test Case #12
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Auto(),
            .expected  = &[_][]const u8{
                "Hello world.            " ++ "Hello world." ++ "Hello world.",
            },
        },

        // Test Case #13
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Fixed(12),
            .expected  = &[_][]const u8{
                "Hello world.            " ++ "Hello world." ++ "Hello world.",
            },
        },

        // Test Case #14
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Fill(1),
            .right     = comptime .Fixed(12),
            .expected  = &[_][]const u8{
                "Hello world.            " ++ "Hello world." ++ "Hello world.",
            },
        },

        // Test Case #15
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Fill(1),
            .right     = comptime .Fill(2),
            .expected  = &[_][]const u8{
                "Hello world.                        " ++ "Hello world." ++ "            Hello world.",
            },
        },

        // Test Case #16
        .{
            .measure   = true,
            .direction = .horizontal,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Fill(2),
            .expected  = &[_][]const u8{
                "Hello world.            " ++ "Hello world." ++ "Hello world.",
            },
        },

        // Test Case #17
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fill(1),
            .center    = comptime .Fill(2),
            .right     = comptime .Fill(1),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "Hello wo",
                "  rld.  ",
                "        ",
                "        ",
                "Hello wo",
                "    rld.",
            },
        },

        // Test Case #18
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Percentage(50),
            .center    = comptime .Auto(),
            .right     = comptime .Auto(),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
            },
        },

        // Test Case #19
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Auto(),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
            },
        },

        // Test Case #20
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Fixed(2),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
            },
        },

        // Test Case #21
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Fill(1),
            .right     = comptime .Fixed(2),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
            },
        },

        // Test Case #22
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Fill(1),
            .right     = comptime .Fill(2),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
                "        ",
                "        ",

            },
        },

        // Test Case #23
        .{
            .measure   = true,
            .max       = 8,
            .direction = .vertical,
            .text      = "Hello world.",
            .left      = comptime .Fraction(1, 2),
            .center    = comptime .Auto(),
            .right     = comptime .Fill(2),
            .expected  = &[_][]const u8{
                "Hello wo",
                "rld.    ",
                "        ",
                "        ",
                "Hello wo",
                "  rld.  ",
                "Hello wo",
                "    rld.",
            },
        },
    }, 0..) |test_case, id| {
        _ = test_case.test_fn(id);
    }
}
