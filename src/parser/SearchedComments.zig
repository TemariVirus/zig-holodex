const std = @import("std");
const json = std.json;

const holodex = @import("../root.zig");
const datatypes = holodex.datatypes;
const helper = @import("helper.zig");

comments: []datatypes.Comment,

const ParseCommentsContext = struct {
    video_count: usize,
    comments: *std.ArrayList(datatypes.Comment),
};

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(source.*))!@This() {
    if (try source.next() != .array_begin) {
        return error.UnexpectedToken;
    }

    var searched_videos: std.ArrayList(datatypes.SearchedVideo) = .init(allocator);
    errdefer searched_videos.deinit();
    var comments: std.ArrayList(datatypes.Comment) = .init(allocator);
    errdefer comments.deinit();

    while (true) {
        if (try source.peekNextTokenType() == .array_end) {
            _ = try source.next();
            break;
        }
        const searched_video = try helper.parseAs(
            datatypes.SearchedVideo,
            &.{
                .{ .name = "id", .type = []const u8, .target = .{ .name = "id" } },
                .{ .name = "title", .type = []const u8, .target = .{ .name = "title" } },
                .{ .name = "type", .type = datatypes.VideoFull.Type, .target = .{ .name = "type" } },
                .{ .name = "topic_id", .type = ?datatypes.Topic, .target = .{ .name = "topic" }, .default = &@as(?datatypes.Topic, null) },
                .{ .name = "published_at", .type = ?datatypes.Timestamp, .target = .{ .name = "published_at" }, .default = &@as(?datatypes.Timestamp, null) },
                .{ .name = "available_at", .type = datatypes.Timestamp, .target = .{ .name = "available_at" } },
                .{ .name = "duration", .type = datatypes.Duration, .target = .{ .name = "duration" }, .default = &datatypes.Duration.fromSeconds(0) },
                .{ .name = "status", .type = datatypes.VideoFull.Status, .target = .{ .name = "status" } },
                .{ .name = "songcount", .type = u32, .target = .{ .name = "songcount" }, .default = &@as(u32, 0) },
                .{ .name = "channel", .type = datatypes.SearchedVideo.Channel, .target = .{ .name = "channel" } },
                .{ .name = "comments", .target = .{ .custom = parseComments } },
            },
            ParseCommentsContext{
                .video_count = searched_videos.items.len,
                .comments = &comments,
            },
            allocator,
            source,
            options,
        );

        try searched_videos.append(searched_video);
    }

    searched_videos.shrinkAndFree(searched_videos.items.len);
    // Add pointer to the offset now that searched_videos will not move
    for (comments.items) |*comment| {
        comment.video = @ptrFromInt(@intFromPtr(searched_videos.items.ptr) +
            @intFromPtr(comment.video) - // Offset from searched_videos[0], plus 1
            @sizeOf(datatypes.SearchedVideo)); // Subtract 1 to get the offset
    }
    return .{
        .comments = try comments.toOwnedSlice(),
    };
}

fn parseComments(
    context: anytype,
    field_name: []const u8,
    allocator: std.mem.Allocator,
    src: anytype,
    options: json.ParseOptions,
) json.ParseError(@TypeOf(src.*))!void {
    std.debug.assert(std.mem.eql(u8, field_name, "comments"));
    const ctx: ParseCommentsContext = context;

    if (try src.next() != .array_begin) {
        return error.UnexpectedToken;
    }

    while (true) {
        if (try src.peekNextTokenType() == .array_end) {
            _ = try src.next();
            return;
        }
        var comment = try helper.parseAs(
            datatypes.Comment,
            &.{
                .{ .name = "comment_key", .type = []const u8, .target = .{ .name = "id" } },
                .{ .name = "message", .type = []const u8, .target = .{ .name = "content" } },
            },
            {},
            allocator,
            src,
            options,
        );
        // Set as offset from searched_videos[0] + 1 for now. We cannot use 0 as it
        // is reserved for null pointers.
        comment.video = @ptrFromInt(@sizeOf(datatypes.SearchedVideo) * (ctx.video_count + 1));
        try ctx.comments.append(comment);
    }
}
