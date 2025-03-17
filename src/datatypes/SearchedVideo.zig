//! Information about a video that was searched for.

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
/// Number of songs in the video.
songcount: u32 = 0,
/// Channel associated with the video.
channel: Channel,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// Channel information associated with a `SearchedVideo`.
pub const Channel = struct {
    /// YouTube channel id.
    id: []const u8,
    /// YouTube channel name.
    name: []const u8,
    /// English name of the channel/channel owner.
    english_name: ?datatypes.EnglishName = null,
    /// Type of the channel.
    type: datatypes.ChannelFull.Type,
    /// URL to the channel's profile picture.
    photo: []const u8,

    pub const format = holodex.defaultFormat(@This(), struct {});

    /// The JSON representation of a `SearchedVideo.Channel`.
    pub const Json = struct {
        id: []const u8,
        name: []const u8,
        type: datatypes.ChannelFull.Type,
        photo: []const u8,
        english_name: ?[]const u8 = null,

        /// Convert to a `SearchChannel.Channel`. This function leaks memory when returning an error.
        /// Use an arena allocator to free memory properly.
        pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Channel {
            return .{
                .id = try holodex.deepCopy(allocator, self.id),
                .name = try holodex.deepCopy(allocator, self.name),
                .english_name = try holodex.deepCopy(allocator, self.english_name),
                .type = self.type,
                .photo = try holodex.deepCopy(allocator, self.photo),
            };
        }
    };
};

/// The JSON representation of a `SearchedVideo`.
pub const Json = struct {
    id: []const u8,
    title: []const u8,
    type: datatypes.VideoFull.Type,
    topic_id: ?[]const u8 = null,
    published_at: ?[]const u8 = null,
    available_at: []const u8,
    duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
    status: datatypes.VideoFull.Status,
    songcount: u32 = 0,
    channel: Channel.Json,
    comments: ?[]datatypes.Comment.Json = null,

    /// Convert to a `SearchChannel`. This function leaks memory when returning an error.
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
            .songcount = self.songcount,
            .channel = try self.channel.to(allocator),
        };
    }
};
