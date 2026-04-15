const std = @import("std");
const Writer = std.Io.Writer;

const zeit = @import("zeit");

pub const Channel = @import("datatypes/Channel.zig");
pub const ChannelFull = @import("datatypes/ChannelFull.zig");
pub const Comment = @import("datatypes/Comment.zig");
pub const ResponseHeaders = @import("datatypes/ResponseHeaders.zig");
pub const SearchedVideo = @import("datatypes/SearchedVideo.zig");
pub const Song = @import("datatypes/Song.zig");
pub const Uuid = @import("datatypes/Uuid.zig");
pub const Video = @import("datatypes/Video.zig");
pub const VideoFull = @import("datatypes/VideoFull.zig");
pub const VideoMin = @import("datatypes/VideoMin.zig");
pub const Vtuber = @import("datatypes/Vtuber.zig");

/// A language code.
pub const Language = []const u8;
pub const Languages = struct {
    pub const all: Language = "all";
    pub const chinese: Language = "zh";
    pub const english: Language = "en";
    pub const indonesian: Language = "id";
    pub const japanese: Language = "ja";
    pub const korean: Language = "ko";
    pub const russian: Language = "ru";
    pub const spanish: Language = "es";
};

/// An offset from the start of a video, in seconds.
pub const VideoOffset = enum(u32) {
    _,

    pub fn seconds(self: VideoOffset) u32 {
        return @intFromEnum(self);
    }

    pub fn fromSeconds(s: u32) VideoOffset {
        return @enumFromInt(s);
    }

    pub fn format(self: VideoOffset, writer: *Writer) Writer.Error!void {
        // Use YouTube format: DDD:HH:MM:SS
        const d = self.seconds() / (24 * 60 * 60);
        const h = (self.seconds() / (60 * 60)) % 24;
        const m = (self.seconds() / 60) % 60;
        const s = self.seconds() % 60;

        if (d > 0) {
            try writer.print("{d}:{d:0>2}:{d:0>2}:{d:0>2}", .{ d, h, m, s });
        } else if (h > 0) {
            try writer.print("{d}:{d:0>2}:{d:0>2}", .{ h, m, s });
        } else {
            try writer.print("{d}:{d:0>2}", .{ m, s });
        }
    }
};

/// A duration of time, in seconds.
pub const Duration = enum(u32) {
    _,

    pub fn seconds(self: Duration) u32 {
        return @intFromEnum(self);
    }

    pub fn fromSeconds(s: u32) Duration {
        return @enumFromInt(s);
    }

    pub fn format(self: Duration, writer: *Writer) Writer.Error!void {
        if (self.seconds() == 0) {
            // Using `writer.printDuration` will print `0ns` instead
            try writer.writeAll("0s");
        } else {
            try writer.printDuration(@as(u64, self.seconds()) * std.time.ns_per_s, .{});
        }
    }

    pub fn add(self: Duration, other: Duration) Duration {
        return Duration.fromSeconds(self.seconds() + other.seconds());
    }

    pub fn sub(self: Duration, other: Duration) Duration {
        return Duration.fromSeconds(self.seconds() - other.seconds());
    }
};

/// A UNIX timestamp.
/// The number of seconds since the UNIX epoch (midnight UTC, January 1, 1970).
pub const Timestamp = enum(i64) {
    _,

    pub const ParseError = error{InvalidTimestamp};

    pub fn seconds(self: Timestamp) i64 {
        return @intFromEnum(self);
    }

    pub fn fromSeconds(s: i64) Timestamp {
        return @enumFromInt(s);
    }

    pub fn toInstant(self: Timestamp) zeit.Instant {
        return zeit.instant(.{
            .source = .{ .unix_timestamp = self.seconds() },
            .timezone = &zeit.utc,
        }) catch unreachable;
    }

    pub fn fromInstant(instant: zeit.Instant) Timestamp {
        return @enumFromInt(instant.unixTimestamp());
    }

    /// Parse a timestamp in the ISO 8601 format
    pub fn parseISO(iso8601: []const u8) ParseError!Timestamp {
        const instant = zeit.instant(.{
            .source = .{ .iso8601 = iso8601 },
        }) catch return ParseError.InvalidTimestamp;
        return fromInstant(instant);
    }

    pub fn jsonParse(
        _: std.mem.Allocator,
        source: anytype,
        _: std.json.ParseOptions,
    ) std.json.ParseError(@TypeOf(source.*))!Timestamp {
        // Worst case: "-XXXXXXXXXXXX-XX-XXTXX:XX:XXZ"
        var buf: [29]u8 = undefined;
        var list: std.array_list.Managed(u8) = .{
            .items = buf[0..0],
            .capacity = buf.len,
            .allocator = undefined,
        };

        const str = try source.allocNextIntoArrayListMax(
            &list,
            .alloc_if_needed,
            buf.len,
        ) orelse list.items;
        return parseISO(str) catch |err| switch (err) {
            ParseError.InvalidTimestamp => return error.InvalidEnumTag,
        };
    }

    pub fn format(self: Timestamp, writer: *Writer) Writer.Error!void {
        self.toInstant().time().strftime(writer, "%Y-%m-%dT%H:%M:%SZ") catch |err| switch (err) {
            error.InvalidFormat,
            error.NoSpaceLeft,
            error.Overflow,
            error.UnsupportedSpecifier,
            error.UnknownSpecifier,
            => unreachable,
            error.WriteFailed => return error.WriteFailed,
        };
    }

    pub fn add(self: Timestamp, duration: Duration) Timestamp {
        return Timestamp.fromSeconds(self.seconds() + @as(i64, duration.seconds()));
    }

    pub fn sub(self: Timestamp, duration: Duration) Timestamp {
        return Timestamp.fromSeconds(self.seconds() - @as(i64, duration.seconds()));
    }
};

/// A topic tag.
pub const Topic = []const u8;

/// An agency or entire category of VTubers. E.g., Hololive, Nijisanji, indies, etc.
pub const Organization = []const u8;
pub const Organizations = struct {
    pub const hololive: Organization = "Hololive";
    pub const indies: Organization = "Independents";
    pub const nijisanji: Organization = "Nijisanji";
};

/// Subgroup of VTubers. Smaller than an organization.
pub const Group = []const u8;
pub const Groups = struct {
    pub const official: Group = "Official";
    pub const miscellanous: Group = "Misc";
    pub const holo_n: Group = "holo-n";

    pub const hololive_jp_gen_0: Group = "0th Generation";
    pub const hololive_jp_gen_1: Group = "1st Generation";
    pub const hololive_jp_gen_2: Group = "2nd Generation";
    pub const hololive_jp_gamers: Group = "GAMERS";
    pub const hololive_jp_gen_3: Group = "3rd Generation (Fantasy)";
    pub const hololive_jp_gen_4: Group = "4th Generation (holoForce)";
    pub const hololive_jp_gen_5: Group = "5th Generation (holoFive)";
    pub const hololive_jp_gen_6: Group = "6th Generation -holoX-";

    pub const hololive_id_gen_1: Group = "Indonesia 1st Gen (AREA 15)";
    pub const hololive_id_gen_2: Group = "Indonesia 2nd Gen (holoro)";
    pub const hololive_id_gen_3: Group = "Indonesia 3rd Gen (holoh3ro)";

    pub const hololive_en_myth: Group = "English -Myth-";
    pub const hololive_en_promise: Group = "English -Promise-";
    pub const hololive_en_advent: Group = "English -Advent-";
    pub const hololive_en_justice: Group = "English -Justice-";

    pub const holostars_jp_gen_1: Group = "HOLOSTARS 1st Gen";
    pub const holostars_jp_gen_2: Group = "HOLOSTARS 2nd Gen (SunTempo)";
    pub const holostars_jp_gen_3: Group = "HOLOSTARS 3rd Gen (TriNero)";
    pub const holostars_jp_uproar: Group = "HOLOSTARS UPROAR!!";

    pub const holostars_en_tempus_hq: Group = "HOLOSTARS English -TEMPUS- HQ";
    pub const holostars_en_tempus_vanguard: Group = "HOLOSTARS English -TEMPUS- Vanguard";
    pub const holostars_en_armis: Group = "HOLOSTARS English -ARMIS-";

    pub const hololive_devis_regloss: Group = "DEV_IS ReGLOSS";
    pub const hololive_devis_flow_glow: Group = "DEV_IS FLOW GLOW";
};
