pub const Constraint = union(enum) {
    auto,
    fill: u16,
    percentage: u8,
    fraction: struct { numerator: u16, denominator: u16 },
    fixed: u16,

    pub fn Auto() Constraint {
        return .auto;
    }

    pub fn Fill(factor: u16) Constraint {
        return .{ .fill = factor };
    }

    pub fn Percentage(value: u8) Constraint {
        return .{ .percentage = value };
    }

    pub fn Fraction(numerator: u16, denominator: u16) Constraint {
        return .{ .fraction = .{ .numerator = numerator, .denominator = denominator } };
    }

    pub fn Fixed(value: u16) Constraint {
        return .{ .fixed = value };
    }
};
