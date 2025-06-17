const std = @import("std");
const tree_sitter = @import("tree-sitter");

extern fn tree_sitter_zig() callconv(.C) *tree_sitter.Language;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file>\n", .{args[0]});
        return;
    }

    const file_path = args[1];
    const file_content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024 * 10); // 10MB max
    defer allocator.free(file_content);

    // Initialize tree-sitter
    const parser = tree_sitter.Parser.create();
    defer parser.destroy();

    // Set the language to Zig
    const language = tree_sitter_zig();
    try parser.setLanguage(language);
    
    // Parse the file
    const tree = parser.parseString(file_content, null);
    if (tree) |t| {
        defer t.destroy();
        
        const root_node = t.rootNode();
        
        // Walk the tree and extract symbols
        try extractSymbols(root_node, file_content, 0);
    } else {
        std.debug.print("Failed to parse file\n", .{});
    }
}

fn extractSymbols(node: tree_sitter.Node, source: []const u8, depth: usize) !void {
    const node_type = node.kind();
    
    // Debug: print all node types to understand the grammar
    // if (node.isNamed()) {
    //     std.debug.print("{s: >[1]}{s}\n", .{ "", node_type });
    // }
    
    // Check for symbol-like nodes in Zig
    if (std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "test_declaration") or
        std.mem.eql(u8, node_type, "variable_declaration") or
        std.mem.eql(u8, node_type, "struct_declaration") or
        std.mem.eql(u8, node_type, "enum_declaration") or
        std.mem.eql(u8, node_type, "union_declaration") or
        std.mem.eql(u8, node_type, "error_set_declaration")) {
        
        // Find the identifier child
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.kind(), "identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    const name = source[start..end];
                    const line = child.startPoint().row + 1;
                    
                    std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, node_type });
                    break;
                }
            }
        }
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try extractSymbols(child, source, depth + 1);
        }
    }
}