const std = @import("std");
const Uri = std.Uri;
const Writer = std.Io.Writer;

const PercentEncodedWriter = struct {
    out: *Writer,
    writer: Writer = .{
        .buffer = &.{},
        .vtable = &.{
            .drain = &drain,
        },
    },

    pub fn init(w: *Writer) PercentEncodedWriter {
        return .{ .out = w };
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        @branchHint(.likely); // There is no buffer
        std.debug.assert(w.end == 0);

        const self: *const @This() = @fieldParentPtr("writer", w);
        for (data[0 .. data.len - 1]) |str| {
            try std.Uri.Component.percentEncode(self.out, str, isUnreserved);
        }
        for (0..splat) |_| {
            try std.Uri.Component.percentEncode(self.out, data[data.len - 1], isUnreserved);
        }

        var written: usize = 0;
        for (data[0 .. data.len - 1]) |str| {
            written += str.len;
        }
        written += data[data.len - 1].len * splat;
        return written;
    }
};

/// Percent encode the formatted string representation of the value.
///
/// ```zig
/// percentEncode(w, "{s}", "hello world");
/// // Output: hello%20world
/// ```
pub fn percentEncode(
    w: *Writer,
    comptime fmt: []const u8,
    value: anytype,
) Writer.Error!void {
    var pew: PercentEncodedWriter = .init(w);
    try pew.writer.print(fmt, .{value});
    // No need to flush as pew has no buffer
}

fn isUnreserved(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
        else => false,
    };
}

fn isUserChar(c: u8) bool {
    return isUnreserved(c) or isSubLimit(c);
}

fn isSubLimit(c: u8) bool {
    return switch (c) {
        '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=' => true,
        else => false,
    };
}

fn isPathChar(c: u8) bool {
    return isUserChar(c) or c == '/' or c == ':' or c == '@';
}

pub fn percentEncodePath(path: Uri.Component) error{UnexpectedCharacter}!Uri.Component {
    switch (path) {
        .raw => |raw| {
            for (raw) |c| {
                if (!isPathChar(c)) {
                    return Uri.ParseError.UnexpectedCharacter;
                }
            }
            return .{ .percent_encoded = raw };
        },
        .percent_encoded => return path,
    }
}
