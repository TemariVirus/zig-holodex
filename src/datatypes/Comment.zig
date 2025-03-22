//! A comment with a timestamp(s) on a searched video.

const std = @import("std");

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;

/// YouTube id of the comment. Navigating to
/// `https://www.youtube.com/watch?v={video.id}&lc={id}` highlights the comment.
id: []const u8,
/// Content of the comment.
content: []const u8,
/// Video the comment is from.
video: *const datatypes.SearchedVideo,

const Self = @This();
pub const format = holodex.defaultFormat(@This(), struct {});
