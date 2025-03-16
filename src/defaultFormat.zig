const std = @import("std");
const assert = std.debug.assert;
const formatBuf = std.fmt.formatBuf;
const mem = std.mem;

fn PrettyFormatter(comptime Writer: type) type {
    return struct {
        writer: Writer,
        indents: usize = 0,
        pretty_mode: bool,

        const INDENT_SIZE = 4;

        pub fn indent(self: *@This()) void {
            self.indents += INDENT_SIZE;
        }

        pub fn unIndent(self: *@This()) void {
            assert(self.indents >= INDENT_SIZE);
            self.indents -= INDENT_SIZE;
        }

        pub fn nextField(self: @This()) Writer.Error!void {
            if (self.pretty_mode) {
                try self.writer.writeByte('\n');
                try self.writer.writeByteNTimes(' ', self.indents);
            } else {
                try self.writer.writeByte(' ');
            }
        }

        fn writeFn(ctx: *const anyopaque, bytes: []const u8) Writer.Error!usize {
            const self: *const @This() = @ptrCast(@alignCast(ctx));
            // Fast path
            if (!self.pretty_mode or self.indents == 0) {
                return self.writer.write(bytes);
            }

            var start: usize = 0;
            var end: usize = 0;
            while (end < bytes.len) {
                const c = bytes[end];
                const len = try std.unicode.utf8ByteSequenceLength(c);
                if (try std.unicode.utf8ByteSequenceLength(c) != 1) {
                    end += len;
                    continue;
                }

                if (c == '\n') {
                    try self.writer.writeAll(bytes[start..end]);
                    try self.nextField();
                    start = end + 1;
                }
                end += 1;
            }

            try self.writer.writeAll(bytes[start..]);
            return bytes.len;
        }

        pub fn anyWriter(self: *const @This()) std.io.AnyWriter {
            return std.io.AnyWriter{ .context = @ptrCast(self), .writeFn = &writeFn };
        }
    };
}

fn StringWriter(comptime Writer: type) type {
    return struct {
        writer: Writer,

        // This is solely used for padding in `std.fmt.formatBuf`.
        pub fn writeBytesNTimes(self: @This(), fill: []const u8, padding: usize) !void {
            try self.writer.writeBytesNTimes(fill, padding);
        }

        // This is solely used for writing `buf` in `std.fmt.formatBuf`.
        pub fn writeAll(self: @This(), buf: []const u8) !void {
            try std.json.encodeJsonString(buf, .{ .escape_unicode = false }, self.writer);
        }
    };
}

// Adapted from `std.fmt.formatType`
fn format(
    value: anytype,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    pretty_formatter: anytype,
    comptime Overwrites: type,
    max_depth: usize,
    is_root: bool,
) @TypeOf(pretty_formatter.writer).Error!void {
    const T = @TypeOf(value);
    const writer = pretty_formatter.writer;
    if (comptime mem.eql(u8, fmt, "*")) {
        return std.fmt.formatAddress(value, options, writer);
    }

    const is_raw = comptime mem.eql(u8, fmt, "raw");
    const is_pretty = comptime mem.eql(u8, fmt, "pretty");
    if (std.meta.hasMethod(T, "format") and !is_root and !is_raw) {
        return value.format(fmt, options, pretty_formatter.anyWriter());
    }

    const string_writer = StringWriter(@TypeOf(writer)){ .writer = writer };
    const simple_type_fmt = switch (@typeInfo(T)) {
        .comptime_int,
        .int,
        .comptime_float,
        .float,
        => if (is_raw or is_pretty) "" else fmt,
        .bool => "",
        .@"enum" => |info| if (info.is_exhaustive or is_raw or is_pretty) "" else fmt,
        else => fmt,
    };
    switch (@typeInfo(T)) {
        .optional => {
            if (value) |payload| {
                return format(payload, fmt, options, pretty_formatter, Overwrites, max_depth, false);
            } else {
                return formatBuf("null", options, writer);
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
                        try format(
                            @field(value, u_field.name),
                            fmt,
                            options,
                            pretty_formatter,
                            struct {},
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
                    try format(
                        @field(value, f.name),
                        fmt,
                        options,
                        pretty_formatter,
                        struct {},
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
                if (std.meta.hasMethod(Overwrites, f.name)) {
                    const formatFn = @field(Overwrites, f.name);
                    try formatFn(@field(value, f.name), fmt, options, pretty_formatter.anyWriter());
                } else {
                    try format(@field(value, f.name), fmt, options, pretty_formatter, struct {}, max_depth - 1, false);
                }
            }
            pretty_formatter.unIndent();
            try pretty_formatter.nextField();
            try writer.writeByte('}');
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    return format(value.*, fmt, options, pretty_formatter, Overwrites, max_depth, false);
                },
                else => return std.fmt.format(
                    writer,
                    "{s}@{x}",
                    .{ @typeName(ptr_info.child), @intFromPtr(value) },
                ),
            },
            .many, .c => {
                if (ptr_info.sentinel()) |_| {
                    return format(mem.span(value), fmt, options, pretty_formatter, Overwrites, max_depth, false);
                }
                if (ptr_info.child == u8 and !is_raw) {
                    return formatBuf(mem.span(value), options, string_writer);
                }
                @compileError("Non-sentinel terminated pointer types must use '*' format string");
            },
            .slice => {
                if (max_depth == 0) {
                    return writer.writeAll("{ ... }");
                }
                if (ptr_info.child == u8 and !is_raw) {
                    return formatBuf(value, options, string_writer);
                }
                try writer.writeByte('{');
                pretty_formatter.indent();
                try pretty_formatter.nextField();
                for (value, 0..) |elem, i| {
                    try format(elem, fmt, options, pretty_formatter, Overwrites, max_depth - 1, false);
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
        .array => |_| return format(&value, fmt, options, pretty_formatter, Overwrites, max_depth, false),
        else => return std.fmt.formatType(value, simple_type_fmt, options, writer, max_depth),
    }
}

/// Create a default format function for a type. Passing in "raw" as the format
/// string will format the value without calling any custom format methods.
///
/// The `Overwrites` type is a struct that contains methods of the form:
/// ```zig
/// pub fn fieldName(
///     value: @TypeOf(T.fieldName),
///     comptime fmt: []const u8,
///     options: std.fmt.FormatOptions,
///     writer: anytype,
/// ) @TypeOf(writer).Error!void {
///     // custom formatting logic for `T.fieldName`
/// }
/// ```
/// When `fieldName` matches the name of a field in `T`, the custom formatting
/// function will be called instead of the default formatting function. This
/// behaviour carries through optionals, pointers, slices, and arrays, but not
/// through unions or structs.
pub fn defaultFormat(
    comptime T: type,
    comptime Overwrites: type,
) fn (T, comptime []const u8, std.fmt.FormatOptions, anytype) anyerror!void {
    return (struct {
        pub fn f(
            value: T,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) @TypeOf(writer).Error!void {
            const is_pretty = comptime mem.eql(u8, fmt, "pretty");
            var pretty_formatter = PrettyFormatter(@TypeOf(writer)){
                .writer = writer,
                .pretty_mode = is_pretty,
            };
            return format(
                value,
                fmt,
                options,
                &pretty_formatter,
                Overwrites,
                std.options.fmt_max_depth,
                true,
            );
        }
    }).f;
}
