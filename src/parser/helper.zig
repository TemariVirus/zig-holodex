const std = @import("std");
const json = std.json;

pub const JsonField = struct {
    /// The name of the field in the JSON object.
    name: []const u8,
    /// The type of the field.
    type: type = void,
    /// The target field in the struct.
    target: union(enum) {
        name: []const u8,
        custom: fn (
            context: anytype,
            field_name: []const u8,
            allocator: std.mem.Allocator,
            source: anytype,
            options: json.ParseOptions,
        ) anyerror!void,
    },
    /// The default value for the field. If target is `custom`, a non-null value
    /// indicates that this json field is not required.
    default: ?*const anyopaque = null,

    pub fn defaultValue(self: JsonField) ?self.type {
        const dp: *const self.type = @ptrCast(@alignCast(self.default orelse return null));
        return dp.*;
    }
};

pub fn maxKeyLen(comptime field_names: []const []const u8) usize {
    comptime {
        var max: usize = 0;
        for (field_names) |name| {
            max = @max(max, name.len);
        }
        return max;
    }
}

pub fn JsonKey(comptime field_names: []const []const u8) type {
    @setEvalBranchQuota(field_names.len * 3);
    return std.BoundedArray(u8, maxKeyLen(field_names));
}

/// Get the next key in the JSON object. The returned key may not be in the
/// `field_names` list.
pub fn nextObjectKey(
    comptime field_names: []const []const u8,
    source: anytype,
    ignore_unknown_fields: bool,
) json.ParseError(@TypeOf(source.*))!?JsonKey(field_names) {
    var key = JsonKey(field_names).init(0) catch unreachable;
    while (true) {
        const token = try source.next();
        switch (token) {
            // No keys left
            .object_end => return null,
            // Accumulate partial values
            .partial_number, .partial_string => |slice| {
                if (key.appendSlice(slice)) {
                    continue;
                } else |_| {
                    try source.skipValue(); // Skip remaining key
                }
            },
            .string => |slice| {
                if (key.appendSlice(slice)) {
                    return key;
                } else |_| {}
            },
            // Escape sequences are not in any of our keys, ignore them
            .partial_string_escaped_1,
            .partial_string_escaped_2,
            .partial_string_escaped_3,
            .partial_string_escaped_4,
            => {
                try source.skipValue(); // Skip remaining key
            },
            // We expect a string key
            .number,
            .object_begin,
            .array_begin,
            .array_end,
            .true,
            .false,
            .null,
            .end_of_document,
            => return error.UnexpectedToken,
            // Never returned by next()
            .allocated_number, .allocated_string => unreachable,
        }

        // We didn't recognize this key, go to the next one
        if (!ignore_unknown_fields) {
            return error.UnknownField;
        }
        key.len = 0;
        try source.skipValue();
        continue;
    }
}

/// Parse a JSON object as a struct `T`, with renaming and default values.
/// `unknown_handler` is called when an unknown field is encountered. If it
/// returns `false` and `options.ignore_unknown_fields` is `false`, an error
/// is returned.
pub fn parseAs(
    comptime T: type,
    comptime fields: []const JsonField,
    /// The context passed to custom field parsers
    context: anytype,
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!T {
    const field_names = comptime blk: {
        var names: [fields.len][]const u8 = undefined;
        for (fields, 0..) |field, i| {
            names[i] = field.name;
        }
        break :blk names;
    };

    if (try source.next() != .object_begin) {
        return error.UnexpectedToken;
    }

    var obj: T = undefined;
    var fields_seen: [fields.len]bool = @splat(false);

    while (try nextObjectKey(&field_names, source, options.ignore_unknown_fields)) |field_name| {
        inline for (fields, 0..) |field, i| {
            if (std.mem.eql(u8, field_name.slice(), field.name)) {
                if (fields_seen[i]) {
                    switch (options.duplicate_field_behavior) {
                        .use_first => switch (field.target) {
                            .name => {
                                // Parse the value to get type checking
                                _ = try json.innerParse(field.type, allocator, source, options);
                                break;
                            },
                            .custom => break,
                        },
                        .@"error" => return error.DuplicateField,
                        .use_last => {},
                    }
                }
                switch (field.target) {
                    .name => |name| @field(obj, name) = try json.innerParse(
                        field.type,
                        allocator,
                        source,
                        options,
                    ),
                    .custom => |func| func(
                        context,
                        field_name.slice(),
                        allocator,
                        source,
                        options,
                    ) catch |err| return @errorCast(err),
                }
                fields_seen[i] = true;
                break;
            }
        } else {
            // Didn't match anything
            if (options.ignore_unknown_fields) {
                try source.skipValue();
            } else {
                return error.UnknownField;
            }
        }
    }

    inline for (fields, 0..) |field, i| {
        if (!fields_seen[i]) {
            if (field.defaultValue()) |default| {
                switch (field.target) {
                    .name => |name| @field(obj, name) = default,
                    .custom => {},
                }
            } else {
                return error.MissingField;
            }
        }
    }
    return obj;
}
