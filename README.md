# zig-holodex

Zig library for the [Holodex](https://holodex.net/) API, with pretty formatting.

Note that as the [official documentation](https://docs.holodex.net/) is outdated,
any documentation here about API endpoints, their parameters, and their responses
are guesswork from querying the API. This library is not affiliated with Holodex.

[Holodex API License](https://docs.holodex.net/#section/LICENSE)

## Installation

Run the following command to add the package to your `build.zig.zon`:

```sh
zig fetch --save git+https://codeberg.org/TemariVirus/zig-holodex#GIT_COMMIT_HASH_OR_TAG
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

You can find your holodex API key at <https://holodex.net/login>.

### POST /search/commentSearch

```zig
const std = @import("std");
const holodex = @import("holodex");

pub fn main(init: std.process.Init) !void {
    var api = holodex.Api.init(.{
        .io = init.io,
        .allocator = init.gpa,
        .api_key = "YOUR-API-KEY-HERE",
    }) catch unreachable;
    defer api.deinit();

    const comments = try api.searchComments(init.gpa, .{
        .comment = "if...",
        .channels = &.{
            "UCvaTdHTWBGv3MKj3KVqJVCw", // Okayu
            "UChAnqc_AY5_I3Px5dig3X1Q", // Korone
        },
        .topics = &.{"singing"},
    });
    defer comments.deinit();
    // Alternatively, use 0.16.0's Io interface to not block
    // var task = api.async(.searchComments, init.gpa, .{
    //     .comment = "if...",
    //     .channels = &.{
    //         "UCvaTdHTWBGv3MKj3KVqJVCw",
    //         "UChAnqc_AY5_I3Px5dig3X1Q",
    //     },
    //     .topics = &.{"singing"},
    // });
    // defer if (task.cancel(init.io)) |res| res.deinit() else |_| {};
    // (do something else while waiting...)
    // const comments = try task.await(init.io);

    std.debug.print("value: {f}\n", .{holodex.pretty(comments.value)});
    std.debug.print("headers: {f}\n", .{comments.headers});
}
```

### GET /channels

```zig
const std = @import("std");
const holodex = @import("holodex");

pub fn main(init: std.process.Init) !void {
    var api = holodex.Api.init(.{
        .io = init.io,
        .allocator = init.gpa,
        .api_key = "YOUR-API-KEY-HERE",
    }) catch unreachable;
    defer api.deinit();

    var pager = api.pageChannels(init.gpa, .{
        .limit = 10,
        .offset = 0,
        .org = holodex.datatypes.Organizations.hololive,
        .sort = .clip_count,
        .order = .desc,
    }) catch unreachable;
    defer pager.deinit();

    var i: usize = 0;
    // Do not call `pager.next` with `std.Io.async` directly as it is not thread-safe
    while (try pager.next()) |channel| {
        std.debug.print("{s}'s clip count: {d}\n", .{
            channel.english_name orelse channel.name,
            channel.stats.clip_count,
        });
        i += 1;
        if (i >= 20) {
            break;
        }
    }
    std.debug.print("Latest headers: {f}\n", .{pager.lastResponseHeaders().?});
}
```
