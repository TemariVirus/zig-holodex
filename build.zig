const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const zeit = b.dependency("zeit", .{
        .target = target,
        .optimize = optimize,
    }).module("zeit");

    // Export the library
    const holodex = b.addModule("holodex", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{
            .{ .name = "zeit", .module = zeit },
        },
        .target = target,
        .optimize = optimize,
    });

    // Expose library version to library
    const options = b.addOptions();
    options.addOption([]const u8, "version", libVersion(b));
    holodex.addImport("lib", options.createModule());

    // Unit tests
    const lib_unit_tests = b.addTest(.{ .root_module = holodex });
    lib_unit_tests.root_module.addImport("zeit", zeit);
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn libVersion(b: *std.Build) []const u8 {
    const BuildZigZon = struct {
        version: []const u8,
    };
    const build_zig_zon = std.zon.parse.fromSlice(
        BuildZigZon,
        b.allocator,
        @embedFile("build.zig.zon"),
        null,
        .{ .ignore_unknown_fields = true },
    ) catch @panic("String field 'version' missing from build.zig.zon");
    return build_zig_zon.version;
}
