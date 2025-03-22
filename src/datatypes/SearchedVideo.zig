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
duration: datatypes.Duration = .fromSeconds(0),
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
};
