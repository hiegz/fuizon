const std = @import("std");
const BorderType = @import("border_type.zig").BorderType;

// zig fmt: off

pub const BorderSet = struct {
    h:  u21, // horizontal line
    v:  u21, // vertical line
    tl: u21, // top left corner
    tr: u21, // top right corner
    bl: u21, // bottom left corner
    br: u21, // bottom right corner

    const map = [_]struct {
        BorderType,
        BorderSet,
    }{
        // Plain (i = 0)
        .{
            BorderType.plain,
            .{
                .h  = '─',
                .v  = '│',
                .tl = '┌',
                .bl = '└',
                .tr = '┐',
                .br = '┘',
            },
        },

        // Rounded (i = 1)
        .{
            BorderType.rounded,
            .{
                .h  = '─',
                .v  = '│',
                .tl = '╭',
                .bl = '╰',
                .tr = '╮',
                .br = '╯',
            },
        },

        // Double (i = 2)
        .{
            BorderType.double,
            .{
                .h  = '═',
                .v  = '║',
                .tl = '╔',
                .bl = '╚',
                .tr = '╗',
                .br = '╝',
            },
        },

        // Thick (i = 3)
        .{
            BorderType.thick,
            .{
                .h  = '━',
                .v  = '┃',
                .tl = '┏',
                .bl = '┗',
                .tr = '┓',
                .br = '┛',
            },
        }
    };

    pub fn fromBorderType(border_type: BorderType) *const BorderSet {
        const t = map[@intFromEnum(border_type)][0];
        const v = &map[@intFromEnum(border_type)][1];

        std.debug.assert(t == border_type);

        return v;
    }
};
