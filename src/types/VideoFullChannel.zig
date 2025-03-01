//! Channel information associated with a `VideoFull`.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube channel id.
id: []const u8,
/// YouTube channel name.
name: []const u8,
/// English name of the channel/channel owner.
english_name: ?datatypes.EnglishName = null,
/// Type of the channel. Ether a VTuber or a subber.
type: datatypes.ChannelFull.Type,
/// VTuber organization the channel is part of.
org: ?datatypes.Organization = null,
/// VTuber subgroup the channel is part of.
group: ?datatypes.Group = null,
/// URL to the channel's profile picture.
photo: []const u8,
/// Number of videos the channel has uploaded.
video_count: u32,
/// Number of subscribers the channel has.
subscriber_count: u64,
/// Number of views the channel has.
view_count: u64,
/// Number of clips of the channel. `0` if the channel is a subber.
clip_count: ?u32 = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `VideoFullChannel`.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    type: datatypes.ChannelFull.Type,
    org: ?[]const u8 = null,
    suborg: ?[]const u8 = null,
    photo: []const u8,
    video_count: u32,
    subscriber_count: u64,
    view_count: u64,
    clip_count: ?u32 = null,

    /// Convert to a `VideoFullChannel`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
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
            .type = self.type,
            .org = try holodex.deepCopy(allocator, self.org),
            .group = group,
            .photo = try holodex.deepCopy(allocator, self.photo),
            .video_count = self.video_count,
            .subscriber_count = self.subscriber_count,
            .view_count = self.view_count,
            .clip_count = self.clip_count,
        };
    }
};
