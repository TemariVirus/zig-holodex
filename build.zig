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
    const Ast = std.zig.Ast;

    var ast = Ast.parse(b.allocator, @embedFile("build.zig.zon"), .zon) catch
        @panic("Out of memory");
    defer ast.deinit(b.allocator);

    var buf: [2]Ast.Node.Index = undefined;
    const zon = ast.fullStructInit(&buf, ast.nodes.items(.data)[0].lhs) orelse
        @panic("Failed to parse build.zig.zon");

    for (zon.ast.fields) |field| {
        const field_name = ast.tokenSlice(ast.firstToken(field) - 2);
        if (std.mem.eql(u8, field_name, "version")) {
            const version_string = ast.tokenSlice(ast.firstToken(field));
            // Remove surrounding quotes
            return version_string[1 .. version_string.len - 1];
        }
    }
    @panic("Field 'version' missing from build.zig.zon");
}
