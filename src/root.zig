const std = @import("std");
const zeit = @import("zeit");

pub const Api = @import("Api.zig");
pub const types = @import("types.zig");

pub const Pager = @import("Pager.zig").Pager;

pub const PercentEncoder = @import("url.zig").PercentEncoder;
pub const percentEncode = @import("url.zig").percentEncode;
pub const QueryFormatter = @import("QueryFormatter.zig").QueryFormatter;
pub const formatQuery = @import("QueryFormatter.zig").formatQuery;

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
    pub const misc: Group = "Misc";
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

pub const DeepCopyError = error{InvalidTimestamp} || std.mem.Allocator.Error;

/// Parse a timestamp in ISO 8601 format, in the utc+0 timezone.
pub fn parseTimestamp(timestamp: ?[]const u8) error{InvalidTimestamp}!?zeit.Instant {
    return if (timestamp) |tp|
        zeit.instant(.{ .source = .{ .iso8601 = tp } }) catch return error.InvalidTimestamp
    else
        null;
}

/// This function leaks memory when returning an error. Use an arena allocator
/// to free memory properly.
pub fn deepCopy(allocator: std.mem.Allocator, src: anytype) std.mem.Allocator.Error!@TypeOf(src) {
    return switch (@typeInfo(@TypeOf(src))) {
        .Bool, .Int, .Float, .Array, .Enum, .Vector => src,
        .Optional => if (src) |x| try deepCopy(allocator, x) else null,
        .Pointer => |info| switch (info.size) {
            .One => {
                const ptr = try allocator.create(info.child);
                ptr.* = try deepCopy(allocator, src.*);
                return ptr;
            },
            .Slice => {
                const slice = try allocator.alloc(info.child, src.len);
                for (src, 0..) |x, i| {
                    slice[i] = try deepCopy(allocator, x);
                }
                return slice;
            },
            else => @compileError("Unsupported pointer type"),
        },
        else => @compileError("Unsupported type"),
    };
}

test {
    std.testing.refAllDecls(@This());
}
