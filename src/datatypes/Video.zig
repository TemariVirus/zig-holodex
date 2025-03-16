//! Basic information about a video.

const std = @import("std");

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

    /// The JSON representation of a `Video.Channel`.
    pub const Json = struct {
        id: []const u8,
        name: []const u8,
        english_name: ?[]const u8 = null,
        type: datatypes.ChannelFull.Type,
        org: ?[]const u8 = null,
        suborg: ?[]const u8 = null,
        photo: []const u8,

        /// Convert to a `Video.Channel`. This function leaks memory when returning an error.
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

            return .{
                .id = try holodex.deepCopy(allocator, self.id),
                .name = try holodex.deepCopy(allocator, self.name),
                .english_name = try holodex.deepCopy(allocator, self.english_name),
                .type = self.type,
                .org = try holodex.deepCopy(allocator, self.org),
                .group = group,
                .photo = try holodex.deepCopy(allocator, self.photo),
            };
        }
    };
};

/// The JSON representation of a `Video`.
pub const Json = struct {
    id: []const u8,
    title: []const u8,
    type: datatypes.VideoFull.Type,
    topic_id: ?[]const u8 = null,
    published_at: ?[]const u8 = null,
    available_at: []const u8,
    duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
    status: datatypes.VideoFull.Status,
    start_scheduled: ?[]const u8 = null,
    start_actual: ?[]const u8 = null,
    end_actual: ?[]const u8 = null,
    live_viewers: u64,
    channel: Channel.Json,

    /// Convert to a `Video`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .title = try holodex.deepCopy(allocator, self.title),
            .type = self.type,
            .topic = try holodex.deepCopy(allocator, self.topic_id),
            .published_at = try holodex.parseOptionalTimestamp(self.published_at),
            .available_at = try datatypes.Timestamp.parseISO(self.available_at),
            .duration = self.duration,
            .status = self.status,
            .live_info = .{
                .start_scheduled = try holodex.parseOptionalTimestamp(self.start_scheduled),
                .start_actual = try holodex.parseOptionalTimestamp(self.start_actual),
                .end_actual = try holodex.parseOptionalTimestamp(self.end_actual),
                .live_viewers = self.live_viewers,
            },
            .channel = try self.channel.to(allocator),
        };
    }
};
