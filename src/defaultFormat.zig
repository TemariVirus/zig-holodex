const std = @import("std");
const formatBuf = std.fmt.formatBuf;
const mem = std.mem;

fn StringFormatter(comptime Writer: type) type {
    return struct {
        writer: Writer,

        // This is solely used for padding in `std.fmt.formatBuf`. Leave it as is.
        pub fn writeBytesNTimes(self: @This(), fill: []const u8, padding: usize) !void {
            try self.writer.writeBytesNTimes(fill, padding);
        }

        // This is solely used for writing `buf` in `std.fmt.formatBuf`.
        // Add quotes, and escape characters.
        pub fn writeAll(self: @This(), buf: []const u8) !void {
            try self.writer.writeAll("\"");

            var start: usize = 0;
            var end: usize = 0;
            while (end < buf.len) {
                const c = buf[end];
                const len = try std.unicode.utf8ByteSequenceLength(c);
                if (try std.unicode.utf8ByteSequenceLength(c) != 1) {
                    end += len;
                    continue;
                }

                const escapes = "\t\n\r\"\\";
                const replaces = [escapes.len][]const u8{ "\\t", "\\n", "\\r", "\\\"", "\\\\" };
                if (mem.indexOfScalar(u8, escapes, c)) |i| {
                    try self.writer.writeAll(buf[start..end]);
                    try self.writer.writeAll(replaces[i]);
                    start = end + 1;
                }
                end += 1;
            }

            try self.writer.writeAll(buf[start..]);
            try self.writer.writeAll("\"");
        }
    };
}

// Adapted from `std.fmt.formatType`
fn format(
    value: anytype,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
    max_depth: usize,
    is_root: bool,
) @TypeOf(writer).Error!void {
    const T = @TypeOf(value);
    if (comptime mem.eql(u8, fmt, "*")) {
        return std.fmt.formatAddress(value, options, writer);
    }

    const is_raw = comptime mem.eql(u8, fmt, "raw");
    const raw_fmt = if (is_raw) "any" else fmt;
    if (std.meta.hasMethod(T, "format") and !is_root and !is_raw) {
        return try value.format(fmt, options, writer);
    }

    const string_writer = StringFormatter(@TypeOf(writer)){ .writer = writer };
    switch (@typeInfo(T)) {
        .ComptimeInt,
        .Int,
        .ComptimeFloat,
        .Float,
        => return std.fmt.formatType(value, raw_fmt, options, writer, max_depth),
        .Bool => return formatBuf(if (value) "true" else "false", options, writer),
        .Optional => {
            if (value) |payload| {
                return format(payload, fmt, options, writer, max_depth, false);
            } else {
                return formatBuf("null", options, writer);
            }
        },
        .Enum => |enumInfo| {
            if (enumInfo.is_exhaustive) {
                try writer.writeAll(".");
                try writer.writeAll(@tagName(value));
                return;
            }

            // Use @tagName only if value is one of known fields
            @setEvalBranchQuota(3 * enumInfo.fields.len);
            inline for (enumInfo.fields) |enumField| {
                if (@intFromEnum(value) == enumField.value) {
                    try writer.writeAll(".");
                    try writer.writeAll(@tagName(value));
                    return;
                }
            }

            try writer.writeAll("(");
            try format(@intFromEnum(value), fmt, options, writer, max_depth, false);
            try writer.writeAll(")");
        },
        .Union => |info| {
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
                        try format(
                            @field(value, u_field.name),
                            fmt,
                            options,
                            writer,
                            max_depth - 1,
                            false,
                        );
                    }
                }
                try writer.writeAll(" }");
            } else {
                try std.fmt.format(writer, "@{x}", .{@intFromPtr(&value)});
            }
        },
        .Struct => |info| {
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
                    try format(
                        @field(value, f.name),
                        fmt,
                        options,
                        writer,
                        max_depth - 1,
                        false,
                    );
                }
                return writer.writeAll(" }");
            }
            try writer.writeAll(@typeName(T));
            if (max_depth == 0) {
                return writer.writeAll("{ ... }");
            }
            try writer.writeAll("{");
            inline for (info.fields, 0..) |f, i| {
                if (i == 0) {
                    try writer.writeAll(" .");
                } else {
                    try writer.writeAll(", .");
                }
                try writer.writeAll(f.name);
                try writer.writeAll(" = ");
                try format(@field(value, f.name), fmt, options, writer, max_depth - 1, false);
            }
            try writer.writeAll(" }");
        },
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .Array, .Enum, .Union, .Struct => {
                    return format(value.*, fmt, options, writer, max_depth, false);
                },
                else => return std.fmt.format(
                    writer,
                    "{s}@{x}",
                    .{ @typeName(ptr_info.child), @intFromPtr(value) },
                ),
            },
            .Many, .C => {
                if (ptr_info.sentinel) |_| {
                    return format(mem.span(value), fmt, options, writer, max_depth, false);
                }
                if (ptr_info.child == u8 and !is_raw) {
                    return try formatBuf(mem.span(value), options, string_writer);
                }
                @compileError("Non-sentinel terminated pointer types must use '*' format string");
            },
            .Slice => {
                if (max_depth == 0) {
                    return writer.writeAll("{ ... }");
                }
                if (ptr_info.child == u8 and !is_raw) {
                    return formatBuf(value, options, string_writer);
                }
                try writer.writeAll("{ ");
                for (value, 0..) |elem, i| {
                    try format(elem, fmt, options, writer, max_depth - 1, false);
                    if (i != value.len - 1) {
                        try writer.writeAll(", ");
                    }
                }
                try writer.writeAll(" }");
            },
        },
        .Array => |info| {
            if (max_depth == 0) {
                return writer.writeAll("{ ... }");
            }
            if (info.child == u8 and !is_raw) {
                return formatBuf(&value, options, string_writer);
            }
            try writer.writeAll("{ ");
            for (value, 0..) |elem, i| {
                try format(elem, fmt, options, writer, max_depth - 1, false);
                if (i < value.len - 1) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeAll(" }");
        },
        .Fn => @compileError("unable to format function body type, use '*const " ++ @typeName(T) ++ "' for a function pointer type"),
        .EnumLiteral => {
            const buffer = [_]u8{'.'} ++ @tagName(value);
            return formatBuf(buffer, options, writer);
        },
        .Null => return formatBuf("null", options, writer),
        else => @compileError("unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

/// Create a default format function for a type. Passing in "raw" as the format
/// string will format the value without calling any custom format methods.
pub fn defaultFormat(
    comptime T: type,
) fn (T, comptime []const u8, std.fmt.FormatOptions, anytype) anyerror!void {
    return (struct {
        pub fn f(
            value: T,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            return format(value, fmt, options, writer, std.options.fmt_max_depth, true);
        }
    }).f;
}
