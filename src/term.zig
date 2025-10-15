const Variable = @import("variable.zig").Variable;

pub const Term = struct {
    coefficient: f64,
    variable: *Variable,

    pub fn init(coefficient: f64, variable: *Variable) Term {
        return .{ .coefficient = coefficient, .variable = variable };
    }
};
