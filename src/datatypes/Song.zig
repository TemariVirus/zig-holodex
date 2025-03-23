//! Information about a song performance.

const std = @import("std");
const json = std.json;

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// Holodex ID of the song performance. This is not the song's ID.
holodex_id: datatypes.Uuid,
/// Name of the song performed.
name: []const u8,
/// Name of the original artist of the song.
original_artist: []const u8,
/// Start time of the song performance in the video.
start: datatypes.VideoOffset,
/// End time of the song performance in the video.
end: datatypes.VideoOffset,
/// URL to the song's cover art.
art: ?[]const u8,
/// iTunes ID of the song.
itunes_id: ?ItunesId,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

pub const ItunesId = enum(u64) { _ };

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!Self {
    const Json = struct {
        id: datatypes.Uuid,
        name: []const u8,
        original_artist: []const u8,
        start: datatypes.VideoOffset,
        end: datatypes.VideoOffset,
        art: ?[]const u8 = null,
        itunesid: ?ItunesId = null,
    };

    const parsed = try json.innerParse(Json, allocator, source, options);
    return Self{
        .holodex_id = parsed.id,
        .name = parsed.name,
        .original_artist = parsed.original_artist,
        .start = parsed.start,
        .end = parsed.end,
        .art = parsed.art,
        .itunes_id = parsed.itunesid,
    };
}
