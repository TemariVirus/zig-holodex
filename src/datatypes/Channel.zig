//! Basic information about a channel.

const std = @import("std");
const json = std.json;

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
/// Channel statistics.
stats: Stats,
/// Whether the channel is currently active or not.
inactive: bool,
/// The channel's most popular topics. `null` if the channel is a subber.
top_topics: ?[]const datatypes.Topic = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

pub const Stats = struct {
    /// Number of videos the channel has uploaded.
    video_count: u32,
    /// Number of subscribers the channel has.
    subscriber_count: u64,
    /// Number of clips of the channel. `0` if the channel is a subber.
    clip_count: u32,
};

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!Self {
    const Json = struct {
        id: []const u8,
        name: []const u8,
        english_name: ?datatypes.EnglishName = null,
        type: datatypes.ChannelFull.Type,
        org: ?datatypes.Organization = null,
        group: ?datatypes.Group = null,
        photo: ?[]const u8 = null,
        twitter: ?[]const u8 = null,
        twitch: ?[]const u8 = null,
        video_count: u32,
        subscriber_count: u64,
        clip_count: ?u32 = null,
        inactive: bool,
        top_topics: ?[]const datatypes.Topic = null,
    };
    const parsed = try json.innerParse(Json, allocator, source, options);
    return .{
        .id = parsed.id,
        .name = parsed.name,
        .english_name = parsed.english_name,
        .type = parsed.type,
        .org = parsed.org,
        .group = parsed.group,
        .photo = parsed.photo,
        .twitter = parsed.twitter,
        .twitch = parsed.twitch,
        .stats = .{
            .video_count = parsed.video_count,
            .subscriber_count = parsed.subscriber_count,
            .clip_count = parsed.clip_count orelse 0,
        },
        .inactive = parsed.inactive,
        .top_topics = parsed.top_topics,
    };
}
