// TODO: Test thread safety

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fmt = std.fmt;
const http = std.http;
const json = std.json;
const meta = std.meta;
const Uri = std.Uri;

const holodex = @import("root.zig");
const datatypes = holodex.datatypes;
const Pager = holodex.Pager;

const formatQuery = @import("QueryFormatter.zig").formatQuery;
const SearchCommentsResponse = @import("parser/SearchedComments.zig");

const package_version = @import("lib").version;
const user_agent_string = std.fmt.comptimePrint(
    "zig-holodex/{s} (zig/{s})",
    .{ package_version, @import("builtin").zig_version_string },
);

/// The API key to use for requests.
api_key: []const u8,
/// The base URI of the API.
base_uri: Uri,
/// The HTTP client to use for requests.
client: http.Client,

const Self = @This();
const empty_query = (struct {}){};

/// Errors that can occur when initializing an `Api` instance.
pub const InitError = Uri.ParseError || error{
    /// The URI scheme is not supported by `http.Client`.
    UnsupportedUriScheme,
    /// The URI is missing a host.
    UriMissingHost,
};

/// Errors that can occur when fetching data from the API.
pub const FetchError = http.Client.ConnectTcpError || error{
    /// The API key used is invalid or expired.
    BadApiKey,
    /// The requested resource was not found.
    NotFound,
    /// The rate limit has been exceeded. The user should wait before making
    /// another request.
    TooManyRequests,
    /// The server returned an unexpected response body. This likely indicates
    /// that the API has been updated and a newer version of this library
    /// should be used.
    InvalidJsonResponse,
    OutOfMemory,
    /// There was an error loading the TLS certificate bundle.
    TlsCertificateBundleLoadFailure,
    /// There usually isn't anything the user can do about this error, as they
    /// most likely arise from a bad server response or an unsupported feature
    /// in `std.http.Client`.
    UnexpectedFetchFailure,
};

/// The order to sort results in.
pub const SortOrder = enum {
    asc,
    desc,
};

/// How to sort search results.
pub const SearchOrder = enum {
    oldest,
    newest,
    longest,
};

pub fn Response(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        headers: datatypes.ResponseHeaders,
        value: T,

        pub const format = holodex.defaultFormat(@This(), struct {});

        pub fn deinit(self: @This()) void {
            const allocator = self.arena.child_allocator;
            self.arena.deinit();
            allocator.destroy(self.arena);
        }
    };
}

pub fn WithTotal(comptime T: type) type {
    return struct {
        total: u64,
        items: T,

        pub const format = holodex.defaultFormat(@This(), struct {});
    };
}

pub const InitOptions = struct {
    /// The allocator to use for the http client.
    allocator: Allocator,
    /// The API key to use for requests. This value must outlive it's `Api` instance.
    api_key: []const u8,
    /// The base URL of the API.
    location: union(enum) {
        /// The URL parsed as a URI.
        uri: Uri,
        /// The URL as a string. If used, this value must outlive it's `Api` instance.
        url: []const u8,
    } = .{ .uri = Uri.parse("https://holodex.net/api/v2") catch unreachable },
};
pub fn init(options: InitOptions) InitError!Self {
    const base_uri = removeTrailingSlash(switch (options.location) {
        .uri => |uri| uri,
        .url => |url| try Uri.parse(url),
    });

    const supported_schemes: std.StaticStringMap(void) = .initComptime(
        .{ .{"http"}, .{"https"} },
    );
    if (!supported_schemes.has(base_uri.scheme)) return InitError.UnsupportedUriScheme;
    if (base_uri.host == null) return InitError.UriMissingHost;

    return .{
        .api_key = options.api_key,
        .base_uri = base_uri,
        .client = http.Client{ .allocator = options.allocator },
    };
}

fn removeTrailingSlash(uri: Uri) Uri {
    var new_uri = uri;
    new_uri.path.percent_encoded = std.mem.trimRight(u8, uri.path.percent_encoded, "/");
    return new_uri;
}

pub fn deinit(self: *Self) void {
    self.client.deinit();
}

/// Helper function to fetch data from the API and parse it as JSON.
/// Returns an error if the response status is not 200 OK.
///
/// It is exposed to allow custom parsing of the response body through a
/// `jsonParse` implementation in `T`.
pub fn fetch(
    self: *Self,
    comptime T: type,
    allocator: Allocator,
    method: http.Method,
    path: []const u8,
    query: anytype,
    payload: anytype,
) FetchError!Response(T) {
    const stringify_options: json.StringifyOptions = .{
        .emit_nonportable_numbers_as_strings = false,
        // Skip null optional fields to save network bandwidth.
        .emit_null_optional_fields = false,
        .emit_strings_as_arrays = false,
        .escape_unicode = false,
        .whitespace = .minified,
    };

    var uri = self.base_uri;
    uri.path.percent_encoded = try fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ self.base_uri.path.percent_encoded, path },
    );
    defer allocator.free(uri.path.percent_encoded);
    uri.query = .{ .percent_encoded = try fmt.allocPrint(
        allocator,
        "{}",
        .{formatQuery(&query)},
    ) };
    defer allocator.free(uri.query.?.percent_encoded);

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = self.client.open(method, uri, .{
        .server_header_buffer = &server_header_buffer,
        .headers = .{
            .user_agent = .{ .override = user_agent_string },
            .content_type = .{ .override = "application/json" },
        },
        .extra_headers = &.{.{
            .name = "X-APIKEY",
            .value = self.api_key,
        }},
        .keep_alive = true,
        .redirect_behavior = @enumFromInt(3),
    }) catch |err| return httpToFetchError(err);
    defer req.deinit();

    if (payload) |p| {
        req.transfer_encoding = .{
            .content_length = countJsonLen(p, stringify_options),
        };
    }

    // Redirect loop
    while (true) {
        req.send() catch |err| return httpToFetchError(err);
        if (payload) |p| {
            json.stringify(
                p,
                stringify_options,
                req.writer(),
            ) catch |err| return httpToFetchError(err);
        }
        req.finish() catch |err| return httpToFetchError(err);
        req.wait() catch |err| switch (err) {
            // req.redirect_behavior should prevent an infinite loop
            http.Client.Request.WaitError.RedirectRequiresResend => continue,
            else => return httpToFetchError(err),
        };
        break;
    }

    switch (req.response.status) {
        .ok => {},
        .forbidden => return FetchError.BadApiKey,
        .not_found => return FetchError.NotFound,
        .too_many_requests => return FetchError.TooManyRequests,
        else => return FetchError.UnexpectedFetchFailure,
    }

    var body_reader = json.reader(allocator, req.reader());
    defer body_reader.deinit();
    const parsed = json.parseFromTokenSource(T, allocator, &body_reader, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch |err| switch (err) {
        error.OutOfMemory => return FetchError.OutOfMemory,
        else => return FetchError.InvalidJsonResponse,
    };
    errdefer parsed.deinit();

    return .{
        .arena = parsed.arena,
        .headers = datatypes.ResponseHeaders.parse(req.response.parser.get()) catch
            return FetchError.UnexpectedFetchFailure,
        .value = parsed.value,
    };
}

fn countJsonLen(value: anytype, options: json.StringifyOptions) u64 {
    var counter = std.io.countingWriter(std.io.null_writer);
    json.stringify(value, options, counter.writer()) catch unreachable;
    return counter.bytes_written;
}

const HttpError = http.Client.RequestError ||
    http.Client.Request.SendError ||
    http.Client.Request.WriteError ||
    http.Client.Request.FinishError ||
    http.Client.Request.WaitError;
fn httpToFetchError(err: HttpError) FetchError {
    switch (err) {
        http.Client.RequestError.InvalidCharacter,
        http.Client.RequestError.Overflow,
        http.Client.RequestError.UnsupportedTransferEncoding,
        http.Client.RequestError.UnsupportedUriScheme, // Checked in `init`
        http.Client.RequestError.UriMissingHost, // Checked in `init`
        http.Client.Request.WriteError.MessageTooLong,
        http.Client.Request.WriteError.NotWriteable,
        http.Client.Request.FinishError.MessageNotCompleted,
        http.Client.Request.WaitError.HttpConnectionHeaderUnsupported,
        http.Client.Request.WaitError.RedirectRequiresResend,
        => unreachable,

        http.Client.RequestError.ConnectionRefused,
        http.Client.RequestError.ConnectionResetByPeer,
        http.Client.RequestError.ConnectionTimedOut,
        http.Client.RequestError.HostLacksNetworkAddresses,
        http.Client.RequestError.NameServerFailure,
        http.Client.RequestError.NetworkUnreachable,
        http.Client.RequestError.OutOfMemory,
        http.Client.RequestError.TemporaryNameServerFailure,
        http.Client.RequestError.TlsInitializationFailed,
        http.Client.RequestError.UnexpectedConnectFailure,
        http.Client.RequestError.UnknownHostName,
        => return @errorCast(err),
        http.Client.RequestError.CertificateBundleLoadFailure => return FetchError.TlsCertificateBundleLoadFailure,

        // There usually isn't anything the user can do about these errors, as
        // they arise from a bad server response or an unsupported feature in
        // `http.Client`.
        http.Client.Request.WriteError.UnexpectedWriteFailure,
        http.Client.Request.WaitError.CompressionInitializationFailed,
        http.Client.Request.WaitError.CompressionUnsupported,
        http.Client.Request.WaitError.EndOfStream,
        http.Client.Request.WaitError.HttpChunkInvalid,
        http.Client.Request.WaitError.HttpHeaderContinuationsUnsupported,
        http.Client.Request.WaitError.HttpHeadersInvalid,
        http.Client.Request.WaitError.HttpHeadersOversize,
        http.Client.Request.WaitError.HttpRedirectLocationInvalid,
        http.Client.Request.WaitError.HttpRedirectLocationMissing,
        http.Client.Request.WaitError.HttpTransferEncodingUnsupported,
        http.Client.Request.WaitError.InvalidContentLength,
        http.Client.Request.WaitError.TlsAlert,
        http.Client.Request.WaitError.TlsFailure,
        http.Client.Request.WaitError.TooManyHttpRedirects,
        http.Client.Request.WaitError.UnexpectedReadFailure,
        => return FetchError.UnexpectedFetchFailure,
    }
}

/// Query options for `live` and `liveWithTotal`.
pub const LiveOptions = struct {
    /// YouTube video ids. If not null, only these videos can be returned.
    /// Other filters still apply.
    video_ids: ?[]const []const u8 = null,
    /// YouTube channel id. If not null, only videos from this channel can be
    /// returned.
    channel_id: ?[]const u8 = null,
    /// Filter by any of the included types.
    types: []const datatypes.VideoFull.Type = &.{.stream},
    /// Only include videos of this topic. Leave null to disable this filter.
    topic: ?datatypes.Topic = null,
    /// Filter by any of the included statuses. Must not include `Status.past`.
    statuses: []const datatypes.VideoFull.Status = &.{ .live, .upcoming },
    /// Filter by any of the included languages. Leave null to query all.
    langs: ?[]const datatypes.Language = null,
    /// Only include videos that are upcoming within this many hours. Does not
    /// filter out videos that are not `Status.upcoming`.
    max_upcoming_hours: u64 = 48,
    /// Only include videos involving this organization. Leave null to disable
    /// this filter.
    org: ?datatypes.Organization = null,
    /// Only include videos mentioning this channel, and are not posted on the
    /// channel itself. Leave null to disable this filter.
    mentioned_channel_id: ?[]const u8 = null,
    /// List of additional information to include for each video. `live_info`
    /// is always included, regardless of this field.
    includes: []const VideoIncludes = &.{},
    /// Column to sort on.
    sort: meta.FieldEnum(datatypes.VideoFull.Json) = .available_at,
    /// Sort order.
    order: SortOrder = .asc,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be greater than 0, and less
    /// than or equal to `max_limit`.
    limit: u64 = 9999,

    pub const max_limit: u64 = 100000;
};

/// The Holodex API version of `LiveOptions`.
const LiveOptionsApi = struct {
    id: ?[]const []const u8,
    channel_id: ?[]const u8,
    type: []const datatypes.VideoFull.Type,
    topic: ?datatypes.Topic,
    status: []const datatypes.VideoFull.Status,
    lang: ?[]const datatypes.Language,
    max_upcoming_hours: u64,
    org: ?datatypes.Organization,
    mentioned_channel_id: ?[]const u8,
    include: ?[]const VideoIncludes,
    sort: meta.FieldEnum(datatypes.VideoFull.Json),
    order: SortOrder,
    offset: u64,
    limit: u64,
    paginated: ?bool,

    pub fn fromLib(options: LiveOptions, paginated: bool) LiveOptionsApi {
        return LiveOptionsApi{
            .id = options.video_ids,
            .channel_id = options.channel_id,
            .type = options.types,
            .topic = options.topic,
            .status = options.statuses,
            .lang = options.langs,
            .max_upcoming_hours = options.max_upcoming_hours,
            .org = options.org,
            .mentioned_channel_id = options.mentioned_channel_id,
            .include = if (options.includes.len == 0) null else options.includes,
            .sort = options.sort,
            .order = options.order,
            .offset = options.offset,
            .limit = options.limit,
            .paginated = if (paginated) true else null,
        };
    }
};

fn liveAssumeLimit(
    self: *Self,
    allocator: Allocator,
    options: LiveOptions,
) FetchError!Response([]datatypes.VideoFull) {
    return self.fetch(
        []datatypes.VideoFull,
        allocator,
        .GET,
        "/live",
        LiveOptionsApi.fromLib(options, false),
        null,
    );
}

/// Fetch currently upcoming or live streams. This corresponds to the `/live`
/// endpoint. This is somewhat similar to calling `videos` but with default
/// options, and `live_info` is always included.
///
/// - Use `liveWithTotal` to get the videos with a total.
/// - Use `pageLive` to page through the results without a total.
pub fn live(
    self: *Self,
    allocator: Allocator,
    options: LiveOptions,
) (FetchError || error{InvalidLimit})!Response([]datatypes.VideoFull) {
    if (options.limit <= 0 or options.limit > LiveOptions.max_limit) return error.InvalidLimit;
    return self.liveAssumeLimit(allocator, options);
}

/// The same as `live`, but includes the total number of videos matching the
/// given options.
///
/// - Use `live` to get the videos without a total.
/// - Use `pagelive` to page through the results without a total.
pub fn liveWithTotal(
    self: *Self,
    allocator: Allocator,
    options: LiveOptions,
) (FetchError || error{InvalidLimit})!Response(WithTotal([]datatypes.VideoFull)) {
    if (options.limit <= 0 or options.limit > LiveOptions.max_limit) return error.InvalidLimit;
    return self.fetch(
        WithTotal([]datatypes.VideoFull),
        allocator,
        .GET,
        "/live",
        LiveOptionsApi.fromLib(options, true),
        null,
    );
}

/// Create a pager that iterates over the results of `live`.
/// `deinit` must be called on the returned pager to free the memory used by it.
///
/// - Use `live` to get the videos without a total.
/// - Use `liveWithTotal` to get the videos with a total.
pub fn pageLive(
    self: *Self,
    allocator: Allocator,
    options: LiveOptions,
) error{InvalidLimit}!Pager(datatypes.VideoFull, LiveOptions, liveAssumeLimit) {
    if (options.limit <= 0 or options.limit > LiveOptions.max_limit) return error.InvalidLimit;
    return Pager(datatypes.VideoFull, LiveOptions, liveAssumeLimit){
        .allocator = allocator,
        .api = self,
        .options = options,
    };
}

/// Extra information to include for videos.
pub const VideoIncludes = enum {
    clips,
    refers,
    sources,
    simulcasts,
    mentions,
    description,
    live_info,
    channel_stats,
    songs,
};

/// Query options for `videos` and `videoWithTotal`.
pub const VideosOptions = struct {
    /// YouTube video ids. If not null, only these videos can be returned.
    /// Other filters still apply.
    video_ids: ?[]const []const u8 = null,
    /// YouTube channel id. If not null, only videos from this channel can be
    /// returned.
    channel_id: ?[]const u8 = null,
    /// Filter by any of the included types. Leave null to query all.
    types: ?[]const datatypes.VideoFull.Type = null,
    /// Only include videos of this topic. Leave null to disable this filter.
    topic: ?datatypes.Topic = null,
    /// Only include videos that have an `available_at` timestamp greater than
    /// or equal to this value. Leave null to disable this filter.
    from: ?datatypes.Timestamp = null,
    /// Only include videos that have an `available_at` timestamp less than or
    /// equal to this value. Leave null to disable this filter.
    to: ?datatypes.Timestamp = null,
    /// Filter by any of the included statuses. Leave null to query all.
    statuses: ?[]const datatypes.VideoFull.Status = null,
    /// Filter by any of the included languages. Leave null to query all.
    langs: ?[]const datatypes.Language = null,
    /// Only include videos that are upcoming within this many hours. Does not
    /// filter out videos that are not `Status.upcoming`. Leave null to disable
    /// this filter.
    max_upcoming_hours: ?u64 = null,
    /// Only include videos involving this organization. Leave null to disable
    /// this filter.
    org: ?datatypes.Organization = null,
    /// Only include videos mentioning this channel, and are not posted on the
    /// channel itself. Leave null to disable this filter.
    mentioned_channel_id: ?[]const u8 = null,
    /// List of additional information to include for each video.
    includes: []const VideoIncludes = &.{},
    /// Column to sort on.
    sort: meta.FieldEnum(datatypes.VideoFull.Json) = .available_at,
    /// Sort order.
    order: SortOrder = .desc,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be greater than 0, and less
    /// than or equal to `max_limit`.
    limit: usize = 25,

    pub const max_limit: usize = 100;
};

/// The Holodex API version of `VideosOptions`.
const VideosOptionsApi = struct {
    id: ?[]const []const u8,
    channel_id: ?[]const u8,
    status: ?[]const datatypes.VideoFull.Status,
    lang: ?[]const datatypes.Language,
    type: ?[]const datatypes.VideoFull.Type,
    topic: ?datatypes.Topic,
    include: ?[]const VideoIncludes,
    org: ?datatypes.Organization,
    mentioned_channel_id: ?[]const u8,
    sort: meta.FieldEnum(datatypes.VideoFull.Json),
    order: SortOrder,
    limit: usize,
    offset: u64,
    paginated: ?bool,
    max_upcoming_hours: ?u64,
    from: ?datatypes.Timestamp,
    to: ?datatypes.Timestamp,

    pub fn fromLib(options: VideosOptions, paginated: bool) VideosOptionsApi {
        return .{
            .id = options.video_ids,
            .channel_id = options.channel_id,
            .status = options.statuses,
            .lang = options.langs,
            .type = options.types,
            .topic = options.topic,
            .include = if (options.includes.len == 0) null else options.includes,
            .org = options.org,
            .mentioned_channel_id = options.mentioned_channel_id,
            .sort = options.sort,
            .order = options.order,
            .limit = options.limit,
            .offset = options.offset,
            .paginated = if (paginated) true else null,
            .max_upcoming_hours = options.max_upcoming_hours,
            .from = options.from,
            .to = options.to,
        };
    }
};

fn videosAssumeLimit(
    self: *Self,
    allocator: Allocator,
    options: VideosOptions,
) FetchError!Response([]datatypes.VideoFull) {
    return self.fetch(
        []datatypes.VideoFull,
        allocator,
        .GET,
        "/videos",
        VideosOptionsApi.fromLib(options, false),
        null,
    );
}

/// Fetch videos matching the given options. This corresponds to the `/videos`
/// endpoint.
///
/// - Use `videosWithTotal` to get the videos with a total.
/// - Use `pageVideos` to page through the results without a total.
pub fn videos(
    self: *Self,
    allocator: Allocator,
    options: VideosOptions,
) (FetchError || error{InvalidLimit})!Response([]datatypes.VideoFull) {
    if (options.limit <= 0 or options.limit > VideosOptions.max_limit) return error.InvalidLimit;
    return self.videosAssumeLimit(allocator, options);
}

/// The same as `videos`, but includes the total number of videos matching the
/// given options.
///
/// - Use `videos` to get the videos without a total.
/// - Use `pageVidoes` to page through the results without a total.
pub fn videosWithTotal(
    self: *Self,
    allocator: Allocator,
    options: VideosOptions,
) (FetchError || error{InvalidLimit})!Response(WithTotal([]datatypes.VideoFull)) {
    if (options.limit <= 0 or options.limit > VideosOptions.max_limit) return error.InvalidLimit;
    return self.fetch(
        WithTotal([]datatypes.VideoFull),
        allocator,
        .GET,
        "/videos",
        VideosOptionsApi.fromLib(options, true),
        null,
    );
}

/// Create a pager that iterates over the results of `videos`.
/// `deinit` must be called on the returned pager to free the memory used by it.
///
/// - Use `videos` to get the videos without a total.
/// - Use `videosWithTotal` to get the videos with a total.
pub fn pageVideos(
    self: *Self,
    allocator: Allocator,
    options: VideosOptions,
) error{InvalidLimit}!Pager(datatypes.VideoFull, VideosOptions, videosAssumeLimit) {
    if (options.limit <= 0 or options.limit > VideosOptions.max_limit) return error.InvalidLimit;
    return Pager(datatypes.VideoFull, VideosOptions, videosAssumeLimit){
        .allocator = allocator,
        .api = self,
        .options = options,
    };
}

/// Fetch information about a YouTube channel. This corresponds to the
/// `/channels/{channelId}` endpoint.
pub fn channelInfo(
    self: *Self,
    allocator: Allocator,
    id: []const u8,
) FetchError!Response(datatypes.ChannelFull) {
    const path = try fmt.allocPrint(allocator, "/channels/{s}", .{id});
    defer allocator.free(path);
    return self.fetch(
        datatypes.ChannelFull,
        allocator,
        .GET,
        path,
        empty_query,
        null,
    );
}

/// Fetch currently upcoming or live streams for a set of channels. This
/// corresponds to the `/users/live` endpoint. This is similar to calling
/// `live` but replies much faster at the cost of customizability. Note that
/// the option `max_upcoming_hours=48` does not appear to be carried over from
/// `live`.
pub fn channelsLive(
    self: *Self,
    allocator: Allocator,
    channel_ids: []const []const u8,
) FetchError!Response([]datatypes.Video) {
    return self.fetch(
        []datatypes.Video,
        allocator,
        .GET,
        "/users/live",
        .{ .channels = channel_ids },
        null,
    );
}

/// Query options for `videoInfo`.
pub const VideoInfoOptions = struct {
    /// The YouTube video ID.
    video_id: []const u8,
    /// Whether to include timestamp comments.
    comments: bool = false,
};
/// The Holodex API version of `VideoInfoOptions`.
const VideoInfoOptionsApi = struct {
    /// Corresponds to the `comments` field.
    c: enum { @"0", @"1" },

    pub fn fromLib(options: VideoInfoOptions) VideoInfoOptionsApi {
        return VideoInfoOptionsApi{
            .c = switch (options.comments) {
                false => .@"0",
                true => .@"1",
            },
        };
    }
};

/// Fetch information about a video. This corresponds to the `/videos/{videoId}`
/// endpoint.
pub fn videoInfo(
    self: *Self,
    allocator: Allocator,
    options: VideoInfoOptions,
) FetchError!Response(datatypes.VideoFull) {
    const path = try fmt.allocPrint(allocator, "/videos/{s}", .{options.video_id});
    defer allocator.free(path);
    return self.fetch(
        datatypes.VideoFull,
        allocator,
        .GET,
        path,
        VideoInfoOptionsApi.fromLib(options),
        null,
    );
}

/// Query options for `listChannels`.
pub const ListChannelsOptions = struct {
    /// Filter by type of channel. Leave null to query all.
    type: ?datatypes.ChannelFull.Type = null,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be greater than 0, and less
    /// than or equal to `max_limit`.
    limit: usize = 25,
    /// If not null, filter VTubers belonging to this organization.
    org: ?datatypes.Organization = null,
    /// Filter by any of the included languages. Leave null to query all.
    lang: ?[]const datatypes.Language = null,
    /// Column to sort on.
    sort: meta.FieldEnum(datatypes.Channel.Json) = .org,
    /// Sort order.
    order: SortOrder = .asc,

    pub const max_limit: usize = 100;
};

/// List channels that match the given options. This corresponds to the
/// `/channels` endpoint. Use `pageChannels` to page through the results
/// instead. The total amount of items is not directly reported by the API.
pub fn listChannels(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
) (FetchError || error{InvalidLimit})!Response([]datatypes.Channel) {
    if (options.limit <= 0 or options.limit > ListChannelsOptions.max_limit) return error.InvalidLimit;
    return self.listChannelsAssumeLimit(allocator, options);
}

fn listChannelsAssumeLimit(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
) FetchError!Response([]datatypes.Channel) {
    return self.fetch(
        []datatypes.Channel,
        allocator,
        .GET,
        "/channels",
        options,
        null,
    );
}

/// Create a pager that iterates over the results of `listChannels`.
/// `deinit` must be called on the returned pager to free the memory used by it.
pub fn pageChannels(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
) error{InvalidLimit}!Pager(datatypes.Channel, ListChannelsOptions, listChannelsAssumeLimit) {
    if (options.limit <= 0 or options.limit > ListChannelsOptions.max_limit) return error.InvalidLimit;
    return Pager(datatypes.Channel, ListChannelsOptions, listChannelsAssumeLimit){
        .allocator = allocator,
        .api = self,
        .options = options,
    };
}

/// Options for `searchComments` and `searchCommentsWithTotal`.
pub const SearchCommentsOptions = struct {
    /// Search for comments containing this string (case insensitive).
    comment: []const u8,
    /// How to sort comments (based on the video they belong to).
    sort: SearchOrder = .newest,
    // This only affects comments on clips, but comments on clips are not
    // crawled, so this field has no effect.
    // langs: []const datatypes.Language = &.{},
    // Only comments on streams are crawled, so this field has no effect.
    // types: []const datatypes.VideoFull.Type = &.{},
    /// Only include videos of any of these topics. Leave empty to disable this
    /// filter.
    topics: []const datatypes.Topic = &.{},
    /// Only include videos involving all of these channels. Leave empty to
    /// disable this filter.
    channels: []const []const u8 = &.{},
    /// Only include videos involving Vtubers from all of these organizations.
    /// Leave empty to disable this filter.
    orgs: []const datatypes.Organization = &.{},
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be greater than 0, and less
    /// than or equal to `max_limit`.
    limit: usize = 30,

    pub const max_limit: usize = 100_000;
};
/// The Holodex API version of `SearchCommentsOptions`.
const SearchCommentsOptionsApi = struct {
    sort: SearchOrder,
    comptime lang: ?[]const datatypes.Language = null,
    comptime target: ?[]const datatypes.VideoFull.Type = null,
    // Questionable design choice, but okay.
    comment: [1][]const u8,
    topic: ?[]const datatypes.Topic,
    vch: ?[]const []const u8,
    org: ?[]const datatypes.Organization,
    offset: u64,
    limit: usize,
    paginated: bool,

    pub fn fromLib(options: SearchCommentsOptions, paginated: bool) SearchCommentsOptionsApi {
        return SearchCommentsOptionsApi{
            .sort = options.sort,
            .comment = .{options.comment},
            .topic = if (options.topics.len == 0) null else options.topics,
            .vch = if (options.channels.len == 0) null else options.channels,
            .org = if (options.orgs.len == 0) null else options.orgs,
            .offset = options.offset,
            .limit = options.limit,
            .paginated = paginated,
        };
    }
};

fn searchCommentsAssumeLimit(
    self: *Self,
    allocator: Allocator,
    options: SearchCommentsOptions,
) FetchError!Response([]datatypes.Comment) {
    const parsed = try self.fetch(
        SearchCommentsResponse,
        allocator,
        .POST,
        "/search/commentSearch",
        empty_query,
        @as(?SearchCommentsOptionsApi, SearchCommentsOptionsApi.fromLib(options, false)),
    );
    errdefer parsed.deinit();
    return .{
        .arena = parsed.arena,
        .headers = parsed.headers,
        .value = parsed.value.comments,
    };
}

/// Search for timestamp comments in streams matching the given options. This
/// corresponds to the `/search/commentSearch` endpoint.
///
/// - Use `searchCommentsWithTotal` to get the comments with a total.
/// - Use `pageSearchComments` to page through the results without a total.
pub fn searchComments(
    self: *Self,
    allocator: Allocator,
    options: SearchCommentsOptions,
) (FetchError || error{InvalidLimit})!Response([]datatypes.Comment) {
    if (options.limit <= 0 or options.limit > SearchCommentsOptions.max_limit) return error.InvalidLimit;
    return self.searchCommentsAssumeLimit(allocator, options);
}

/// The same as `searchComments`, but includes the total number of comments
/// matching the given options.
///
/// - Use `searchComments` to get the comments without a total.
/// - Use `pageSearchComments` to page through the results without a total.
pub fn searchCommentsWithTotal(
    self: *Self,
    allocator: Allocator,
    options: SearchCommentsOptions,
) (FetchError || error{InvalidLimit})!Response(WithTotal([]datatypes.Comment)) {
    if (options.limit <= 0 or options.limit > 100_000) return error.InvalidLimit;

    const parsed = try self.fetch(
        WithTotal(SearchCommentsResponse),
        allocator,
        .POST,
        "/search/commentSearch",
        empty_query,
        @as(?SearchCommentsOptionsApi, SearchCommentsOptionsApi.fromLib(options, true)),
    );
    errdefer parsed.deinit();
    return .{
        .arena = parsed.arena,
        .headers = parsed.headers,
        .value = .{
            .total = parsed.value.total,
            .items = parsed.value.items.comments,
        },
    };
}

/// Create a pager that iterates over the results of `searchComments`.
/// `deinit` must be called on the returned pager to free the memory used by it.
///
/// - Use `searchComments` to get the comments without a total.
/// - Use `searchCommentsWithTotal` to get the comments with a total.
pub fn pageSearchComments(
    self: *Self,
    allocator: Allocator,
    options: SearchCommentsOptions,
) error{InvalidLimit}!Pager(datatypes.Comment, SearchCommentsOptions, searchCommentsAssumeLimit) {
    if (options.limit <= 0 or options.limit > SearchCommentsOptions.max_limit) return error.InvalidLimit;
    return Pager(datatypes.Comment, SearchCommentsOptions, searchCommentsAssumeLimit){
        .allocator = allocator,
        .api = self,
        .options = options,
    };
}
