//! Full information about a channel.

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
/// Channel statistics.
stats: Stats,
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

/// Type of a channel.
pub const Type = enum {
    subber,
    vtuber,
    external,
    system,
};

/// Stats of a channel.
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

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!Self {
    const Json = struct {
        id: []const u8,
        name: []const u8,
        english_name: ?datatypes.EnglishName = null,
        type: Type,
        org: ?datatypes.Organization = null,
        group: ?datatypes.Group = null,
        photo: ?[]const u8 = null,
        banner: ?[]const u8 = null,
        twitter: ?[]const u8 = null,
        twitch: ?[]const u8 = null,
        video_count: u32,
        subscriber_count: u64,
        view_count: u64,
        clip_count: ?u32 = null,
        lang: ?datatypes.Language = null,
        published_at: ?datatypes.Timestamp = null,
        created_at: ?datatypes.Timestamp = null,
        updated_at: ?datatypes.Timestamp = null,
        inactive: bool,
        description: ?[]const u8 = null,
        top_topics: ?[]const datatypes.Topic = null,
        yt_handle: ?[]const []const u8 = null,
        yt_name_history: ?[]const []const u8 = null,
        crawled_at: ?datatypes.Timestamp = null,
        comments_crawled_at: ?datatypes.Timestamp = null,
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
        .banner = parsed.banner,
        .twitter = parsed.twitter,
        .twitch = parsed.twitch,
        .stats = .{
            .video_count = parsed.video_count,
            .subscriber_count = parsed.subscriber_count,
            .view_count = parsed.view_count,
            .clip_count = parsed.clip_count orelse 0,
        },
        .lang = parsed.lang,
        .published_at = parsed.published_at,
        .created_at = parsed.created_at,
        .updated_at = parsed.updated_at,
        .inactive = parsed.inactive,
        .description = parsed.description,
        .top_topics = parsed.top_topics,
        .yt_handle = parsed.yt_handle,
        .yt_name_history = parsed.yt_name_history,
        .crawled_at = parsed.crawled_at,
        .comments_crawled_at = parsed.comments_crawled_at,
    };
}
