const std = @import("std");
const meta = std.meta;
const testing = std.testing;

const percentEncode = @import("url.zig").percentEncode;

/// Format a struct as a url query string.
/// See `formatQuery` for more details.
pub fn QueryFormatter(comptime T: type) type {
    switch (@typeInfo(T)) {
        .@"struct" => {},
        else => @compileError("Expected struct, found '" ++ @typeName(T) ++ "'"),
    }

    return struct {
        query: *const T,

        pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            var printed = false;
            inline for (comptime meta.fieldNames(T)) |key| {
                const value = @field(self.query, key);
                if (willPrint(value)) {
                    if (printed) {
                        try writer.writeAll("&");
                    }
                    printed = true;

                    try writer.print("{s}=", .{percentEncode(key)});
                    switch (@typeInfo(@TypeOf(value))) {
                        .pointer => |info| try handlePointer(info, value, writer),
                        .optional => try handleOptional(value, writer),
                        .@"enum" => try handleEnum(value, writer),
                        else => try writer.print("{}", .{percentEncode(value)}),
                    }
                }
            }
        }

        fn willPrint(value: anytype) bool {
            return switch (@typeInfo(@TypeOf(value))) {
                .optional => value != null,
                else => true,
            };
        }

        fn handleString(value: []const u8, writer: anytype) !void {
            try writer.print("{s}", .{percentEncode(value)});
        }

        fn handlePointer(info: std.builtin.Type.Pointer, value: anytype, writer: anytype) !void {
            if (info.child == u8) {
                try handleString(value, writer);
            } else {
                // Array of strings or enums
                for (value, 0..) |item, j| {
                    if (j != 0) {
                        try writer.writeAll(",");
                    }
                    switch (@typeInfo(@TypeOf(item))) {
                        .pointer => try handleString(item, writer),
                        .@"enum" => try handleEnum(item, writer),
                        else => @compileError("Expected string or enum, found '" ++ @typeName(@TypeOf(item)) ++ "'"),
                    }
                }
            }
        }

        fn handleOptional(value: anytype, writer: anytype) !void {
            if (value) |val| {
                switch (@typeInfo(@TypeOf(val))) {
                    .pointer => |info| try handlePointer(info, val, writer),
                    .@"enum" => try handleEnum(val, writer),
                    else => try writer.print("{}", .{percentEncode(val)}),
                }
            }
        }

        fn handleEnum(value: anytype, writer: anytype) !void {
            // Use value's format method if it exists
            if (std.meta.hasMethod(@TypeOf(value), "format")) {
                return writer.print("{}", .{percentEncode(value)});
            }
            try handleString(@tagName(value), writer);
        }
    };
}

/// Create a new `holodex.QueryFormatter` for the given query struct.
/// `query` must be a const pointer to a struct.
/// Field names and values will be percent-encoded.
/// `null` values are omitted.
///
/// ```zig
/// const Query = struct {
///     foo: []const u8,
///     bar: ?u32,
/// };
/// const query = Query{ .foo = "hello world", .bar = null };
/// std.debug.print("example.com{}", .{ formatQuery(&query) });
/// // Output: example.com?foo=hello%20world
/// ```
pub fn formatQuery(query: anytype) QueryFormatter(meta.Child(@TypeOf(query))) {
    return .{ .query = query };
}

test formatQuery {
    const TestQuery = struct {
        null: ?[]const u8,
        int: u32,
        str: []const u8,
        list: []const []const u8,
        @"enum": enum { @"69%", sleepingTogether },
        @"日本語🙃": ?[]const u8,
        list_of_enums: ?[]const enum { a, b, c } = null,
    };

    try testing.expectFmt(
        "holodex.net/ya/goo?int=42&str=Man%20I%20Love%20Fauna&list=,,oui%20oui,PP,%E3%81%A1%E3%82%93%E3%81%A1%E3%82%93&enum=69%25&list_of_enums=a,b",
        "holodex.net/ya/goo?{}",
        .{formatQuery(&TestQuery{
            .null = null,
            .int = 42,
            .str = "Man I Love Fauna",
            .list = &.{ "", "", "oui oui", "PP", "ちんちん" },
            .@"enum" = .@"69%",
            .@"日本語🙃" = null,
            .list_of_enums = &.{ .a, .b },
        })},
    );

    try testing.expectFmt(
        "holodex.net/ya/goo?null=Hopes%20and%20dreams&int=0&str=hololive%20is%20an%20idol%20group%20like%20AKB48&list=&enum=sleepingTogether&%E6%97%A5%E6%9C%AC%E8%AA%9E%F0%9F%99%83=%E9%87%8F%E5%AD%90%E3%83%81%E3%82%AD%E3%83%B3%E3%82%B9%E3%83%BC%E3%83%97%E3%82%B0%E3%83%A9%E3%82%B9%E3%83%93%E3%83%83%E3%82%B0%E3%83%81%E3%83%A5%E3%83%B3%E3%82%B0%E3%82%B9%E3%80%80%F0%9F%8F%83%F0%9F%92%A8%F0%9F%90%89",
        "holodex.net/ya/goo?{}",
        .{formatQuery(&TestQuery{
            .null = "Hopes and dreams",
            .int = 0,
            .str = "hololive is an idol group like AKB48",
            .list = &.{},
            .@"enum" = .sleepingTogether,
            .@"日本語🙃" = "量子チキンスープグラスビッグチュングス　🏃💨🐉",
        })},
    );
}
