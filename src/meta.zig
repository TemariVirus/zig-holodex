const std = @import("std");

pub fn isErrorSubset(Super: type, Sub: type) bool {
    const super_set = @typeInfo(Super).error_set;
    const sub_set = @typeInfo(Sub).error_set;
    const total_len = super_set.?.len + sub_set.?.len;
    @setEvalBranchQuota(30 * total_len *
        @as(comptime_int, std.math.log2_int_ceil(usize, total_len)));

    var super_names: [super_set.?.len][]const u8 = undefined;
    for (&super_names, super_set.?) |*s, e| {
        s.* = e.name;
    }
    var sub_names: [sub_set.?.len][]const u8 = undefined;
    for (&sub_names, sub_set.?) |*s, e| {
        s.* = e.name;
    }

    const asc = (struct {
        pub fn inner(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }).inner;
    std.sort.pdq([]const u8, &super_names, {}, asc);
    std.sort.pdq([]const u8, &sub_names, {}, asc);

    var i: usize = 0;
    for (super_names) |e| {
        if (i == sub_names.len) return true;
        if (std.mem.eql(u8, e, sub_names[i])) {
            i += 1;
        }
    }
    return i == sub_names.len;
}
