//! Custom http headers returned by the Holodex API.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

// Max number of requests that can be made in a period of time.
rate_limit: u32,
// Number of remaining requests before the rate limit is reached.
rate_limit_remaining: u32,
// When `rate_limit_remaining` will reset to `rate_limit`.
rate_limit_reset: datatypes.Timestamp,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

pub const ParseError = std.fmt.ParseIntError || error{
    DuplicateHeader,
    InvalidHeader,
    MissingHeader,
    Overflow,
};

/// Parse the relevant headers from the http response headers.
pub fn parse(bytes: []const u8) ParseError!Self {
    const field_map: std.StaticStringMapWithEql(
        std.meta.FieldEnum(Self),
        std.static_string_map.eqlAsciiIgnoreCase,
    ) = .initComptime(.{
        .{ "X-Ratelimit-Limit", .rate_limit },
        .{ "X-Ratelimit-Remaining", .rate_limit_remaining },
        .{ "X-Ratelimit-Reset", .rate_limit_reset },
    });

    var headers_it: std.http.HeaderIterator = .init(bytes);
    _ = headers_it.next() orelse return ParseError.InvalidHeader;

    var headers: Self = undefined;
    var fields_seen: [@typeInfo(Self).@"struct".fields.len]bool = @splat(false);
    while (headers_it.next()) |header| {
        const field = field_map.get(header.name) orelse continue;
        if (fields_seen[@intFromEnum(field)]) {
            return ParseError.DuplicateHeader;
        }

        fields_seen[@intFromEnum(field)] = true;
        switch (field) {
            .rate_limit => headers.rate_limit =
                try parseHeaderInt(u32, header.value),
            .rate_limit_remaining => headers.rate_limit_remaining =
                try parseHeaderInt(u32, header.value),
            .rate_limit_reset => headers.rate_limit_reset =
                datatypes.Timestamp.fromSeconds(
                    try parseHeaderInt(i64, header.value),
                ),
        }
    }

    if (!std.mem.allEqual(bool, &fields_seen, true)) {
        return ParseError.MissingHeader;
    }
    return headers;
}

fn parseHeaderInt(comptime T: type, buf: []const u8) ParseError!T {
    return std.fmt.parseInt(T, buf, 10) catch |err| return switch (err) {
        std.fmt.ParseIntError.InvalidCharacter => ParseError.InvalidHeader,
        std.fmt.ParseIntError.Overflow => ParseError.Overflow,
    };
}
