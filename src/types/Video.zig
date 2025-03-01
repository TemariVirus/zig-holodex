//! Basic information about a video.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube video id.
id: []const u8,
/// Language of the video. The translated language if the video is a subbed clip.
lang: ?datatypes.Language = null,
/// Type of the video. Either a stream or a clip.
type: datatypes.VideoFull.Type,
/// YouTube video title.
title: []const u8,
/// Status of the video.
status: datatypes.VideoFull.Status,
/// Channel the video is from.
channel: struct {
    /// YouTube channel id.
    id: []const u8,
    /// YouTube channel name.
    name: []const u8,
    /// English name of the channel/channel owner.
    english_name: ?datatypes.EnglishName,
    /// VTuber organization the channel is part of.
    org: ?[]const u8,
    /// URL to the channel's profile picture.
    photo: []const u8,
},
/// Duration of the video. `0` if the video is a stream that has not ended.
duration: datatypes.Duration,
/// When the video went live or became viewable.
available_at: ?datatypes.Timestamp,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `Video`.
pub const Json = struct {
    id: []const u8,
    lang: ?[]const u8 = null,
    type: datatypes.VideoFull.Type,
    title: []const u8,
    status: datatypes.VideoFull.Status,
    channel: struct {
        id: []const u8,
        name: []const u8,
        english_name: ?[]const u8 = null,
        org: ?[]const u8 = null,
        photo: []const u8,
    },
    duration: datatypes.Duration = datatypes.Duration.fromSeconds(0),
    available_at: ?[]const u8 = null,

    /// Convert to a `Video`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .lang = try holodex.deepCopy(allocator, self.lang),
            .type = self.type,
            .title = try holodex.deepCopy(allocator, self.title),
            .status = self.status,
            .channel = .{
                .id = try holodex.deepCopy(allocator, self.channel.id),
                .name = try holodex.deepCopy(allocator, self.channel.name),
                .english_name = try holodex.deepCopy(allocator, self.channel.english_name),
                .org = try holodex.deepCopy(allocator, self.channel.org),
                .photo = try holodex.deepCopy(allocator, self.channel.photo),
            },
            .duration = self.duration,
            .available_at = try holodex.parseOptionalTimestamp(self.available_at),
        };
    }
};
