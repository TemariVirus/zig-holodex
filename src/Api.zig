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
    /// The response exceeded the maximum size allowed by
    /// `FetchOptions.max_response_size`.
    ResponseTooLarge,
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

pub const ResponseHeaders = struct {
    // Max number of requests that can be made in a period of time.
    rate_limit: u32,
    // Number of remaining requests before the rate limit is reached.
    rate_limit_remaining: u32,
    // When `rate_limit_remaining` will reset to `rate_limit`.
    rate_limit_reset: datatypes.Timestamp,

    pub const ParseError = fmt.ParseIntError || error{
        DuplicateHeader,
        InvalidHeader,
        MissingHeader,
        Overflow,
    };
    pub fn parse(bytes: []const u8) ParseError!ResponseHeaders {
        const field_map: std.StaticStringMapWithEql(
            meta.FieldEnum(ResponseHeaders),
            std.static_string_map.eqlAsciiIgnoreCase,
        ) = .initComptime(.{
            .{ "X-Ratelimit-Limit", .rate_limit },
            .{ "X-Ratelimit-Remaining", .rate_limit_remaining },
            .{ "X-Ratelimit-Reset", .rate_limit_reset },
        });

        var headers_it: http.HeaderIterator = .init(bytes);
        _ = headers_it.next() orelse return ParseError.InvalidHeader;

        var headers: ResponseHeaders = undefined;
        var fields_seen: [@typeInfo(ResponseHeaders).@"struct".fields.len]bool = @splat(false);
        while (headers_it.next()) |header| {
            const field = field_map.get(header.name) orelse continue;
            if (fields_seen[@intFromEnum(field)]) {
                return ParseError.DuplicateHeader;
            }

            fields_seen[@intFromEnum(field)] = true;
            switch (field) {
                .rate_limit => headers.rate_limit =
                    try parseHeaderInt(u32, header.value),
                .rate_limit_remaining => headers.rate_limit_remaining =
                    try parseHeaderInt(u32, header.value),
                .rate_limit_reset => headers.rate_limit_reset =
                    datatypes.Timestamp.fromSeconds(
                        try parseHeaderInt(i64, header.value),
                    ),
            }
        }

        if (!std.mem.allEqual(bool, &fields_seen, true)) {
            return ParseError.MissingHeader;
        }
        return headers;
    }

    fn parseHeaderInt(comptime T: type, buf: []const u8) ParseError!T {
        return std.fmt.parseInt(T, buf, 10) catch |err| return switch (err) {
            std.fmt.ParseIntError.InvalidCharacter => ParseError.InvalidHeader,
            std.fmt.ParseIntError.Overflow => ParseError.Overflow,
        };
    }
};

pub fn Response(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        headers: ResponseHeaders,
        value: T,

        pub fn deinit(self: @This()) void {
            const allocator = self.arena.child_allocator;
            self.arena.deinit();
            allocator.destroy(self.arena);
        }
    };
}

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
pub fn init(allocator: Allocator, options: InitOptions) InitError!Self {
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
    /// The behavior to use when a duplicate field is encountered in the JSON
    /// response.
    json_duplicate_field_behavior: meta.fieldInfo(json.ParseOptions, .duplicate_field_behavior).type = .@"error",
    /// Whether to ignore unknown fields in the JSON response.
    json_ignore_unknown_fields: bool = true,
};

/// Helper function to fetch data from the API and parse it as JSON.
/// Returns an error if the response status is not 200 OK.
///
/// Only use this when you require the raw JSON.
pub fn fetch(
    self: *Self,
    comptime T: type,
    allocator: Allocator,
    method: http.Method,
    path: []const u8,
    query: anytype,
    payload: anytype,
    options: FetchOptions,
) FetchError!Response(T) {
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
        .{holodex.formatQuery(&query)},
    ) };
    defer allocator.free(uri.query.?.percent_encoded);

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = self.client.open(method, uri, .{
        .server_header_buffer = &server_header_buffer,
        .extra_headers = &.{.{
            .name = "X-APIKEY",
            .value = self.api_key,
        }},
        .keep_alive = true,
    }) catch |err| return httpToFetchError(err);
    defer req.deinit();

    // TODO: Support payload for POST requests
    if (payload) |p| {
        _ = p;
        // req.transfer_encoding = .{ .content_length = p.len };
        @panic("Payloads are not yet supported");
    }
    req.send() catch |err| return httpToFetchError(err);
    if (payload) |p| {
        _ = p;
        // try req.writeAll(p);
    }
    req.finish() catch |err| return httpToFetchError(err);
    req.wait() catch |err| return httpToFetchError(err);

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
        .ignore_unknown_fields = options.json_ignore_unknown_fields,
        .duplicate_field_behavior = options.json_duplicate_field_behavior,
    }) catch |err| switch (err) {
        error.OutOfMemory => return FetchError.OutOfMemory,
        else => return FetchError.InvalidJsonResponse,
    };
    errdefer parsed.deinit();

    return .{
        .arena = parsed.arena,
        .headers = ResponseHeaders.parse(req.response.parser.get()) catch
            return FetchError.UnexpectedFetchFailure,
        .value = parsed.value,
    };
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
        // TODO: Actually re-send instead of returning an error
        http.Client.Request.WaitError.RedirectRequiresResend,
        http.Client.Request.WaitError.TlsAlert,
        http.Client.Request.WaitError.TlsFailure,
        http.Client.Request.WaitError.TooManyHttpRedirects,
        http.Client.Request.WaitError.UnexpectedReadFailure,
        => return FetchError.UnexpectedFetchFailure,
    }
}

fn conversionToFetchError(err: datatypes.JsonConversionError) FetchError {
    return switch (err) {
        datatypes.JsonConversionError.OutOfMemory => return FetchError.OutOfMemory,
        datatypes.JsonConversionError.InvalidTimestamp,
        datatypes.JsonConversionError.InvalidUuid,
        datatypes.JsonConversionError.MissingField,
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
) FetchError!Response(datatypes.ChannelFull) {
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
    arena.* = .init(allocator);
    errdefer arena.deinit();

    const result = parsed.value.to(arena.allocator()) catch |err| return conversionToFetchError(err);
    return .{
        .arena = arena,
        .headers = parsed.headers,
        .value = result,
    };
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
) FetchError!Response(datatypes.VideoFull) {
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
    arena.* = .init(allocator);
    errdefer arena.deinit();

    const result = parsed.value.to(arena.allocator()) catch |err| return conversionToFetchError(err);
    return .{
        .arena = arena,
        .headers = parsed.headers,
        .value = result,
    };
}

/// Query options for `Api.listChannels`.
pub const ListChannelsOptions = struct {
    /// Filter by type of channel. Leave null to query all.
    type: ?datatypes.ChannelFull.Type = null,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be greater than 0, and less
    /// than or equal to 100.
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
) (FetchError || error{InvalidLimit})!Response([]datatypes.Channel) {
    if (options.limit <= 0 or options.limit > 100) return error.InvalidLimit;

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
    arena.* = .init(allocator);
    errdefer arena.deinit();

    const result = try arena.allocator().alloc(datatypes.Channel, parsed.value.len);
    for (parsed.value, 0..) |channel, i| {
        result[i] = channel.to(arena.allocator()) catch |err| return conversionToFetchError(err);
    }
    return .{
        .arena = arena,
        .headers = parsed.headers,
        .value = result,
    };
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
