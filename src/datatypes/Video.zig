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
channel: datatypes.VideoChannel,
/// Duration of the video. `0` if the video is a stream that has not ended.
duration: datatypes.Duration,
/// When the video went live or became viewable.
available_at: ?datatypes.Timestamp = null,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `Video`.
pub const Json = struct {
    id: []const u8,
    lang: ?[]const u8 = null,
    type: datatypes.VideoFull.Type,
    title: []const u8,
    status: datatypes.VideoFull.Status,
    channel: datatypes.VideoChannel.Json,
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
            .channel = try self.channel.to(allocator),
            .duration = self.duration,
            .available_at = try holodex.parseOptionalTimestamp(self.available_at),
        };
    }
};
