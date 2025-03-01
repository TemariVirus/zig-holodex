//! Information about a song performance.

const std = @import("std");

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
art: []const u8,
/// iTunes ID of the song.
itunes_id: u64,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `Song`.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    original_artist: []const u8,
    start: datatypes.VideoOffset,
    end: datatypes.VideoOffset,
    art: []const u8,
    itunesid: u64,

    /// Convert to a `Song`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return Self{
            .holodex_id = try datatypes.Uuid.parse(self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .original_artist = try holodex.deepCopy(allocator, self.original_artist),
            .start = self.start,
            .end = self.end,
            .art = try holodex.deepCopy(allocator, self.art),
            .itunes_id = self.itunesid,
        };
    }
};
