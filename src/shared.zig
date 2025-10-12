// zig fmt: off

const std = @import("std");

const Strong = @import("strong.zig").Strong;

/// Represents a shared object.
pub fn Shared(comptime T: type) type {
    return struct {
        /// how many active strong references to this object currently exist.
        ///
        /// When the number of strong references reaches zero, the object data
        /// is returned to the owner of the last strong reference.
        strong: usize,

        /// how many active weak references to this object currently exist.
        ///
        /// When the number of strong and weak references reaches zero, the
        /// shared object is destroyed.
        weak: usize,

        /// the data being shared.
        data: T,

        /// Creates a new shared object using the provided allocator and returns
        /// a strong reference to it. The underlying object data is undefined.
        pub fn init(gpa: std.mem.Allocator) error{OutOfMemory}!Strong(T) {
            const shared: *Shared(T) = try gpa.create(Shared(T));

            shared.strong = 1;
            shared.weak   = 0;
            shared.data   = undefined;

            return .{ .gpa = gpa, .reference = shared };
        }

        /// Creates a new shared object using the provided allocator,
        /// initializes it with `data`, and returns a strong reference to it.
        pub fn create(gpa: std.mem.Allocator, data: T) error{OutOfMemory}!Strong(T) {
            const ref = try Shared(T).init(gpa);
            ref.data().* = data;
            return ref;
        }
    };
}
