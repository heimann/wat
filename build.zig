const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "wat",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const tree_sitter = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("tree-sitter", tree_sitter.module("tree-sitter"));

    const tree_sitter_zig = b.dependency("tree_sitter_zig", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_zig.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_zig.path("src"));

    const tree_sitter_go = b.dependency("tree_sitter_go", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_go.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_go.path("src"));

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
