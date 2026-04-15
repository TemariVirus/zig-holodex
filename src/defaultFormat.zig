const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Writer = std.Io.Writer;

const PrettyFormatter = struct {
    out: *Writer,
    writer: Writer = .{
        .buffer = &.{},
        .vtable = &.{
            .drain = &drain,
        },
    },
    indents: usize = 0,

    const INDENT_SIZE = 4;

    pub fn init(writer: *Writer) @This() {
        return .{ .out = writer };
    }

    pub fn indent(self: *@This()) void {
        self.indents += INDENT_SIZE;
    }

    pub fn unIndent(self: *@This()) void {
        assert(self.indents >= INDENT_SIZE);
        self.indents -= INDENT_SIZE;
    }

    pub fn nextField(self: @This()) Writer.Error!void {
        try self.out.writeByte('\n');
        try self.out.splatByteAll(' ', self.indents);
    }

    pub fn writeString(self: @This(), str: []const u8) Writer.Error!void {
        try std.json.Stringify.encodeJsonString(str, .{ .escape_unicode = false }, self.out);
    }

    /// Formats and writes the given bytes to `self.out`, returning the number
    /// of input bytes written.
    fn write(self: @This(), bytes: []const u8) Writer.Error!usize {
        var written: usize = 0;
        var start: usize = 0;
        var end: usize = 0;
        while (end < bytes.len) {
            const c = bytes[end];
            if (c == '\n') {
                const n = try self.out.write(bytes[start..end]);
                written += n;
                if (n < end - start) {
                    return written;
                }
                try self.nextField();
                start = end + 1;
                end += 1;
            } else {
                end += std.unicode.utf8ByteSequenceLength(c) catch 1;
            }
        }

        written += try self.out.write(bytes[start..]);
        return written;
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        const self: *const @This() = @fieldParentPtr("writer", w);

        // Fast path
        if (self.indents == 0) {
            return self.out.writeSplat(data, splat);
        }

        var written: usize = 0;
        for (data[0 .. data.len - 1]) |str| {
            const n = try self.write(str);
            written += n;
            if (n < str.len) {
                return written;
            }
        }
        for (0..splat) |_| {
            const str = data[data.len - 1];
            const n = try self.write(str);
            written += n;
            if (n < str.len) {
                return written;
            }
        }
        return written;
    }
};

fn prettify(
    value: anytype,
    pretty_formatter: *PrettyFormatter,
    comptime max_depth: usize,
) Writer.Error!void {
    if (std.meta.hasMethod(@TypeOf(value), "prettyFormat")) {
        try value.prettyFormat(pretty_formatter, max_depth);
    } else if (std.meta.hasMethod(@TypeOf(value), "format")) {
        try value.format(&pretty_formatter.writer);
    } else {
        try prettifyInner(value, pretty_formatter, max_depth);
    }
}

// Adapted from `std.fmt.formatType`
fn prettifyInner(
    value: anytype,
    pretty_formatter: *PrettyFormatter,
    comptime max_depth: usize,
) Writer.Error!void {
    const T = @TypeOf(value);
    const writer = &pretty_formatter.writer;

    switch (@typeInfo(T)) {
        .optional => {
            if (value) |payload| {
                return prettifyInner(payload, pretty_formatter, max_depth);
            } else {
                return writer.writeAll("null");
            }
        },
        .@"union" => |info| {
            try writer.writeAll(@typeName(T));
            if (max_depth == 0) {
                return writer.writeAll("{ ... }");
            }
            if (info.tag_type) |UnionTagType| {
                try writer.writeAll("{ .");
                try writer.writeAll(@tagName(@as(UnionTagType, value)));
                try writer.writeAll(" = ");
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        // Overwrite field formatting if it exists
                        if (@hasDecl(T, "Overwrites") and std.meta.hasMethod(T.Overwrites, u_field.name)) {
                            const formatFn = @field(T.Overwrites, u_field.name);
                            try formatFn(@field(value, u_field.name), writer);
                        } else {
                            try prettify(@field(value, u_field.name), pretty_formatter, max_depth - 1);
                        }
                    }
                }
                try writer.writeAll(" }");
            } else {
                try std.fmt.format(writer, "@{x}", .{@intFromPtr(&value)});
            }
        },
        .@"struct" => |info| {
            if (info.is_tuple) {
                // Skip the type and field names when formatting tuples.
                if (max_depth == 0) {
                    return writer.writeAll("{ ... }");
                }
                try writer.writeAll("{");
                inline for (info.fields, 0..) |f, i| {
                    if (i == 0) {
                        try writer.writeAll(" ");
                    } else {
                        try writer.writeAll(", ");
                    }
                    try prettify(
                        @field(value, f.name),
                        pretty_formatter,
                        max_depth - 1,
                    );
                }
                return writer.writeAll(" }");
            }

            try writer.writeAll(@typeName(T));
            if (max_depth == 0) {
                return writer.writeAll("{ ... }");
            }
            try writer.writeAll("{");
            pretty_formatter.indent();
            try pretty_formatter.nextField();
            inline for (info.fields, 0..) |f, i| {
                if (i != 0) {
                    try writer.writeByte(',');
                    try pretty_formatter.nextField();
                }
                try writer.writeByte('.');
                try writer.writeAll(f.name);
                try writer.writeAll(" = ");
                // Overwrite field formatting if it exists
                if (@hasDecl(T, "Overwrites") and std.meta.hasMethod(T.Overwrites, f.name)) {
                    const formatFn = @field(T.Overwrites, f.name);
                    try formatFn(@field(value, f.name), writer);
                } else {
                    try prettify(@field(value, f.name), pretty_formatter, max_depth - 1);
                }
            }
            pretty_formatter.unIndent();
            try pretty_formatter.nextField();
            try writer.writeByte('}');
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    return prettify(value.*, pretty_formatter, max_depth);
                },
                else => return writer.print(
                    "{s}@{x}",
                    .{ @typeName(ptr_info.child), @intFromPtr(value) },
                ),
            },
            .many, .c => {
                if (ptr_info.sentinel()) |_| {
                    return prettifyInner(mem.span(value), pretty_formatter, max_depth);
                }
                @compileError("Non-sentinel terminated pointer types must use '*' format string");
            },
            .slice => {
                if (ptr_info.child == u8) {
                    return pretty_formatter.writeString(value);
                }
                if (max_depth == 0) {
                    return writer.writeAll("{ ... }");
                }
                try writer.writeByte('{');
                pretty_formatter.indent();
                try pretty_formatter.nextField();
                for (value, 0..) |elem, i| {
                    try prettify(elem, pretty_formatter, max_depth - 1);
                    if (i != value.len - 1) {
                        try writer.writeByte(',');
                        try pretty_formatter.nextField();
                    }
                }
                pretty_formatter.unIndent();
                try pretty_formatter.nextField();
                try writer.writeByte('}');
            },
        },
        .array => return prettifyInner(&value, pretty_formatter, max_depth),
        else => {
            return if (std.meta.hasMethod(@TypeOf(value), "prettyFormat"))
                value.prettyFormat(pretty_formatter, max_depth - 1)
            else if (std.meta.hasMethod(@TypeOf(value), "format"))
                value.format(&pretty_formatter.writer)
            else
                writer.printValue("", .{}, value, max_depth);
        },
    }
}

/// Create a default format function for a type.
///
/// By adding an `Overwrites` struct decl that contains methods of the form:
/// ```zig
/// pub fn fieldName(
///     value: @TypeOf(T.fieldName),
///     writer: *std.Io.Writer,
/// ) std.Io.Writer.Error!void {
///     // custom formatting logic for `T.fieldName`
/// }
/// ```
/// When `fieldName` matches the name of a field in `T`, the custom formatting
/// function will be called instead of the default formatting function.
pub fn DefaultFormat(comptime T: type) type {
    return struct {
        pub fn format(value: T, writer: *Writer) Writer.Error!void {
            var pretty_formatter: PrettyFormatter = .init(writer);
            return prettifyInner(
                value,
                &pretty_formatter,
                std.options.fmt_max_depth,
            );
        }

        pub fn prettyFormat(
            value: T,
            pretty_formatter: *PrettyFormatter,
            comptime max_depth: usize,
        ) Writer.Error!void {
            return prettifyInner(
                value,
                pretty_formatter,
                max_depth,
            );
        }
    };
}

/// Pretty prints a value.
///
/// ```zig
/// std.debug.print("{f}\n", .{holodex.pretty(value)});
/// ```
pub fn pretty(value: anytype) std.fmt.Alt(
    @TypeOf(value),
    DefaultFormat(@TypeOf(value)).format,
) {
    return .{ .data = value };
}
