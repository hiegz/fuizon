/// Defines the numerical tolerance used when comparing 64-bit floating-point
/// values.
///
/// Floating-point arithmetic is inherently imprecise due to rounding errors
/// that occur during computation. Direct equality comparisons (`a === b`)
/// between two 64-bit floats can therefore yield false negatives even when the
/// numbers are logically equivalent.
///
/// This constant specifies the acceptable difference between two float values
/// for them to be considered equal within reasonable precision.
pub const TOLERANCE = 1.0e-8;

/// Returns true if two 64-bit floats are equal within `TOLERANCE`
pub fn nearEq(lhs: f64, rhs: f64) bool {
    return @abs(lhs - rhs) <= TOLERANCE;
}

/// Returns true if a 64-bit float is effectively zero.
pub fn nearZero(num: f64) bool {
    return nearEq(num, 0.0);
}
