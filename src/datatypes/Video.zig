//! Basic information about a video.

const std = @import("std");
const json = std.json;

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube video id.
id: []const u8,
/// YouTube video title.
title: []const u8,
/// Type of the video.
type: datatypes.VideoFull.Type,
/// Topic of the video (from Holodex).
topic: ?datatypes.Topic = null,
/// When the video was published.
published_at: ?datatypes.Timestamp = null,
/// When the video went live or became viewable.
available_at: datatypes.Timestamp,
/// Duration of the video. `0` if the video is a stream that has not ended.
duration: datatypes.Duration,
/// Status of the video.
status: datatypes.VideoFull.Status,
/// Information about the livestream. `null` if the video is not a stream.
live_info: ?datatypes.VideoFull.LiveInfo = null,
/// Channel associated with the video.
channel: Channel,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// Channel information associated with a `Video`.
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

    pub const format = holodex.defaultFormat(@This(), struct {});

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        source: anytype,
        options: json.ParseOptions,
    ) json.ParseError(@TypeOf(source.*))!Channel {
        const Json = struct {
            id: []const u8,
            name: []const u8,
            english_name: ?[]const u8 = null,
            type: datatypes.ChannelFull.Type,
            org: ?[]const u8 = null,
            suborg: ?[]const u8 = null,
            photo: []const u8,
        };

        const parsed = try json.innerParse(Json, allocator, source, options);
        const group = if (parsed.suborg) |suborg|
            if (suborg.len <= 2)
                null
            else
                // Remove the 2 random letters preceding the group name.
                suborg[2..]
        else
            null;
        return Channel{
            .id = parsed.id,
            .name = parsed.name,
            .english_name = parsed.english_name,
            .type = parsed.type,
            .org = parsed.org,
            .group = group,
            .photo = parsed.photo,
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
        type: datatypes.VideoFull.Type,
        topic_id: ?[]const u8 = null,
        published_at: ?datatypes.Timestamp = null,
        available_at: datatypes.Timestamp,
        duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
        status: datatypes.VideoFull.Status,
        start_scheduled: ?datatypes.Timestamp = null,
        start_actual: ?datatypes.Timestamp = null,
        end_actual: ?datatypes.Timestamp = null,
        live_viewers: u64,
        channel: Channel,
    };
    const parsed = try json.innerParse(Json, allocator, source, options);
    return Self{
        .id = parsed.id,
        .title = parsed.title,
        .type = parsed.type,
        .topic = parsed.topic_id,
        .published_at = parsed.published_at,
        .available_at = parsed.available_at,
        .duration = parsed.duration,
        .status = parsed.status,
        .live_info = .{
            .start_scheduled = parsed.start_scheduled,
            .start_actual = parsed.start_actual,
            .end_actual = parsed.end_actual,
            .live_viewers = parsed.live_viewers,
        },
        .channel = parsed.channel,
    };
}
