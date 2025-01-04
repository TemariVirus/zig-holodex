const std = @import("std");

fn isUriUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

fn PercentEncodedWriterImpl(comptime Writer: type) type {
    return struct {
        pub fn write(context: Writer, bytes: []const u8) Writer.Error!usize {
            try std.Uri.Component.percentEncode(context, bytes, isUriUnreserved);
            return bytes.len;
        }
    };
}

fn percentEncodedWriter(writer: anytype) std.io.GenericWriter(
    @TypeOf(writer),
    @TypeOf(writer).Error,
    PercentEncodedWriterImpl(@TypeOf(writer)).write,
) {
    return .{ .context = writer };
}

/// Percent encode the formatted value. See `holodex.percentEncode` for more details.
pub fn PercentEncoder(comptime T: type) type {
    return struct {
        data: T,

        pub fn format(
            self: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const percent_encoder = percentEncodedWriter(writer);
            try std.fmt.formatType(self.data, fmt, options, percent_encoder, 1);
        }
    };
}

/// Percent encode the formatted string representation of the value.
/// This is a thin wrapper around `std.fmt.formatType`.
///
/// ```zig
/// std.debug.print("{s}", .{ percentEncode("hello world") });
/// // Output: hello%20world
/// ```
pub fn percentEncode(value: anytype) PercentEncoder(@TypeOf(value)) {
    return .{ .data = value };
}
