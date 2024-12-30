const std = @import("std");
const meta = std.meta;
const testing = std.testing;
const Type = std.builtin.Type;

pub fn QueryFormatter(comptime T: type) type {
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

            var printed = false;
            inline for (comptime meta.fieldNames(T)) |key| {
                const value = @field(self.query, key);
                if (willPrint(value)) {
                    if (printed) {
                        try writer.writeAll("&");
                    }
                    printed = true;
                }

                switch (@typeInfo(@TypeOf(value))) {
                    .Pointer => |info| try handlePointer(info, key, value, writer),
                    .Optional => try handleOptional(key, value, writer),
                    .Enum => try writer.print("{s}={s}", .{ key, @tagName(value) }),
                    else => try writer.print("{s}={}", .{ key, value }),
                }
            }
        }

        fn willPrint(value: anytype) bool {
            return switch (@typeInfo(@TypeOf(value))) {
                .Optional => value != null,
                else => true,
            };
        }

        fn handlePointer(info: Type.Pointer, key: []const u8, value: anytype, writer: anytype) !void {
            if (info.child == u8) {
                // String
                try writer.print("{s}={s}", .{ key, value });
            } else {
                // Array of strings
                try writer.print("{s}=", .{key});
                for (value, 0..) |item, j| {
                    if (j != 0) {
                        try writer.writeAll(",");
                    }
                    try writer.print("{s}", .{item});
                }
            }
        }

        fn handleOptional(key: []const u8, value: anytype, writer: anytype) !void {
            if (value) |val| {
                switch (@typeInfo(@TypeOf(val))) {
                    .Pointer => |info| try handlePointer(info, key, val, writer),
                    .Enum => try writer.print("{s}={s}", .{ key, @tagName(val) }),
                    else => try writer.print("{s}={}", .{ key, val }),
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
        null: ?[]const u8,
        int: u32,
        str: []const u8,
        list: []const []const u8,
        @"enum": enum { @"69%", sleepingTogether },
    };

    try testing.expectFmt(
        "holodex.net/ya/goo?int=42&str=Man I Love Fauna&list=,,oui oui,PP&enum=69%",
        "holodex.net/ya/goo{}",
        .{formatQuery(&TestQuery{
            .null = null,
            .int = 42,
            .str = "Man I Love Fauna",
            .list = &.{ "", "", "oui oui", "PP" },
            .@"enum" = .@"69%",
        })},
    );

    try testing.expectFmt(
        "holodex.net/ya/goo?null=Hopes and dreams&int=0&str=hololive is an idol group like AKB48&list=&enum=sleepingTogether",
        "holodex.net/ya/goo{}",
        .{formatQuery(&TestQuery{
            .null = "Hopes and dreams",
            .int = 0,
            .str = "hololive is an idol group like AKB48",
            .list = &.{},
            .@"enum" = .sleepingTogether,
        })},
    );
}
