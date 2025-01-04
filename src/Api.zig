const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fmt = std.fmt;
const http = std.http;
const json = std.json;
const meta = std.meta;
const Uri = std.Uri;

const holodex = @import("root.zig");
const Channel = holodex.types.Channel;
const ChannelType = Channel.ChannelType;
const Pager = holodex.Pager;

/// The API key to use for requests.
api_key: []const u8,
/// The base URI of the API.
base_uri: Uri,
/// The HTTP client to use for requests.
client: http.Client,

const Self = @This();

pub const FetchError = error{
    /// The API key used is invalid or expired.
    BadApiKey,
    /// The requested resource was not found. This likely indicates that the
    /// API has been updated and a newer version of this library should be used.
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
} || http.Client.ConnectTcpError;

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

/// Perform a one-shot request to the URL.
/// Returns an error if the response status is not 200 OK.
pub fn fetch(
    self: *Self,
    comptime Response: type,
    allocator: Allocator,
    method: http.Method,
    path: []const u8,
    query: anytype,
    payload: anytype,
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
        .max_append_size = std.math.maxInt(usize), // No limit, `OutOfMemory` will be returned if we run out of memory

        .location = .{ .uri = uri },
        .method = method,
        .payload = payload,

        .extra_headers = &.{.{
            .name = "X-APIKEY",
            .value = self.api_key,
        }},
    }) catch |err| switch (err) {
        // The arguments passed into `fetch` means that no code paths lead to these errors
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
        error.StreamTooLong, // `max_append_size` is set to `std.math.maxInt(usize)`
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
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    ) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidJsonResponse,
    };
}

/// Return a pager that iterates over the results of a query.
/// `deinit` must be called to free the memory used by the pager.
pub fn pager(
    self: *Self,
    comptime Response: type,
    allocator: Allocator,
    apiFn: anytype,
    query: switch (@typeInfo(@TypeOf(apiFn))) {
        .Fn => |info| info.params[2].type.?,
        .Pointer => |info| @typeInfo(info.child).Fn.params[2].type.?,
        else => @compileError("`apiFn` must be a function or a function pointer."),
    },
) Pager(Response, @TypeOf(query)) {
    return Pager(Response, @TypeOf(query)){
        .allocator = allocator,
        .api = self,
        .apiFn = switch (@typeInfo(@TypeOf(apiFn))) {
            .Fn => &apiFn,
            .Pointer => apiFn,
            else => @compileError("`apiFn` must be a function or a function pointer."),
        },
        .query = query,
    };
}

pub const ListChannelsOptions = struct {
    /// Filter by type of channel. Leave null to query all.
    type: ?ChannelType = null,
    /// Offset to start at.
    offset: u64 = 0,
    /// Maximum number of channels to return. Must be less than or equal to 50.
    limit: usize = 25,
    /// If not null, filter VTubers belonging to this organization.
    org: ?holodex.Organization = null,
    /// Filter by any of the included languages. Leave null to query all.
    lang: ?[]holodex.Language = null,
    /// Column to sort on.
    sort: meta.FieldEnum(Channel) = .org,
    /// Sort order.
    order: SortOrder = .asc,
};
pub fn listChannels(
    self: *Self,
    allocator: Allocator,
    options: ListChannelsOptions,
) FetchError!json.Parsed([]Channel) {
    assert(options.limit <= 50);
    return try self.fetch(
        []Channel,
        allocator,
        .GET,
        "/channels",
        options,
        null,
    );
}
