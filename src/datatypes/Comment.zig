//! A comment with a timestamp(s) on a video.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube id of the comment.
id: []const u8,
/// Content of the comment.
content: []const u8,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});

/// The JSON representation of a `Comment`.
pub const Json = struct {
    comment_key: []const u8,
    message: []const u8,

    /// Convert to a `Comment`. This function leaks memory when returning an error.
    /// Use an arena allocator to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) datatypes.JsonConversionError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.comment_key),
            .content = try holodex.deepCopy(allocator, self.message),
        };
    }
};
