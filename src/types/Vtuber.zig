//! Information about a VTuber.

const std = @import("std");

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
pub const format = holodex.defaultFormat(@This());

// No need to include `type` field as it should always be `vtuber`
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    org: ?[]const u8 = null,
    suborg: ?[]const u8 = null,
    photo: []const u8,
    lang: ?[]const u8 = null,

    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        const group = if (self.suborg) |suborg|
            // Remove the 2 random letters preceding the group name.
            try holodex.deepCopy(allocator, suborg[2..])
        else
            null;

        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .org = try holodex.deepCopy(allocator, self.org),
            .group = group,
            .photo = try holodex.deepCopy(allocator, self.photo),
            .lang = try holodex.deepCopy(allocator, self.lang),
        };
    }
};
