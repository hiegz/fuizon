// zig fmt: off

const std = @import("std");

const Shared = @import("shared.zig").Shared;
const Strong = @import("strong.zig").Strong;

/// Represents a weak reference to a shared object.
pub fn Weak(comptime T: type) type {
    return struct {
        /// The allocator used to allocate and free the shared object.
        gpa: std.mem.Allocator,

        /// Reference to the shared object.
        ///
        /// The object is allocated when the first strong reference is created,
        /// and deallocated when all strong and weak references are dropped.
        reference: *Shared(T),

        /// Drops the weak object reference.
        ///
        /// If this is the last reference, the shared object is freed.
        pub fn deinit(self: Weak(T)) void {
            self.reference.weak -= 1;

            if (self.reference.strong + self.reference.weak == 0)
                self.gpa.destroy(self.reference);
        }

        /// Upgrades the weak reference to a shared reference if the shared
        /// object data hasn't already been dropped. Otherwise, this function
        /// returns `null`.
        pub fn upgrade(weak: Weak(T)) ?Strong(T) {
            if (weak.reference.strong == 0)
                return null;

            var strong: Strong(T)    = undefined;

            strong.gpa               = weak.gpa;
            strong.reference         = weak.reference;
            strong.reference.strong += 1;

            return strong;
        }
    };
}
