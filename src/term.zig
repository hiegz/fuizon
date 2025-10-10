const Variable = @import("variable.zig").Variable;

pub const Term = struct {
    coefficient: f32,
    variable: *Variable,

    pub fn init(coefficient: f32, variable: *Variable) Term {
        return .{ .coefficient = coefficient, .variable = variable };
    }
};
