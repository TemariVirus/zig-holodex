const std = @import("std");

pub const formatQuery = @import("QueryFormatter.zig").formatQuery;

test {
    std.testing.refAllDecls(@This());
}
