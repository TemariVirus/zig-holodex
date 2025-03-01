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

/// The API key to use for requests.
api_key: []const u8,
/// The base URI of the API.
base_uri: Uri,
/// The HTTP client to use for requests.
client: http.Client,

const Self = @This();
const empty_query = (struct {}){};

/// Errors that can occur when fetching data from the API.
pub const FetchError = error{
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
    /// The response exceeded the maximum size allowed by
    /// `FetchOptions.max_response_size`.
    ResponseTooLarge,
    /// There was an error loading the TLS certificate bundle.
    TlsCertificateBundleLoadFailure,
    /// There usually isn't anything the user can do about this error, as they
    /// most likely arise from a bad server response or an unsupported feature
    /// in `std.http.Client`.
    UnexpectedFetchFailure,
} || http.Client.ConnectTcpError;

/// The order to sort results in.
pub const SortOrder = enum {
    asc,
    desc,
};

pub const InitOptions = struct {
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
pub fn init(allocator: Allocator, options: InitOptions) (Uri.ParseError || error{UriMissingHost})!Self {
    const base_uri = removeTrailingSlash(switch (options.location) {
        .uri => |uri| uri,
        .url => |url| try Uri.parse(url),
    });
    if (base_uri.host == null) return error.UriMissingHost;

    return Self{
        .api_key = options.api_key,
        .base_uri = base_uri,
        .client = http.Client{ .allocator = allocator },
    };
}

fn removeTrailingSlash(uri: Uri) Uri {
    const path = uri.path.percent_encoded;
    if (path.len == 0) return uri;

    if (path[path.len - 1] == '/') {
        var new_uri = uri;
        new_uri.path.percent_encoded = path[0 .. path.len - 1];
        return new_uri;
    }
    return uri;
}

pub fn deinit(self: *Self) void {
    self.client.deinit();
}

pub const FetchOptions = struct {
    /// The maximum size of the response body in bytes. If the response exceeds
    /// this size, `FetchError.ResponseTooLarge` will be returned.
    max_response_size: usize = 8 * 1024 * 1024, // Most responses are a few KiB, 8 MiB should be enough
    /// The behavior to use when a duplicate field is encountered in the JSON
    /// response.
    json_duplicate_field_behavior: meta.fieldInfo(json.ParseOptions, .duplicate_field_behavior).type = .@"error",
    /// Whether to ignore unknown fields in the JSON response.
    json_ignore_unknown_fields: bool = true,
};

/// Helper function to fetch data from the API and parse it as JSON.
/// Returns an error if the response status is not 200 OK.
///
/// It is recommended to use the more specific methods like `channelInfo`
/// instead of calling this method directly.
pub fn fetch(
    self: *Self,
    comptime Response: type,
    allocator: Allocator,
    method: http.Method,
    path: []const u8,
    query: anytype,
    payload: anytype,
    options: FetchOptions,
) FetchError!json.Parsed(Response) {
    var uri = self.base_uri;
    uri.path.percent_encoded = try fmt.allocPrint(
        allocator,
        "{s}{s}",
        .{ self.base_uri.path.percent_encoded, path },
    );
    defer allocator.free(uri.path.percent_encoded);
    uri.query = Uri.Component{ .percent_encoded = try fmt.allocPrint(
        allocator,
        "{}",
        .{holodex.formatQuery(&query)},
    ) };
    defer allocator.free(uri.query.?.percent_encoded);

    var res_buffer = std.ArrayList(u8).init(allocator);
    defer res_buffer.deinit();
    const status = (self.client.fetch(.{
        .response_storage = .{ .dynamic = &res_buffer },
        .max_append_size = options.max_response_size,

        .location = .{ .uri = uri },
        .method = method,
        .payload = payload,

        .extra_headers = &.{.{
            .name = "X-APIKEY",
            .value = self.api_key,
        }},
    }) catch |err| switch (err) {
        // The arguments passed into `client.fetch` means that no code paths lead to these errors
        fmt.ParseIntError.Overflow,
        fmt.ParseIntError.InvalidCharacter,
        Uri.ParseError.InvalidFormat,
        Uri.ParseError.InvalidPort,
        Uri.ParseError.UnexpectedCharacter,
        http.Client.RequestError.UnsupportedUriScheme,
        http.Client.RequestError.UriMissingHost,
        http.Client.RequestError.UnsupportedTransferEncoding,
        http.Client.Request.WriteError.NotWriteable,
        http.Client.Request.WriteError.MessageTooLong,
        http.Client.Request.ReadError.InvalidTrailers,
        http.Client.Request.FinishError.MessageNotCompleted,
        http.Client.Response.ParseError.HttpConnectionHeaderUnsupported,
        => unreachable,
        // These errors should be returned
        http.Client.ConnectTcpError.ConnectionRefused,
        http.Client.ConnectTcpError.NetworkUnreachable,
        http.Client.ConnectTcpError.ConnectionTimedOut,
        http.Client.ConnectTcpError.ConnectionResetByPeer,
        http.Client.ConnectTcpError.TemporaryNameServerFailure,
        http.Client.ConnectTcpError.NameServerFailure,
        http.Client.ConnectTcpError.UnknownHostName,
        http.Client.ConnectTcpError.HostLacksNetworkAddresses,
        http.Client.ConnectTcpError.UnexpectedConnectFailure,
        http.Client.ConnectTcpError.TlsInitializationFailed,
        error.OutOfMemory,
        => return @as(FetchError, @errorCast(err)),
        error.StreamTooLong => return FetchError.ResponseTooLarge,
        http.Client.RequestError.CertificateBundleLoadFailure => return FetchError.TlsCertificateBundleLoadFailure,
        // Group other errors into `UnexpectedFetchFailure`. There usually isn't
        // anything the user can do about these errors, as they arise from a
        // bad server response or an unsupported feature in `http.Client`.
        http.Client.Connection.WriteError.UnexpectedWriteFailure,
        http.Client.Connection.ReadError.TlsFailure,
        http.Client.Connection.ReadError.TlsAlert,
        http.Client.Connection.ReadError.UnexpectedReadFailure,
        http.Client.Connection.ReadError.EndOfStream,
        http.Client.Request.WaitError.TooManyHttpRedirects,
        http.Client.Request.WaitError.RedirectRequiresResend,
        http.Client.Request.WaitError.HttpRedirectLocationMissing,
        http.Client.Request.WaitError.HttpRedirectLocationInvalid,
        http.Client.Request.WaitError.CompressionInitializationFailed,
        http.Client.Request.WaitError.HttpHeadersOversize,
        http.Client.Request.ReadError.DecompressionFailure,
        http.Client.Response.ParseError.HttpHeadersInvalid,
        http.Client.Response.ParseError.HttpHeaderContinuationsUnsupported,
        http.Client.Response.ParseError.HttpTransferEncodingUnsupported,
        http.Client.Response.ParseError.InvalidContentLength,
        http.Client.Response.ParseError.CompressionUnsupported,
        http.protocol.HeadersParser.ReadError.HttpChunkInvalid,
        => return FetchError.UnexpectedFetchFailure,
    }).status;
    switch (status) {
        .ok => {},
        .forbidden => return FetchError.BadApiKey,
        .not_found => return FetchError.NotFound,
        .too_many_requests => return FetchError.TooManyRequests,
        else => return FetchError.UnexpectedFetchFailure,
    }

    return json.parseFromSlice(
        Response,
        allocator,
        res_buffer.items,
        .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = options.json_ignore_unknown_fields,
            .duplicate_field_behavior = options.json_duplicate_field_behavior,
        },
    ) catch |err| switch (err) {
        error.OutOfMemory => FetchError.OutOfMemory,
        else => FetchError.InvalidJsonResponse,
    };
}

fn toFetchError(err: datatypes.JsonConversionError) FetchError {
    return switch (err) {
        datatypes.JsonConversionError.OutOfMemory => return FetchError.OutOfMemory,
        datatypes.JsonConversionError.InvalidTimestamp,
        datatypes.JsonConversionError.InvalidUuid,
        => return FetchError.InvalidJsonResponse,
    };
}

/// Fetch information about a YouTube channel. This corresponds to the
/// `/channels/{channelId}` endpoint.
pub fn channelInfo(
    self: *Self,
    allocator: Allocator,
    id: []const u8,
    fetch_options: FetchOptions,
) FetchError!json.Parsed(datatypes.ChannelFull) {
    const path = try fmt.allocPrint(allocator, "/channels/{s}", .{id});
    defer allocator.free(path);
    const parsed = try self.fetch(
        datatypes.ChannelFull.Json,
        allocator,
        .GET,
        path,
        empty_query,
        null,
        fetch_options,
    );
    defer parsed.deinit();

    var arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    const result = parsed.value.to(arena.allocator()) catch |err| return toFetchError(err);
    return .{ .arena = arena, .value = result };
}

/// Query options for `Api.videoInfo`.
pub const VideoInfoOptions = struct {
    /// The YouTube video ID.
    video_id: []const u8,
    /// Filter channels/clips. official streams do not follow this parameter.
    lang: ?[]const datatypes.Language = &.{datatypes.Languages.all},
    /// Whether to include timestamp comments.
    comments: bool = false,
};
/// The Holodex API version of `VideoInfoOptions`.
const VideoInfoOptionsApi = struct {
    /// Corresponds to the `lang` field.
    lang: ?[]const datatypes.Language,
    /// Corresponds to the `comments` field.
    c: enum { @"0", @"1" },

    pub fn from(options: VideoInfoOptions) VideoInfoOptionsApi {
        return VideoInfoOptionsApi{
            .lang = options.lang,
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
    fetch_options: FetchOptions,
) FetchError!json.Parsed(datatypes.VideoFull) {
    const path = try fmt.allocPrint(allocator, "/videos/{s}", .{options.video_id});
    defer allocator.free(path);
    const parsed = try self.fetch(
        datatypes.VideoFull.Json,
        allocator,
        .GET,
        path,
        VideoInfoOptionsApi.from(options),
        null,
        fetch_options,
    );
    defer parsed.deinit();

    var arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    const result = parsed.value.to(arena.allocator()) catch |err| return toFetchError(err);
    return .{ .arena = arena, .value = result };
}

/// Query options for `Api.listChannels`.
pub const ListChannelsOptions = struct {
    /// Filter by type of channel. Leave null to query all.
    type: ?datatypes.ChannelFull.Type = null,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be less than or equal to 50.
    limit: usize = 25,
    /// If not null, filter VTubers belonging to this organization.
    org: ?datatypes.Organization = null,
    /// Filter by any of the included languages. Leave null to query all.
    lang: ?[]const datatypes.Language = null,
    /// Column to sort on.
    sort: meta.FieldEnum(datatypes.Channel) = .org,
    /// Sort order.
    order: SortOrder = .asc,
};

/// List channels that match the given options. This corresponds to the
/// `/channels` endpoint. Use `Api.pageChannels` to page through the results
/// instead.
pub fn listChannels(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
    fetch_options: FetchOptions,
) FetchError!json.Parsed([]datatypes.Channel) {
    assert(options.limit <= 50);

    const parsed = try self.fetch(
        []datatypes.Channel.Json,
        allocator,
        .GET,
        "/channels",
        options,
        null,
        fetch_options,
    );
    defer parsed.deinit();

    var arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    const result = try arena.allocator().alloc(datatypes.Channel, parsed.value.len);
    for (parsed.value, 0..) |channel, i| {
        result[i] = channel.to(arena.allocator()) catch |err| return toFetchError(err);
    }
    return .{ .arena = arena, .value = result };
}

/// Create a pager that iterates over the results of `Api.listChannels`.
/// `deinit` must be called on the returned pager to free the memory used by it.
pub fn pageChannels(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
    fetch_options: FetchOptions,
) Pager(datatypes.Channel, ListChannelsOptions, listChannels) {
    return Pager(datatypes.Channel, ListChannelsOptions, listChannels){
        .allocator = allocator,
        .api = self,
        .query = options,
        .options = fetch_options,
    };
}
