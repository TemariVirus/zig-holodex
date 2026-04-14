const std = @import("std");

const zeit = @import("zeit");

pub const Api = @import("Api.zig");
pub const datatypes = @import("datatypes.zig");
pub const DefaultFormat = @import("defaultFormat.zig").DefaultFormat;
pub const Pager = @import("Pager.zig").Pager;
pub const pretty = @import("defaultFormat.zig").pretty;

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(@import("QueryFormatter.zig"));
    std.testing.refAllDecls(@import("url.zig"));
}
