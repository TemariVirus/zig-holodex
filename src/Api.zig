const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const http = std.http;
const json = std.json;
const meta = std.meta;

const holodex = @import("root.zig");
const Channel = holodex.types.Channel;
const ChannelType = Channel.ChannelType;
const Pager = holodex.Pager;

/// The API key to use for requests.
api_key: []const u8,
/// The base URL of the API. Must end with a slash.
base_url: []const u8,
/// The HTTP client to use for requests.
client: http.Client,

const Self = @This();

pub const ApiError = error{
    FailedToFetchApiResponse,
};

pub const SortOrder = enum {
    asc,
    desc,
};

pub const InitOptions = struct {
    /// The API key to use for requests.
    api_key: []const u8,
    /// The base URL of the API. Must not end with a slash.
    base_url: []const u8 = "https://holodex.net/api/v2",
};
pub fn init(allocator: Allocator, options: InitOptions) Self {
    return Self{
        .api_key = options.api_key,
        .base_url = options.base_url,
        .client = http.Client{ .allocator = allocator },
    };
}

pub fn deinit(self: *Self) void {
    self.client.deinit();
}

/// Perform a one-shot request to the API.
pub fn fetch(
    self: *Self,
    method: http.Method,
    url: []const u8,
    payload: ?[]const u8,
    response_buffer: ?*std.ArrayList(u8),
) !http.Status {
    return (try self.client.fetch(.{
        .response_storage = if (response_buffer) |buf| .{ .dynamic = buf } else .ignore,

        .location = .{ .url = url },
        .method = method,
        .payload = payload,

        .extra_headers = &.{.{
            .name = "X-APIKEY",
            .value = self.api_key,
        }},
    })).status;
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
pub fn listChannels(self: *Self, allocator: Allocator, options: ListChannelsOptions) !json.Parsed([]Channel) {
    assert(options.limit <= 50);

    const url = try std.fmt.allocPrint(
        allocator,
        "{s}/channels{}",
        .{ self.base_url, holodex.formatQuery(&options) },
    );
    defer allocator.free(url);

    var res_buffer = std.ArrayList(u8).init(allocator);
    defer res_buffer.deinit();

    const status = try self.fetch(.GET, url, null, &res_buffer);
    if (status != .ok) {
        return ApiError.FailedToFetchApiResponse;
    }

    return try json.parseFromSlice(
        []Channel,
        allocator,
        res_buffer.items,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    );
}
