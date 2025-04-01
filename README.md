# zig-holodex

Zig library for the [Holodex](https://holodex.net/) API, with pretty formatting.

Note that as the [official documentation](https://docs.holodex.net/) is outdated,
any documentation here about API endpoints, their parameters, and their responses
are guesswork from querying the API. This library is not affiliated with Holodex.

[Holodex API License](https://docs.holodex.net/#section/LICENSE)

## Installation

Run the following command to add the package to your `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/TemariVirus/zig-holodex#GIT_COMMIT_HASH_OR_TAG
```

Then, reference the package and import it into your module of choice in your `build.zig`:

```zig
const holodex = b.dependency("holodex", .{
    .target = target,
    .optimize = optimize,
});
your_module.addImport("holodex", holodex.module("holodex"));
```

## Examples

### POST /search/commentSearch

```zig
const std = @import("std");
const holodex = @import("holodex");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit();

    var api = holodex.Api.init(.{
        .allocator = allocator,
        .api_key = "YOUR-API-KEY-HERE",
    }) catch unreachable;
    defer api.deinit();

    const comments = try api.searchComments(allocator, .{
        .comment = "if...",
        .channels = &.{
            "UCvaTdHTWBGv3MKj3KVqJVCw", // Okayu
            "UChAnqc_AY5_I3Px5dig3X1Q", // Korone
        },
        .topics = &.{"singing"},
    });
    defer comments.deinit();

    std.debug.print("value: {pretty}\n", .{comments.value});
    std.debug.print("headers: {}\n", .{comments.headers});
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

    var api = holodex.Api.init(.{
        .allocator = allocator,
        .api_key = "YOUR-API-KEY-HERE",
    }) catch unreachable;
    defer api.deinit();

    var pager = api.pageChannels(allocator, .{
        .limit = 10,
        .offset = 0,
        .org = holodex.datatypes.Organizations.hololive,
        .sort = .clip_count,
        .order = .desc,
    }) catch unreachable;
    defer pager.deinit();

    var i: usize = 0;
    while (try pager.next()) |channel| {
        std.debug.print("{s}'s clip count: {}\n", .{
            channel.english_name orelse channel.name,
            channel.stats.clip_count,
        });
        i += 1;
        if (i >= 20) {
            break;
        }
    }
    std.debug.print("Latest headers: {}\n", .{pager.lastResponseHeaders().?});
}
```
