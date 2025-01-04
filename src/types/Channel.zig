const std = @import("std");
const fmt = std.fmt;
const zeit = @import("zeit");
const holodex = @import("../root.zig");

/// YouTube channel id.
id: []const u8,
/// YouTube channel name.
name: []const u8,
/// English name of the channel/channel owner.
english_name: ?EnglishName = null,
/// Type of the channel. Ether a VTuber or a subber.
type: ChannelType,
/// VTuber organization the channel is part of.
org: ?holodex.Organization = null,
/// VTuber subgroup the channel is part of.
group: ?holodex.Group = null,
/// URL to the channel's profile picture.
photo: ?[]const u8 = null,
/// URL to the channel's banner.
banner: ?[]const u8 = null,
/// The channel's Twitter handle. Does not include the initial `@`.
twitter: ?[]const u8 = null,
/// The channel's Twitch handle. Does not include the initial `@`.
twitch: ?[]const u8 = null,
/// Number of videos the channel has uploaded.
video_count: ?u64 = null,
/// Number of subscribers the channel has.
subscriber_count: ?u64 = null,
/// Number of views the channel has.
viewer_count: ?u64 = null,
/// Number of clips of the channel. `0` if the channel is a subber.
clip_count: ?u64 = null,
/// Primary language of the channel.
lang: ?holodex.Language = null,
/// When the channel was created.
published_at: ?zeit.Instant = null,
/// When the channel was added to holodex.
created_at: ?zeit.Instant = null,
/// When the channel was last updated in holodex.
updated_at: ?zeit.Instant = null,
/// Whether the channel is currently active or not.
inactive: bool,
/// Description of the channel.
description: ?[]const u8 = null,
/// The channel's most popular topics.
top_topics: ?[]const Topic = null,
/// The channel's YouTube handles. Includes the initial `@`.
yt_handle: ?[]const []const u8 = null,
/// A list of the channel's names in chronological order.
yt_name_history: ?[]const []const u8 = null,
/// When the channel was last crawled.
crawled_at: ?zeit.Instant = null,
/// When the channel's comments were last crawled.
comments_crawled_at: ?zeit.Instant = null,

const Self = @This();

/// Type of a channel. Either a VTuber or a subber.
pub const ChannelType = enum {
    subber,
    vtuber,
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

pub const Topic = []const u8;

/// The JSON representation of a channel.
pub const Json = struct {
    id: []const u8,
    name: []const u8,
    english_name: ?EnglishName = null,
    type: ChannelType,
    org: ?holodex.Organization = null,
    group: ?holodex.Group = null,
    photo: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    twitter: ?[]const u8 = null,
    twitch: ?[]const u8 = null,
    video_count: ?u64 = null,
    subscriber_count: ?u64 = null,
    viewer_count: ?u64 = null,
    clip_count: ?u64 = null,
    lang: ?holodex.Language = null,
    published_at: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    inactive: bool,
    description: ?[]const u8 = null,
    top_topics: ?[]const Topic = null,
    yt_handle: ?[]const []const u8 = null,
    yt_name_history: ?[]const []const u8 = null,
    crawled_at: ?[]const u8 = null,
    comments_crawled_at: ?[]const u8 = null,

    /// This function leaks memory when returning an error. Use an arena allocator
    /// to free memory properly.
    pub fn to(self: @This(), allocator: std.mem.Allocator) holodex.DeepCopyError!Self {
        return .{
            .id = try holodex.deepCopy(allocator, self.id),
            .name = try holodex.deepCopy(allocator, self.name),
            .english_name = try holodex.deepCopy(allocator, self.english_name),
            .type = self.type,
            .org = try holodex.deepCopy(allocator, self.org),
            .group = try holodex.deepCopy(allocator, self.group),
            .photo = try holodex.deepCopy(allocator, self.photo),
            .banner = try holodex.deepCopy(allocator, self.banner),
            .twitter = try holodex.deepCopy(allocator, self.twitter),
            .twitch = try holodex.deepCopy(allocator, self.twitch),
            .video_count = self.viewer_count,
            .subscriber_count = self.subscriber_count,
            .viewer_count = self.viewer_count,
            .clip_count = self.clip_count,
            .lang = try holodex.deepCopy(allocator, self.lang),
            .published_at = try holodex.parseTimestamp(self.published_at),
            .created_at = try holodex.parseTimestamp(self.created_at),
            .updated_at = try holodex.parseTimestamp(self.updated_at),
            .inactive = self.inactive,
            .description = try holodex.deepCopy(allocator, self.description),
            .top_topics = try holodex.deepCopy(allocator, self.top_topics),
            .yt_handle = try holodex.deepCopy(allocator, self.yt_handle),
            .yt_name_history = try holodex.deepCopy(allocator, self.yt_name_history),
            .crawled_at = try holodex.parseTimestamp(self.crawled_at),
            .comments_crawled_at = try holodex.parseTimestamp(self.comments_crawled_at),
        };
    }
};
