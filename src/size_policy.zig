pub const SizePolicy = union(enum) {
    auto,
    fill: u16,
    percentage: u16,
    fraction: struct { numerator: u16, denominator: u16 },
    fixed: u16,

    pub fn Auto() SizePolicy {
        return .auto;
    }

    pub fn Fill(factor: u16) SizePolicy {
        return .{ .fill = factor };
    }

    pub fn Percentage(value: u16) SizePolicy {
        return .{ .percentage = value };
    }

    pub fn Fraction(numerator: u16, denominator: u16) SizePolicy {
        return .{ .fraction = .{ .numerator = numerator, .denominator = denominator } };
    }

    pub fn Fixed(value: u16) SizePolicy {
        return .{ .fixed = value };
    }
};
