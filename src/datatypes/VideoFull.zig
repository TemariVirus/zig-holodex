//! Full information about a video.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;
const VideoMin = datatypes.VideoMin;

/// YouTube video id.
id: []const u8,
/// YouTube video title.
title: []const u8,
/// Type of the video. Either a stream or a clip.
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
timestamp_comments: ?[]const datatypes.Comment = null,

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

    /// The JSON representation of a `VideoFull.Channel`.
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

        /// Convert to a `VideoFull.Channel`. This function leaks memory when returning an error.
        /// Use an arena allocator to free memory properly.
        pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Channel {
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
};

/// The JSON representation of a `VideoFull`.
pub const Json = struct {
    id: []const u8,
    title: []const u8,
    type: Type,
    topic_id: ?[]const u8 = null,
    published_at: ?[]const u8 = null,
    available_at: []const u8,
    duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
    status: Status,
    lang: ?[]const u8 = null,
    live_tl_count: ?std.json.ArrayHashMap(u32) = null,
    // Only returned when 'includes' contains 'description'
    description: ?[]const u8 = null,
    // Ignore `songscount`
    // Only returned when 'includes' contains 'songs'
    songs: ?[]const datatypes.Song.Json = null,
    channel: Channel.Json,

    // Only returned when 'includes' contains 'live_info'
    start_scheduled: ?[]const u8 = null,
    start_actual: ?[]const u8 = null,
    end_actual: ?[]const u8 = null,
    live_viewers: ?u64 = null,

    // Only returned when 'includes' contains 'clips'
    clips: ?[]const VideoMin.Json = null,
    // Only returned when 'includes' contains 'sources'
    sources: ?[]const VideoMin.Json = null,
    // Only returned when 'includes' contains 'refers'
    refers: ?[]const VideoMin.Json = null,
    // Only returned when 'includes' contains 'simulcasts'
    simulcasts: ?[]const VideoMin.Json = null,
    // Only returned when 'includes' contains 'mentions'
    mentions: ?[]const datatypes.Vtuber.Json = null,
    // Only returned when c === '1', comments with timestamps only
    comments: ?[]const datatypes.Comment.Json = null,

    fn toOptionalArray(
        Child: type,
        allocator: std.mem.Allocator,
        array: ?[]const Child.Json,
    ) datatypes.JsonConversionError!?[]Child {
        if (array) |arr| {
            const converted = try allocator.alloc(Child, arr.len);
            for (0..arr.len) |i| {
                converted[i] = try arr[i].to(allocator);
            }
            return converted;
        } else {
            return null;
        }
    }

    /// Convert to a `VideoFull`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        const live_tl_count = if (self.live_tl_count) |map| blk: {
            var copy: std.StringArrayHashMapUnmanaged(u32) = .empty;
            try copy.ensureTotalCapacity(allocator, map.map.count());
            var iter = map.map.iterator();
            while (iter.next()) |entry| {
                copy.entries.appendAssumeCapacity(.{
                    .key = try allocator.dupe(u8, entry.key_ptr.*),
                    .value = entry.value_ptr.*,
                    // Re-indexing will compute this hash later
                    .hash = undefined,
                });
            }
            try copy.reIndex(allocator);
            break :blk copy;
        } else null;

        // Use non-nullable `live_viewers` field to check if `live_info` should be `null`.
        const live_info = if (self.live_viewers) |live_viewers| LiveInfo{
            .start_scheduled = try holodex.parseOptionalTimestamp(self.start_scheduled),
            .start_actual = try holodex.parseOptionalTimestamp(self.start_actual),
            .end_actual = try holodex.parseOptionalTimestamp(self.end_actual),
            .live_viewers = live_viewers,
        } else null;

        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .title = try holodex.deepCopy(allocator, self.title),
            .type = self.type,
            .topic = try holodex.deepCopy(allocator, self.topic_id),
            .published_at = try holodex.parseOptionalTimestamp(self.published_at),
            .available_at = try datatypes.Timestamp.parseISO(self.available_at),
            .duration = self.duration,
            .status = self.status,
            .lang = try holodex.deepCopy(allocator, self.lang),
            .live_tl_count = live_tl_count,
            .description = try holodex.deepCopy(allocator, self.description),
            .songs = try toOptionalArray(datatypes.Song, allocator, self.songs),
            .channel = try self.channel.to(allocator),

            .live_info = live_info,
            .clips = try toOptionalArray(VideoMin, allocator, self.clips),
            .sources = try toOptionalArray(VideoMin, allocator, self.sources),
            .refers = try toOptionalArray(VideoMin, allocator, self.refers),
            .simulcasts = try toOptionalArray(VideoMin, allocator, self.simulcasts),
            .mentions = try toOptionalArray(datatypes.Vtuber, allocator, self.mentions),
            .timestamp_comments = try toOptionalArray(datatypes.Comment, allocator, self.comments),
        };
    }
};
