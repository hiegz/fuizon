// zig fmt: off

const std = @import("std");

const Shared = @import("shared.zig").Shared;
const Weak = @import("weak.zig").Weak;

/// Represents a strong reference to a shared object.
pub fn Strong(comptime T: type) type {
    return struct {
        /// The allocator used to allocate and free the shared object.
        gpa: std.mem.Allocator,

        /// Reference to the shared object.
        ///
        /// The object is allocated when the first strong reference is created,
        /// and deallocated when all strong and weak references are dropped.
        ref: *Shared(T),

        /// Returns the shared object data.
        pub fn data(self: Strong(T)) *T {
            return &self.ref.data;
        }

        /// Creates a new strong reference to the shared object.
        pub fn clone(strong: Strong(T)) Strong(T) {
            strong.ref.strong += 1;
            return strong;
        }

        /// Creates a new weak reference to the shared object.
        pub fn downgrade(strong: Strong(T)) Weak(T) {
            var weak: Weak(T) = undefined;
            weak.gpa = strong.gpa;
            weak.ref = strong.ref;
            weak.ref.weak += 1;
            return weak;
        }

        /// Drops the strong object reference.
        ///
        /// If this is the last strong reference, the object data is dropped
        /// and returned to the caller. Otherwise, this function returns
        /// `null`.
        ///
        /// If this is the last reference, the shared object is freed.
        pub fn deinit(self: Strong(T)) ?T {
            var object_data: ?T = null;

            if (self.ref.strong == 1)
                object_data = self.ref.data;

            self.ref.strong -= 1;

            if (self.ref.strong + self.ref.weak == 0)
                self.gpa.destroy(self.ref);

            return object_data;
        }
    };
}
