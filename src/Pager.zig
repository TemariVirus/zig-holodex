const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const testing = std.testing;

const Api = @import("root.zig").Api;

/// A pager that iterates over the results of a query.
/// `Query` must be a struct that contains an `offset` field of an integer type.
/// `deinit` must be called to free the memory used by the pager.
pub fn Pager(comptime Response: type, comptime Query: type) type {
    return struct {
        allocator: Allocator,
        api: *Api,
        apiFn: *const fn (*Api, Allocator, Query) anyerror!json.Parsed([]Response),
        query: Query,
        responses: ?json.Parsed([]Response) = null,
        responses_index: usize = 0,

        pub fn deinit(self: *@This()) void {
            if (self.responses) |responses| {
                responses.deinit();
            }
        }

        /// Return the next result, or `null` if there are no more results.
        /// The caller does not own the memory of the returned value.
        /// `deinit` must be called to free the memory used by the pager.
        pub fn next(self: *@This()) !?Response {
            try self.tryNextPage();
            if (self.responses.?.value.len == 0) {
                return null;
            }

            defer self.responses_index += 1;
            return self.responses.?.value[self.responses_index];
        }

        /// If at the end of the current page, fetch the next page.
        /// Otherwise, do nothing.
        fn tryNextPage(self: *@This()) !void {
            // Return if we're not at the end of the current page.
            if (self.responses) |responses| {
                if (self.responses_index < responses.value.len) {
                    return;
                }
            }

            const new_responses = try self.apiFn(self.api, self.allocator, self.query);
            if (self.responses) |responses| {
                responses.deinit();
            }
            self.responses = new_responses;
            self.responses_index = 0;
            self.query.offset += @intCast(new_responses.value.len);
        }
    };
}

test Pager {
    const T = u32;
    const Query = struct {
        mul: T,
        offset: T,
    };
    // Mock api endpoint that returns the multiples of `mul`, 2 at a time, up
    // to `MAX`.
    const apiFn = (struct {
        const MAX = 14; // Inclusive

        pub fn apiFn(_: *Api, allocator: Allocator, query: Query) !json.Parsed([]T) {
            const arena = try allocator.create(std.heap.ArenaAllocator);
            arena.* = std.heap.ArenaAllocator.init(testing.allocator);

            const value = try arena.allocator().alloc(T, 2);
            for (0..value.len) |i| {
                value[i] = (query.offset + @as(T, @intCast(i))) * query.mul;
            }

            return json.Parsed([]T){
                .arena = arena,
                .value = value[0..@min(value.len, (MAX / query.mul) + 1 - query.offset)],
            };
        }
    }).apiFn;

    var api = Api.init(testing.allocator, .{ .api_key = "Bae's key" });
    defer api.deinit();
    var pager = Pager(T, Query){
        .allocator = testing.allocator,
        .api = &api,
        .apiFn = apiFn,
        .query = Query{ .mul = 2, .offset = 3 },
    };
    defer pager.deinit();

    var responses = std.ArrayList(T).init(testing.allocator);
    defer responses.deinit();
    while (try pager.next()) |response| {
        try responses.append(response);
    }

    try testing.expectEqualSlices(T, &.{ 6, 8, 10, 12, 14 }, responses.items);
}