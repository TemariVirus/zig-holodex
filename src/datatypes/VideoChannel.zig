//! Channel information associated with a `Video`. The channel is assumed to
//! always be a VTuber channel, so no `type` field exists.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube channel id.
id: []const u8,
/// YouTube channel name.
name: []const u8,
/// English name of the channel/channel owner.
english_name: ?datatypes.EnglishName = null,
/// VTuber organization the channel is part of.
org: ?datatypes.Organization = null,
/// URL to the channel's profile picture.
photo: []const u8,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `VideoChannel`.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    org: ?[]const u8 = null,
    photo: []const u8,

    /// Convert to a `VideoChannel`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .org = try holodex.deepCopy(allocator, self.org),
            .photo = try holodex.deepCopy(allocator, self.photo),
        };
    }
};
