//! Universally Unique Identifier (UUID).

const std = @import("std");

/// Binary representation of the UUID, in big-endian order.
bytes: [16]u8,

pub const ParseError = error{InvalidUuid};

fn parseHexOctet(octet: [2]u8) ParseError!u8 {
    const high = switch (octet[0]) {
        '0'...'9' => |c| c - '0',
        'a'...'f' => |c| c - 'a' + 10,
        'A'...'F' => |c| c - 'A' + 10,
        else => return ParseError.InvalidUuid,
    };
    const low = switch (octet[1]) {
        '0'...'9' => |c| c - '0',
        'a'...'f' => |c| c - 'a' + 10,
        'A'...'F' => |c| c - 'A' + 10,
        else => return ParseError.InvalidUuid,
    };
    return (high << 4) | low;
}

/// Parse a UUID in the format `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
/// Does not check validity of reserved bits.
pub fn parse(string: []const u8) ParseError!@This() {
    if (string.len != 36 or
        string[8] != '-' or
        string[13] != '-' or
        string[18] != '-' or
        string[23] != '-')
    {
        return ParseError.InvalidUuid;
    }

    var bytes: [16]u8 = undefined;
    for (0..4) |i| {
        bytes[i] = try parseHexOctet(string[i * 2 ..][0..2].*);
    }
    for (4..6) |i| {
        bytes[i] = try parseHexOctet(string[i * 2 + 1 ..][0..2].*);
    }
    for (6..8) |i| {
        bytes[i] = try parseHexOctet(string[i * 2 + 2 ..][0..2].*);
    }
    for (8..10) |i| {
        bytes[i] = try parseHexOctet(string[i * 2 + 3 ..][0..2].*);
    }
    for (10..16) |i| {
        bytes[i] = try parseHexOctet(string[i * 2 + 4 ..][0..2].*);
    }
    return .{ .bytes = bytes };
}

pub fn format(
    value: @This(),
    comptime _: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var buf: [36]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const buf_writer = fbs.writer();

    for (value.bytes[0..4]) |byte| {
        buf_writer.print("{x}", .{byte}) catch unreachable;
    }
    buf_writer.writeByte('-') catch unreachable;
    for (value.bytes[4..6]) |byte| {
        buf_writer.print("{x}", .{byte}) catch unreachable;
    }
    buf_writer.writeByte('-') catch unreachable;
    for (value.bytes[6..8]) |byte| {
        buf_writer.print("{x}", .{byte}) catch unreachable;
    }
    buf_writer.writeByte('-') catch unreachable;
    for (value.bytes[8..10]) |byte| {
        buf_writer.print("{x}", .{byte}) catch unreachable;
    }
    buf_writer.writeByte('-') catch unreachable;
    for (value.bytes[10..16]) |byte| {
        buf_writer.print("{x}", .{byte}) catch unreachable;
    }

    try std.fmt.formatBuf(fbs.getWritten(), options, writer);
}
