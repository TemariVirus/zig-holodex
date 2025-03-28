const std = @import("std");
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

    pub fn format(self: VideoOffset, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        if (std.mem.eql(u8, fmt, "raw")) {
            try writer.print("{d}", .{self.seconds()});
            return;
        }

        // Use YouTube format: DDD:HH:MM:SS
        const d = self.seconds() / (24 * 60 * 60);
        const h = (self.seconds() / (60 * 60)) % 24;
        const m = (self.seconds() / 60) % 60;
        const s = self.seconds() % 60;

        // Worst case: "XXXXX:XX:XX:XX"
        var buf: [14]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const buf_writer = fbs.writer();
        if (d > 0) {
            buf_writer.print("{d}:{d:0>2}:{d:0>2}:{d:0>2}", .{ d, h, m, s }) catch unreachable;
        } else if (h > 0) {
            buf_writer.print("{d}:{d:0>2}:{d:0>2}", .{ h, m, s }) catch unreachable;
        } else {
            buf_writer.print("{d}:{d:0>2}", .{ m, s }) catch unreachable;
        }

        try std.fmt.formatBuf(fbs.getWritten(), options, writer);
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

    pub fn format(self: Duration, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        if (std.mem.eql(u8, fmt, "raw")) {
            try writer.print("{d}", .{self.seconds()});
            return;
        }

        if (self.seconds() == 0) {
            // Using `std.fmt.fmtDuration` will print `0ns` instead
            try std.fmt.formatBuf("0s", options, writer);
        } else {
            try std.fmt.fmtDuration(@as(u64, self.seconds()) * std.time.ns_per_s).format(fmt, options, writer);
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
        allocator: std.mem.Allocator,
        source: anytype,
        _: std.json.ParseOptions,
    ) std.json.ParseError(@TypeOf(source.*))!Timestamp {
        // Worst case: "-XXXXXXXXXXXX-XX-XXTXX:XX:XXZ"
        var buf: [29]u8 = undefined;
        var list: std.ArrayList(u8) = .{
            .items = buf[0..0],
            .capacity = buf.len,
            .allocator = allocator,
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

    pub fn format(self: Timestamp, comptime _: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        // Worst case: "-XXXXXXXXXXXX-XX-XXTXX:XX:XXZ"
        var buf: [29]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const buf_writer = fbs.writer();

        self.toInstant().time().strftime(buf_writer, "%Y-%m-%dT%H:%M:%SZ") catch |err| switch (err) {
            error.InvalidFormat,
            error.Overflow,
            error.UnsupportedSpecifier,
            error.UnknownSpecifier,
            => unreachable,
            else => return err,
        };

        try std.fmt.formatBuf(fbs.getWritten(), options, writer);
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

/// English name of a channel.
pub const EnglishName = []const u8;
pub const EnglishNames = struct {
    // Hololive miscellanous
    pub const Yagoo: EnglishName = "YAGOO";
    pub const Hololive: EnglishName = "hololive VTuber Group";
    pub const Holostars: EnglishName = "HOLOSTARS Official";
    pub const Holizontal: EnglishName = "HLZNTL";

    // Hololive JP gen 0
    pub const Tokino_Sora: EnglishName = "Tokino Sora";
    pub const Ankimo: EnglishName = "Ankimo";
    pub const Roboco: EnglishName = "Robocosan";
    pub const AZKi: EnglishName = "AZKi";
    pub const Sakura_Miko: EnglishName = "Sakura Miko";
    pub const Hoshimachi_Suisei: EnglishName = "Hoshimachi Suisei";
    pub const Midnight_Grand_Orchestra: EnglishName = "Midnight Grand Orchestra";

    // Hololive JP gen 1
    pub const Yozora_Mel: EnglishName = "Yozora Mel";
    pub const Shirakami_Fubuki: EnglishName = "Shirakami Fubuki";
    pub const Natsuiro_Matsuri: EnglishName = "Natsuiro Matsuri";
    pub const Aki_Rosenthal: EnglishName = "Aki Rosenthal";
    pub const Aki_Rosenthal_Sub: EnglishName = "Aki Rosenthal (Sub)";
    pub const Akai_Haato: EnglishName = "Akai Haato";
    pub const Akai_Haato_Sub: EnglishName = "Akai Haato (Sub)";

    // Hololive JP gen 2
    pub const Minato_Aqua: EnglishName = "Minato Aqua";
    pub const Murasaki_Shion: EnglishName = "Murasaki Shion";
    pub const Nakiri_Ayame: EnglishName = "Nakiri Ayame";
    pub const Yuzuki_Choco: EnglishName = "Yuzuki Choco";
    pub const Yuzuki_Choco_Sub: EnglishName = "Choco Sub Channel";
    pub const Oozora_Subaru: EnglishName = "Oozora Subaru";

    // Hololive JP GAMERS (not double counting Fubuki)
    pub const Ookami_Mio: EnglishName = "Ookami Mio";
    pub const Nekomata_Okayu: EnglishName = "Nekomata Okayu";
    pub const Inugami_Korone: EnglishName = "Inugami Korone";

    // Hololive JP gen 3
    pub const Usada_Pekora: EnglishName = "Usada Pekora";
    pub const Uruha_Rushia: EnglishName = "Uruha Rushia";
    pub const Shiranui_Flare: EnglishName = "Shiranui Flare";
    pub const Shirogane_Noel: EnglishName = "Shirogane Noel";
    pub const Houshou_Marine: EnglishName = "Houshou Marine";

    // Hololive JP gen 4
    pub const Amane_Kanata: EnglishName = "Amane Kanata";
    pub const Kiryu_Coco: EnglishName = "Kiryu Coco";
    pub const Tsunomaki_Watame: EnglishName = "Tsunomaki Watame";
    pub const Tokoyami_Towa: EnglishName = "Tokoyami Towa";
    pub const Himemori_Luna: EnglishName = "Himemori Luna";

    // Hololive JP gen 5
    pub const Yukihana_Lamy: EnglishName = "Yukihana Lamy";
    pub const Momosuzu_Nene: EnglishName = "Momosuzu Nene";
    pub const Shishiro_Botan: EnglishName = "Shishiro Botan";
    pub const Mano_Aloe: EnglishName = "Mano Aloe";
    pub const Omaru_Polka: EnglishName = "Omaru Polka";

    // Hololive JP gen 6
    pub const Laplus_Darknesss: EnglishName = "La+ Darknesss";
    pub const Takane_Lui: EnglishName = "Takane Lui";
    pub const Hakui_Koyori: EnglishName = "Hakui Koyori";
    pub const Sakamata_Chloe: EnglishName = "Sakamata Chloe";
    pub const Kazama_Iroha: EnglishName = "Kazama Iroha";

    // Holostars JP gen 1
    pub const Hanasaki_Miyabi: EnglishName = "Hanasaki Miyabi";
    pub const Kagami_Kira: EnglishName = "Kagami Kira";
    pub const Kanade_Izuru: EnglishName = "Kanade Izuru";
    pub const Yakushiji_Suzaku: EnglishName = "Yakushiji Suzaku";
    pub const Arurandeisu: EnglishName = "Arurandeisu";
    pub const Rikka: EnglishName = "Rikka";

    // Holostars JP gen 2
    pub const Astel_Leda: EnglishName = "Astel Leda";
    pub const Kishido_Temma: EnglishName = "Kishido Temma";
    pub const Yukoku_Roberu: EnglishName = "Yukoku Roberu";

    // Holostars JP gen 3
    pub const Tsukishita_Kaoru: EnglishName = "Tsukishita Kaoru";
    pub const Kageyama_Shien: EnglishName = "Kageyama Shien";
    pub const Aragami_Oga: EnglishName = "Aragami Oga";

    // Holostars JP uproar
    pub const Yatogami_Fuma: EnglishName = "Yatogami Fuma";
    pub const Utsugi_Uyu: EnglishName = "Utsugi Uyu";
    pub const Hizaki_Gamma: EnglishName = "Hizaki Gamma";
    pub const Minase_Rio: EnglishName = "Minase Rio";

    // Hololive ID gen 1
    pub const Ayunda_Risu: EnglishName = "Ayunda Risu";
    pub const Moona_Hoshinova: EnglishName = "Moona Hoshinova";
    pub const Airani_Iofifteen: EnglishName = "Airani Iofifteen";

    // Hololive ID gen 2
    pub const Kureiji_Ollie: EnglishName = "Kureiji Ollie";
    pub const Anya_Melfissa: EnglishName = "Anya Melfissa";
    pub const Pavolia_Reine: EnglishName = "Pavolia Reine";

    // Hololive ID gen 3
    pub const Vestia_Zeta: EnglishName = "Vestia Zeta";
    pub const Kaela_Kovalskia: EnglishName = "Kaela Kovalskia";
    pub const Kobo_Kanaeru: EnglishName = "Kobo Kanaeru";

    // Hololive EN Myth
    pub const Mori_Calliope: EnglishName = "Mori Calliope";
    pub const Takanashi_Kiara: EnglishName = "Takanashi Kiara";
    pub const Takanashi_Kiara_Sub: EnglishName = "Takanashi Kiara SubCh.";
    pub const Ninomae_Inanis: EnglishName = "Ninomae Ina'nis";
    pub const Gawr_Gura: EnglishName = "Gawr Gura";
    pub const Watson_Amelia: EnglishName = "Watson Amelia";

    // Hololive EN CouncilRys
    pub const IRyS: EnglishName = "IRyS";
    pub const Tsukumo_Sana: EnglishName = "Tsukumo Sana";
    pub const Ceres_Fauna: EnglishName = "Ceres Fauna";
    pub const Ouro_Kronii: EnglishName = "Ouro Kronii";
    pub const Nanashi_Mumei: EnglishName = "Nanashi Mumei";
    pub const Hakos_Baelz: EnglishName = "Hakos Baelz";

    // Hololive EN Advent
    pub const Shiori_Novella: EnglishName = "Shiori Novella";
    pub const Koseki_Bijou: EnglishName = "Koseki Bijou";
    pub const Nerissa_Ravencroft: EnglishName = "Nerissa Ravencroft";
    pub const FuwaMoco: EnglishName = "Fuwawa & Mococo Abyssgard";

    // Hololive EN Justice
    pub const Elizabeth_Rose_Bloodflame: EnglishName = "Elizabeth Rose Bloodflame";
    pub const Gigi_Murin: EnglishName = "Gigi Murin";
    pub const Cecilia_Immergreen: EnglishName = "Cecilia Immergreen";
    pub const Raora_Panthera: EnglishName = "Raora Panthera";

    // Holostars EN Tempus HQ
    pub const Regis_Altare: EnglishName = "Regis Altare";
    pub const Magni_Dezmond: EnglishName = "Magni Dezmond";
    pub const Axel_Syrios: EnglishName = "Axel Syrios";
    pub const Noir_Vesper: EnglishName = "Noir Vesper";

    // Holostars EN Tempus Vanguard
    pub const Gavis_Bettel: EnglishName = "Gavis Bettel";
    pub const Machina_X_Flayon: EnglishName = "Machina X Flayon";
    pub const Banzoin_Hakka: EnglishName = "Banzoin Hakka";
    pub const Josuiji_Shinri: EnglishName = "Josuiji Shinri";

    // Holosta EN Armis
    pub const Jurard_T_Rexford: EnglishName = "Jurard T Rexford";
    pub const Goldbullet: EnglishName = "Goldbullet";
    pub const Octavio: EnglishName = "Octavio";
    pub const Crimzon_Ruze: EnglishName = "Crimzon Ruze";

    // Hololive DEV_IS ReGLOSS
    pub const Hiodoshi_Ao: EnglishName = "Hiodoshi Ao";
    pub const Otonose_Kanade: EnglishName = "Otonose Kanade";
    pub const Ichijou_Ririka: EnglishName = "Ichijou Ririka";
    pub const Juufuutei_Raden: EnglishName = "Juufuutei Raden";
    pub const Todoroki_Hajime: EnglishName = "Todoroki Hajime";

    // Hololive DEV_IS FLOW GLOW
    pub const Isaki_Riona: EnglishName = "Isaki Riona";
    pub const Koganei_Niko: EnglishName = "Koganei Niko";
    pub const Mizumiya_Su: EnglishName = "Mizumiya Su";
    pub const Rindo_Chihaya: EnglishName = "Rindo Chihaya";
    pub const Kikirara_Vivi: EnglishName = "Kikirara Vivi";
};
