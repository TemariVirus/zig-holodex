const std = @import("std");
const zeit = @import("zeit");

pub const Api = @import("Api.zig");
pub const datatypes = @import("datatypes.zig");

pub const defaultFormat = @import("defaultFormat.zig").defaultFormat;
pub const Pager = @import("Pager.zig").Pager;
pub const PercentEncoder = @import("url.zig").PercentEncoder;
pub const percentEncode = @import("url.zig").percentEncode;
pub const QueryFormatter = @import("QueryFormatter.zig").QueryFormatter;
pub const formatQuery = @import("QueryFormatter.zig").formatQuery;

/// Parse an optional timestamp in the ISO 8601 format.
pub fn parseOptionalTimestamp(timestamp: ?[]const u8) error{InvalidTimestamp}!?datatypes.Timestamp {
    return if (timestamp) |tp|
        try datatypes.Timestamp.parseISO(tp)
    else
        null;
}

/// This function leaks memory when returning an error. Use an arena allocator
/// to free memory properly.
pub fn deepCopy(allocator: std.mem.Allocator, src: anytype) std.mem.Allocator.Error!@TypeOf(src) {
    return switch (@typeInfo(@TypeOf(src))) {
        .Bool, .Int, .Float, .Array, .Enum, .Vector => src,
        .Optional => if (src) |x| try deepCopy(allocator, x) else null,
        .Pointer => |info| switch (info.size) {
            .One => {
                const ptr = try allocator.create(info.child);
                ptr.* = try deepCopy(allocator, src.*);
                return ptr;
            },
            .Slice => {
                const slice = try allocator.alloc(info.child, src.len);
                for (src, 0..) |x, i| {
                    slice[i] = try deepCopy(allocator, x);
                }
                return slice;
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

test {
    std.testing.refAllDecls(@This());
}
