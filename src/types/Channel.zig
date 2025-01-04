const std = @import("std");
const fmt = std.fmt;
const zeit = @import("zeit");
const holodex = @import("../root.zig");
const types = holodex.types;

/// YouTube channel id.
id: []const u8,
/// YouTube channel name.
name: []const u8,
/// English name of the channel/channel owner.
english_name: ?types.EnglishName = null,
/// Type of the channel. Ether a VTuber or a subber.
type: Type,
/// VTuber organization the channel is part of.
org: ?types.Organization = null,
/// VTuber subgroup the channel is part of.
group: ?types.Group = null,
/// URL to the channel's profile picture.
photo: ?[]const u8 = null,
/// URL to the channel's banner.
banner: ?[]const u8 = null,
/// The channel's Twitter handle. Does not include the initial `@`.
twitter: ?[]const u8 = null,
/// The channel's Twitch handle. Does not include the initial `@`.
twitch: ?[]const u8 = null,
/// Number of videos the channel has uploaded.
video_count: ?u64 = null,
/// Number of subscribers the channel has.
subscriber_count: ?u64 = null,
/// Number of views the channel has.
viewer_count: ?u64 = null,
/// Number of clips of the channel. `0` if the channel is a subber.
clip_count: ?u64 = null,
/// Primary language of the channel.
lang: ?types.Language = null,
/// When the channel was created.
published_at: ?zeit.Instant = null,
/// When the channel was added to holodex.
created_at: ?zeit.Instant = null,
/// When the channel was last updated in holodex.
updated_at: ?zeit.Instant = null,
/// Whether the channel is currently active or not.
inactive: bool,
/// Description of the channel.
description: ?[]const u8 = null,
/// The channel's most popular topics.
top_topics: ?[]const types.Topic = null,
/// The channel's YouTube handles. Includes the initial `@`.
yt_handle: ?[]const []const u8 = null,
/// A list of the channel's names in chronological order.
yt_name_history: ?[]const []const u8 = null,
/// When the channel was last crawled.
crawled_at: ?zeit.Instant = null,
/// When the channel's comments were last crawled.
comments_crawled_at: ?zeit.Instant = null,

const Self = @This();

/// Type of a channel. Either a VTuber or a subber.
pub const Type = enum {
    subber,
    vtuber,
};

/// The JSON representation of a channel.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?[]const u8 = null,
    type: Type,
    org: ?[]const u8 = null,
    group: ?[]const u8 = null,
    photo: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    twitter: ?[]const u8 = null,
    twitch: ?[]const u8 = null,
    video_count: ?u64 = null,
    subscriber_count: ?u64 = null,
    viewer_count: ?u64 = null,
    clip_count: ?u64 = null,
    lang: ?[]const u8 = null,
    published_at: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    inactive: bool,
    description: ?[]const u8 = null,
    top_topics: ?[]const []const u8 = null,
    yt_handle: ?[]const []const u8 = null,
    yt_name_history: ?[]const []const u8 = null,
    crawled_at: ?[]const u8 = null,
    comments_crawled_at: ?[]const u8 = null,

    /// This function leaks memory when returning an error. Use an arena allocator
    /// to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) holodex.DeepCopyError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .type = self.type,
            .org = try holodex.deepCopy(allocator, self.org),
            .group = try holodex.deepCopy(allocator, self.group),
            .photo = try holodex.deepCopy(allocator, self.photo),
            .banner = try holodex.deepCopy(allocator, self.banner),
            .twitter = try holodex.deepCopy(allocator, self.twitter),
            .twitch = try holodex.deepCopy(allocator, self.twitch),
            .video_count = self.viewer_count,
            .subscriber_count = self.subscriber_count,
            .viewer_count = self.viewer_count,
            .clip_count = self.clip_count,
            .lang = try holodex.deepCopy(allocator, self.lang),
            .published_at = try holodex.parseTimestamp(self.published_at),
            .created_at = try holodex.parseTimestamp(self.created_at),
            .updated_at = try holodex.parseTimestamp(self.updated_at),
            .inactive = self.inactive,
            .description = try holodex.deepCopy(allocator, self.description),
            .top_topics = try holodex.deepCopy(allocator, self.top_topics),
            .yt_handle = try holodex.deepCopy(allocator, self.yt_handle),
            .yt_name_history = try holodex.deepCopy(allocator, self.yt_name_history),
            .crawled_at = try holodex.parseTimestamp(self.crawled_at),
            .comments_crawled_at = try holodex.parseTimestamp(self.comments_crawled_at),
        };
    }
};
