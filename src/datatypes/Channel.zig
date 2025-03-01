//! Basic information about a channel.

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
photo: ?[]const u8 = null,
/// The channel's Twitter handle. Does not include the initial `@`.
twitter: ?[]const u8 = null,
/// The channel's Twitch handle. Does not include the initial `@`.
twitch: ?[]const u8 = null,
/// Number of videos the channel has uploaded.
video_count: ?u32 = null,
/// Number of subscribers the channel has.
subscriber_count: ?u64 = null,
/// Number of views the channel has.
view_count: ?u64 = null,
/// Number of clips of the channel. `0` if the channel is a subber.
clip_count: ?u32 = null,
/// Whether the channel is currently active or not.
inactive: bool,
/// The channel's most popular topics.
top_topics: ?[]const datatypes.Topic = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `Channel`.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    type: datatypes.ChannelFull.Type,
    org: ?[]const u8 = null,
    group: ?[]const u8 = null,
    photo: ?[]const u8 = null,
    twitter: ?[]const u8 = null,
    twitch: ?[]const u8 = null,
    video_count: ?u32 = null,
    subscriber_count: ?u64 = null,
    view_count: ?u64 = null,
    clip_count: ?u32 = null,
    inactive: bool,
    top_topics: ?[]const []const u8 = null,

    /// Convert to a `Channel`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .type = self.type,
            .org = try holodex.deepCopy(allocator, self.org),
            .group = try holodex.deepCopy(allocator, self.group),
            .photo = try holodex.deepCopy(allocator, self.photo),
            .twitter = try holodex.deepCopy(allocator, self.twitter),
            .twitch = try holodex.deepCopy(allocator, self.twitch),
            .video_count = self.video_count,
            .subscriber_count = self.subscriber_count,
            .view_count = self.view_count,
            .clip_count = self.clip_count,
            .inactive = self.inactive,
            .top_topics = try holodex.deepCopy(allocator, self.top_topics),
        };
    }
};
