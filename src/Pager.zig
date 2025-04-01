const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const testing = std.testing;

const Api = @import("root.zig").Api;
const datatypes = @import("root.zig").datatypes;

/// A pager that iterates over the results of an endpoint.
/// `Options` must be a struct that contains:
///   - an `offset` field of an integer type.
///   - a `limit` field of an integer type, that has a value greater than 0.
///
/// `deinit` must be called to free the memory used by the pager.
pub fn Pager(
    comptime T: type,
    comptime Options: type,
    comptime apiFn: fn (*Api, Allocator, Options) Api.FetchError!Api.Response([]T),
) type {
    return struct {
        allocator: Allocator,
        api: *Api,
        options: Options,
        responses: ?Api.Response([]T) = null,
        responses_index: usize = 0,

        pub fn deinit(self: *@This()) void {
            if (self.responses) |responses| {
                responses.deinit();
            }
        }

        /// Return the headers of the last response, or `null` if there was no
        /// last response. The returned value is guaranteed to be non-null if
        /// `next` was called at least once.
        pub fn lastResponseHeaders(self: @This()) ?datatypes.ResponseHeaders {
            if (self.responses) |res| {
                return res.headers;
            }
            return null;
        }

        /// Return the index of the current item, starting from 0.
        pub fn currentIndex(self: @This()) usize {
            const page_len = if (self.responses) |res| res.value.len else 0;
            return self.options.offset - page_len + self.responses_index -| 1;
        }

        /// Return the current page number, starting from 0. Assumes that
        /// `options.limit` has not changed after initialization.
        pub fn currentPage(self: @This()) usize {
            return @divExact(self.options.offset, self.options.limit) -| 1;
        }

        /// Return the next result, or `null` if there are no more results.
        /// The caller does not own the memory of the returned value.
        /// `deinit` must be called to free the memory used by the pager.
        pub fn next(self: *@This()) Api.FetchError!?T {
            try self.tryNextPage();
            if (self.responses.?.value.len == 0) {
                return null;
            }

            defer self.responses_index += 1;
            return self.responses.?.value[self.responses_index];
        }

        /// If at the end of the current page and there are more pages, fetch
        /// the next page. Otherwise, do nothing.
        fn tryNextPage(self: *@This()) Api.FetchError!void {
            // Return if we're not at the end of the current page or there are
            // no more pages.
            if (self.responses) |*responses| {
                if (self.responses_index < responses.value.len) {
                    return;
                }
                // This is the end of the last page
                if (responses.value.len < self.options.limit) {
                    responses.value = &.{};
                    return;
                }
            }

            const new_responses = try apiFn(
                self.api,
                self.allocator,
                self.options,
            );
            if (self.responses) |responses| {
                responses.deinit();
            }
            self.responses = new_responses;
            self.responses_index = 0;
            self.options.offset += @intCast(new_responses.value.len);
        }
    };
}

test Pager {
    const T = u32;
    const Options = struct {
        mul: T,
        offset: T,
    };
    // Mock api endpoint that returns the multiples of `mul`, 2 at a time, up
    // to `MAX`.
    const apiFn = (struct {
        const MAX = 14; // Inclusive

        pub fn apiFn(_: *Api, allocator: Allocator, options: Options) !Api.Response([]T) {
            const arena = try allocator.create(std.heap.ArenaAllocator);
            arena.* = std.heap.ArenaAllocator.init(testing.allocator);

            const value = try arena.allocator().alloc(T, 2);
            for (0..value.len) |i| {
                value[i] = (options.offset + @as(T, @intCast(i))) * options.mul;
            }

            return .{
                .arena = arena,
                .headers = undefined,
                .value = value[0..@min(value.len, (MAX / options.mul) + 1 - options.offset)],
            };
        }
    }).apiFn;

    var api = Api.init(testing.allocator, .{ .api_key = "Bae's key" }) catch unreachable;
    defer api.deinit();
    var pager = Pager(T, Options, apiFn){
        .allocator = testing.allocator,
        .api = &api,
        .options = Options{ .mul = 2, .offset = 3 },
    };
    defer pager.deinit();

    var responses = std.ArrayList(T).init(testing.allocator);
    defer responses.deinit();
    while (try pager.next()) |response| {
        try responses.append(response);
    }

    try testing.expectEqualSlices(T, &.{ 6, 8, 10, 12, 14 }, responses.items);
}
