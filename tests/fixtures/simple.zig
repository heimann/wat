const std = @import("std");

pub const VERSION = "1.0.0";

const Point = struct {
    x: i32,
    y: i32,
};

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn privateHelper() void {
    // Private function
}

pub const Status = enum {
    ok,
    error,
};

const Result = union(enum) {
    success: i32,
    failure: []const u8,
};

test "basic addition" {
    const result = add(2, 3);
    try std.testing.expectEqual(5, result);
}

const MyError = error{
    InvalidInput,
    OutOfBounds,
};