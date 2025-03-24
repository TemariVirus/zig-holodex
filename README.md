# zig-holodex

Zig library for the [Holodex](https://holodex.net/) API, with pretty formatting.

Note that as the [official documentation](https://docs.holodex.net/) is outdated,
any documentation here about API endpoints, their parameters, and their responses
are guesswork from querying the API. This library is not affiliated with Holodex.

## Supported Endpoints

- [x] GET /live
- [x] GET /videos
- [x] GET /channels/{channelId}
- [ ] GET /channels/{channelId}/{type}
- [x] GET /users/live
- [x] GET /videos/{videoId}
- [x] GET /channels
- [ ] POST /search/videoSearch
- [x] POST /search/commentSearch

## Examples

### GET /videos/{videoId}

```zig
const std = @import("std");
const holodex = @import("holodex");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    var api = holodex.Api.init(
        allocator,
        .{ .api_key = "YOUR-API-KEY-HERE" },
    ) catch unreachable;
    defer api.deinit();

    const info = try api.videoInfo(allocator, .{
        .comments = false,
        .video_id = "lusGw2tPWpQ",
    }, .{});
    defer info.deinit();

    std.debug.print("{pretty}\n", .{info.value});
}
```

### GET /channels

```zig
const std = @import("std");
const holodex = @import("holodex");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    var api = holodex.Api.init(
        allocator,
        .{ .api_key = "YOUR-API-KEY-HERE" },
    ) catch unreachable;
    defer api.deinit();

    var pager = api.pageChannels(allocator, .{
        .limit = 10,
        .offset = 0,
        .org = holodex.datatypes.Organizations.hololive,
        .sort = .clip_count,
        .order = .desc,
    }, .{});
    defer pager.deinit();

    var i: usize = 0;
    while (try pager.next()) |channel| {
        if (i >= 20) {
            break;
        }

        std.debug.print("{s}'s clip count: {}\n", .{
            channel.english_name orelse channel.name,
            channel.clip_count orelse 0,
        });
        i += 1;
    }
}
```
