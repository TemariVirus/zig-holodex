//! Information about a VTuber.

const std = @import("std");
const json = std.json;

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

id: []const u8,
name: []const u8,
english_name: ?[]const u8 = null,
org: ?[]const u8 = null,
group: ?[]const u8 = null,
photo: []const u8,
lang: ?[]const u8 = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!Self {
    // No need to include `type` field as it should always be `vtuber`
    const Json = struct {
        id: []const u8,
        name: []const u8,
        english_name: ?[]const u8 = null,
        org: ?[]const u8 = null,
        suborg: ?[]const u8 = null,
        photo: []const u8,
        lang: ?[]const u8 = null,
    };

    const parsed = try json.innerParse(Json, allocator, source, options);
    const group = if (parsed.suborg) |suborg|
        if (suborg.len <= 2)
            null
        else
            // Remove the 2 random letters preceding the group name.
            suborg[2..]
    else
        null;
    return .{
        .id = parsed.id,
        .name = parsed.name,
        .english_name = parsed.english_name,
        .org = parsed.org,
        .group = group,
        .photo = parsed.photo,
        .lang = parsed.lang,
    };
}
