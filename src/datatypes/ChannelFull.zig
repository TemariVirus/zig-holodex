//! Full information about a channel.

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
type: Type,
/// VTuber organization the channel is part of.
org: ?datatypes.Organization = null,
/// VTuber subgroup the channel is part of.
group: ?datatypes.Group = null,
/// URL to the channel's profile picture.
photo: ?[]const u8 = null,
/// URL to the channel's banner.
banner: ?[]const u8 = null,
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
/// Primary language of the channel.
lang: ?datatypes.Language = null,
/// When the channel was created.
published_at: ?datatypes.Timestamp = null,
/// When the channel was added to holodex.
created_at: ?datatypes.Timestamp = null,
/// When the channel was last updated in holodex.
updated_at: ?datatypes.Timestamp = null,
/// Whether the channel is currently active or not.
inactive: bool,
/// Description of the channel.
description: ?[]const u8 = null,
/// The channel's most popular topics.
top_topics: ?[]const datatypes.Topic = null,
/// The channel's YouTube handles. Includes the initial `@`.
yt_handle: ?[]const []const u8 = null,
/// A list of the channel's names in chronological order.
yt_name_history: ?[]const []const u8 = null,
/// When the channel was last crawled.
crawled_at: ?datatypes.Timestamp = null,
/// When the channel's comments were last crawled.
comments_crawled_at: ?datatypes.Timestamp = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// Type of a channel. Either a VTuber or a subber.
pub const Type = enum {
    subber,
    vtuber,
};
