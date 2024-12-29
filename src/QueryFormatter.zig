const std = @import("std");
const meta = std.meta;
const testing = std.testing;

fn QueryFormatter(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Struct => {},
        else => @compileError("Expected struct, found '" ++ @typeName(T) ++ "'"),
    }

    return struct {
        query: *const T,

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            if (meta.fieldNames(T).len > 0) {
                try writer.writeAll("?");
            }

            inline for (comptime meta.fieldNames(T), 0..) |key, i| {
                if (i != 0) {
                    try writer.writeAll("&");
                }

                const value = @field(self.query, key);
                switch (@typeInfo(@TypeOf(value))) {
                    .Pointer => |info| if (info.child == u8) {
                        try writer.print("{s}={s}", .{ key, value });
                    } else {
                        try writer.print("{s}=", .{key});
                        for (value, 0..) |item, j| {
                            if (j != 0) {
                                try writer.writeAll(",");
                            }
                            try writer.print("{s}", .{item});
                        }
                    },
                    else => try writer.print("{s}={}", .{ key, value }),
                }
            }
        }
    };
}

/// Create a new QueryFormatter for the given query struct.
/// `query` must be a pointer to a struct.
pub fn formatQuery(query: anytype) QueryFormatter(meta.Child(@TypeOf(query))) {
    return QueryFormatter(meta.Child(@TypeOf(query))){ .query = query };
}

test formatQuery {
    const TestQuery = struct {
        int: u32,
        str: []const u8,
        list: []const []const u8,
    };
    const query = TestQuery{
        .int = 42,
        .str = "Man I Love Fauna",
        .list = &.{ "", "", "oui oui", "PP" },
    };
    try testing.expectFmt(
        "holodex.net/ya/goo?int=42&str=Man I Love Fauna&list=,,oui oui,PP",
        "holodex.net/ya/goo{}",
        .{formatQuery(&query)},
    );
}
