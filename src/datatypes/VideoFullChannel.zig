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
/// Channel statistics.
stats: ?Stats,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

pub const Stats = struct {
    /// Number of videos the channel has uploaded.
    video_count: u32,
    /// Number of subscribers the channel has.
    subscriber_count: u64,
    /// Number of views the channel has.
    view_count: u64,
    /// Number of clips of the channel. `0` if the channel is a subber.
    clip_count: u32,
};

/// The JSON representation of a `VideoFullChannel`.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    type: datatypes.ChannelFull.Type,
    org: ?[]const u8 = null,
    suborg: ?[]const u8 = null,
    photo: []const u8,

    // Only returned when 'includes' contains 'channel_stats'
    video_count: ?u32 = null,
    subscriber_count: ?u64 = null,
    view_count: ?u64 = null,
    clip_count: ?u32 = null,

    /// Convert to a `VideoFullChannel`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        const group = if (self.suborg) |suborg|
            if (suborg.len <= 2)
                null
            else
                // Remove the 2 random letters preceding the group name.
                try holodex.deepCopy(allocator, suborg[2..])
        else
            null;

        // Use non-nullable `video_count` field to check if `stats` should be `null`
        const stats = if (self.video_count) |_| Stats{
            .video_count = self.video_count.?,
            .subscriber_count = self.subscriber_count orelse return datatypes.JsonConversionError.MissingField,
            .view_count = self.view_count orelse return datatypes.JsonConversionError.MissingField,
            .clip_count = self.clip_count orelse 0,
        } else null;

        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .type = self.type,
            .org = try holodex.deepCopy(allocator, self.org),
            .group = group,
            .photo = try holodex.deepCopy(allocator, self.photo),
            .stats = stats,
        };
    }
};
