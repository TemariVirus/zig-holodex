//! Minimum information about a video.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube video id.
id: []const u8,
/// Language of the video. The translated language if the video is a subbed clip.
lang: ?datatypes.Language = null,
/// Type of the video.
type: datatypes.VideoFull.Type,
/// YouTube video title.
title: []const u8,
/// Status of the video.
status: datatypes.VideoFull.Status,
/// Channel the video is from.
channel: Channel,
/// Duration of the video. `0` if the video is a stream that has not ended.
duration: datatypes.Duration,
/// When the video went live or became viewable.
available_at: ?datatypes.Timestamp = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// Channel information associated with a `VideoMin`.
pub const Channel = struct {
    /// YouTube channel id.
    id: []const u8,
    /// YouTube channel name.
    name: []const u8,
    /// English name of the channel/channel owner.
    english_name: ?datatypes.EnglishName = null,
    /// VTuber organization the channel is part of.
    org: ?datatypes.Organization = null,
    /// URL to the channel's profile picture.
    photo: []const u8,

    pub const format = holodex.defaultFormat(@This(), struct {});
};
