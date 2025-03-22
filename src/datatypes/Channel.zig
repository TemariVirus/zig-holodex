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
