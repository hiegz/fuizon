pub const StackConstraint = union(enum) {
    auto,
    fill: u16,
    percentage: u8,
    fraction: struct { numerator: u16, denominator: u16 },
    fixed: u16,

    pub fn Auto() StackConstraint {
        return .auto;
    }

    pub fn Fill(factor: u16) StackConstraint {
        return .{ .fill = factor };
    }

    pub fn Percentage(value: u8) StackConstraint {
        return .{ .percentage = value };
    }

    pub fn Fraction(numerator: u16, denominator: u16) StackConstraint {
        return .{ .fraction = .{ .numerator = numerator, .denominator = denominator } };
    }

    pub fn Fixed(value: u16) StackConstraint {
        return .{ .fixed = value };
    }
};
