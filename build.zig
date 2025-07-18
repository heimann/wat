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

    const tree_sitter_python = b.dependency("tree_sitter_python", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_python.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_python.path("src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_python.path("src"));

    const tree_sitter_javascript = b.dependency("tree_sitter_javascript", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_javascript.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_javascript.path("src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_javascript.path("src"));

    const tree_sitter_typescript = b.dependency("tree_sitter_typescript", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_typescript.path("typescript/src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_typescript.path("typescript/src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_typescript.path("typescript/src"));

    const tree_sitter_rust = b.dependency("tree_sitter_rust", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_rust.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_rust.path("src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_rust.path("src"));

    const tree_sitter_c = b.dependency("tree_sitter_c", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_c.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_c.path("src"));

    const tree_sitter_java = b.dependency("tree_sitter_java", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_java.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_java.path("src"));

    const tree_sitter_elixir = b.dependency("tree_sitter_elixir", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_elixir.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_elixir.path("src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_elixir.path("src"));

    const tree_sitter_html = b.dependency("tree_sitter_html", .{});
    exe.addCSourceFile(.{
        .file = tree_sitter_html.path("src/parser.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addCSourceFile(.{
        .file = tree_sitter_html.path("src/scanner.c"),
        .flags = &.{"-std=c11"},
    });
    exe.addIncludePath(tree_sitter_html.path("src"));

    // Link SQLite
    exe.linkSystemLibrary("sqlite3");
    exe.linkLibC();

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
