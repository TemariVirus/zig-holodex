//! Full information about a video.

const std = @import("std");
const json = std.json;

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;
const VideoMin = datatypes.VideoMin;

/// YouTube video id.
id: []const u8,
/// YouTube video title.
title: []const u8,
/// Type of the video.
type: Type,
/// Topic of the video (from Holodex).
topic: ?datatypes.Topic = null,
/// When the video was published.
published_at: ?datatypes.Timestamp = null,
/// When the video went live or became viewable.
available_at: datatypes.Timestamp,
/// Duration of the video. `0` if the video is a stream that has not ended.
duration: datatypes.Duration,
/// Status of the video.
status: Status,
/// Language of the video. The translated language if the video is a subbed clip.
lang: ?datatypes.Language = null,
/// Counts of live translations in different languages.
/// Key is the language code, value is the count.
live_tl_count: ?std.StringArrayHashMapUnmanaged(u32) = null,
/// Description of the video.
description: ?[]const u8 = null,
/// Songs performed in this video.
songs: ?[]const datatypes.Song = null,
/// Information about the livestream. `null` if the video is not a stream.
live_info: ?LiveInfo = null,
/// Channel associated with the video.
channel: Channel,
/// Clips of the video.
clips: ?[]const VideoMin = null,
/// Sources of the clip. `null` if the video is not a clip.
sources: ?[]const VideoMin = null,
/// Videos linked in the description.
refers: ?[]const VideoMin = null,
/// TODO: What are simulcasts?
simulcasts: ?[]const VideoMin = null,
/// VTubers featured in this video.
mentions: ?[]const datatypes.Vtuber = null,
/// Comments with timestamps on the video.
timestamp_comments: ?[]const TimestampComment = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {
    pub fn live_tl_count(
        value: ?std.StringArrayHashMapUnmanaged(u32),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (value) |map| {
            try writer.writeAll("{");
            var i: usize = 0;
            var iter = map.iterator();
            while (iter.next()) |entry| {
                if (i == 0) {
                    try writer.writeAll(" ");
                } else {
                    try writer.writeAll(", ");
                }
                try writer.print("\"{s}\": {d}", .{ entry.key_ptr.*, entry.value_ptr.* });
                i += 1;
            }
            try writer.writeAll(" }");
        } else {
            try writer.writeAll("null");
        }
    }
});

/// Type of a video.
pub const Type = enum {
    /// Stream or video uploaded by a VTuber.
    stream,
    /// Clip made by a clipper.
    clip,
    /// Placeholder with no corresponding video on YouTube.
    placeholder,
};

/// Status of a video.
pub const Status = enum {
    live,
    missing,
    new,
    past,
    upcoming,
};

/// Information about a livestream.
pub const LiveInfo = struct {
    /// When the stream is scheduled to start.
    start_scheduled: ?datatypes.Timestamp = null,
    /// When the stream actually started.
    start_actual: ?datatypes.Timestamp = null,
    /// When the stream actually ended.
    end_actual: ?datatypes.Timestamp = null,
    /// The current number of viewers watching the stream. `0` if the stream is not live.
    live_viewers: u64,
};

/// Channel information associated with a `VideoFull`.
pub const Channel = struct {
    /// YouTube channel id.
    id: []const u8,
    /// YouTube channel name.
    name: []const u8,
    /// English name of the channel/channel owner.
    english_name: ?datatypes.EnglishName = null,
    /// Type of the channel.
    type: datatypes.ChannelFull.Type,
    /// VTuber organization the channel is part of.
    org: ?datatypes.Organization = null,
    /// VTuber subgroup the channel is part of.
    group: ?datatypes.Group = null,
    /// URL to the channel's profile picture.
    photo: []const u8,
    /// Channel statistics.
    stats: ?Stats,

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

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Channel {
        const Json = struct {
            id: []const u8,
            name: []const u8,
            english_name: ?datatypes.EnglishName = null,
            type: datatypes.ChannelFull.Type,
            org: ?datatypes.Organization = null,
            suborg: ?datatypes.Group = null,
            photo: []const u8,
            video_count: ?u32 = null,
            subscriber_count: ?u64 = null,
            view_count: ?u64 = null,
            clip_count: ?u32 = null,
        };

        const parsed = try json.innerParse(Json, allocator, source, options);
        const group = if (parsed.suborg) |suborg|
            if (suborg.len <= 2)
                null
            else
                // Remove the 2 random letters preceding the group name
                suborg[2..]
        else
            null;

        // Use non-nullable `video_count` field to check if `stats` should be `null`
        const stats = if (parsed.video_count) |_| Stats{
            .video_count = parsed.video_count.?,
            .subscriber_count = parsed.subscriber_count orelse return error.MissingField,
            .view_count = parsed.view_count orelse return error.MissingField,
            .clip_count = parsed.clip_count orelse 0,
        } else null;

        return .{
            .id = parsed.id,
            .name = parsed.name,
            .english_name = parsed.english_name,
            .type = parsed.type,
            .org = parsed.org,
            .group = group,
            .photo = parsed.photo,
            .stats = stats,
        };
    }
};

/// A comment with a timestamp(s) on a video.
pub const TimestampComment = struct {
    /// YouTube id of the comment. Navigating to
    /// `https://www.youtube.com/watch?v={video.id}&lc={id}` highlights the comment.
    id: []const u8,
    /// Content of the comment.
    content: []const u8,

    const Self = @This();
    pub const format = holodex.defaultFormat(@This(), struct {});

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!TimestampComment {
        const Json = struct {
            comment_key: []const u8,
            message: []const u8,
        };
        const parsed = try json.innerParse(Json, allocator, source, options);
        return .{
            .id = parsed.comment_key,
            .content = parsed.message,
        };
    }
};

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!Self {
    const Json = struct {
        id: []const u8,
        title: []const u8,
        type: Type,
        topic_id: ?datatypes.Topic = null,
        published_at: ?datatypes.Timestamp = null,
        available_at: datatypes.Timestamp,
        duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
        status: Status,
        lang: ?datatypes.Language = null,
        live_tl_count: ?std.json.ArrayHashMap(u32) = null,
        // Only returned when 'includes' contains 'description'
        description: ?[]const u8 = null,
        // Ignore `songscount`
        // Only returned when 'includes' contains 'songs'
        songs: ?[]const datatypes.Song = null,
        channel: Channel,

        // Only returned when 'includes' contains 'live_info'
        start_scheduled: ?datatypes.Timestamp = null,
        start_actual: ?datatypes.Timestamp = null,
        end_actual: ?datatypes.Timestamp = null,
        live_viewers: ?u64 = null,

        // Only returned when 'includes' contains 'clips'
        clips: ?[]const VideoMin = null,
        // Only returned when 'includes' contains 'sources'
        sources: ?[]const VideoMin = null,
        // Only returned when 'includes' contains 'refers'
        refers: ?[]const VideoMin = null,
        // Only returned when 'includes' contains 'simulcasts'
        simulcasts: ?[]const VideoMin = null,
        // Only returned when 'includes' contains 'mentions'
        mentions: ?[]const datatypes.Vtuber = null,
        // Only returned when c === '1', comments with timestamps only
        comments: ?[]const TimestampComment = null,
    };

    const parsed = try json.innerParse(Json, allocator, source, options);

    // Use non-nullable `live_viewers` field to check if `live_info` should be `null`.
    const live_info = if (parsed.live_viewers) |live_viewers| LiveInfo{
        .start_scheduled = parsed.start_scheduled,
        .start_actual = parsed.start_actual,
        .end_actual = parsed.end_actual,
        .live_viewers = live_viewers,
    } else null;

    return .{
        .id = parsed.id,
        .title = parsed.title,
        .type = parsed.type,
        .topic = parsed.topic_id,
        .published_at = parsed.published_at,
        .available_at = parsed.available_at,
        .duration = parsed.duration,
        .status = parsed.status,
        .lang = parsed.lang,
        .live_tl_count = if (parsed.live_tl_count) |map| map.map else null,
        .description = parsed.description,
        .songs = parsed.songs,
        .live_info = live_info,
        .channel = parsed.channel,
        .clips = parsed.clips,
        .sources = parsed.sources,
        .refers = parsed.refers,
        .simulcasts = parsed.simulcasts,
        .mentions = parsed.mentions,
        .timestamp_comments = parsed.comments,
    };
}
