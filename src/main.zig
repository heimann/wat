const std = @import("std");
const tree_sitter = @import("tree-sitter");

extern fn tree_sitter_zig() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_go() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_python() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_javascript() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_typescript() callconv(.C) *tree_sitter.Language;

fn detectLanguage(file_path: []const u8) ?*tree_sitter.Language {
    if (std.mem.endsWith(u8, file_path, ".zig")) {
        return tree_sitter_zig();
    } else if (std.mem.endsWith(u8, file_path, ".go")) {
        return tree_sitter_go();
    } else if (std.mem.endsWith(u8, file_path, ".py")) {
        return tree_sitter_python();
    } else if (std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".mjs")) {
        return tree_sitter_javascript();
    } else if (std.mem.endsWith(u8, file_path, ".ts") or std.mem.endsWith(u8, file_path, ".tsx")) {
        return tree_sitter_typescript();
    }
    return null;
}

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

    // Detect language based on file extension
    const language = detectLanguage(file_path) orelse {
        std.debug.print("Unsupported file type: {s}\n", .{file_path});
        return;
    };
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

fn extractSymbolFromSpec(spec_node: tree_sitter.Node, source: []const u8, parent_type: []const u8) !void {
    // Find the identifier in spec nodes
    var i: u32 = 0;
    while (i < spec_node.childCount()) : (i += 1) {
        if (spec_node.child(i)) |child| {
            if (std.mem.eql(u8, child.kind(), "identifier") or 
                std.mem.eql(u8, child.kind(), "type_identifier")) {
                const start = child.startByte();
                const end = child.endByte();
                const name = source[start..end];
                const line = child.startPoint().row + 1;
                
                std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, parent_type });
                break;
            }
        }
    }
}

fn extractSymbols(node: tree_sitter.Node, source: []const u8, depth: usize) !void {
    const node_type = node.kind();
    
    // Debug: print all node types to understand the grammar
    // if (node.isNamed()) {
    //     std.debug.print("DEBUG: {s}\n", .{node_type});
    // }
    
    // Check for symbol-like nodes in Zig
    if (std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "test_declaration") or
        std.mem.eql(u8, node_type, "variable_declaration") or
        std.mem.eql(u8, node_type, "struct_declaration") or
        std.mem.eql(u8, node_type, "enum_declaration") or
        std.mem.eql(u8, node_type, "union_declaration") or
        std.mem.eql(u8, node_type, "error_set_declaration") or
        // Go node types
        std.mem.eql(u8, node_type, "type_declaration") or
        std.mem.eql(u8, node_type, "const_declaration") or
        std.mem.eql(u8, node_type, "var_declaration") or
        // Python node types
        std.mem.eql(u8, node_type, "function_definition") or
        std.mem.eql(u8, node_type, "class_definition") or
        // JavaScript node types (note: function_declaration is already covered)
        std.mem.eql(u8, node_type, "class_declaration") or
        std.mem.eql(u8, node_type, "method_definition") or
        // TypeScript node types
        std.mem.eql(u8, node_type, "interface_declaration") or
        std.mem.eql(u8, node_type, "type_alias_declaration") or
        std.mem.eql(u8, node_type, "enum_declaration") or
        std.mem.eql(u8, node_type, "internal_module")) {
        
        // Find the identifier child
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.kind();
                // For Go, we need to look at spec nodes
                if (std.mem.eql(u8, child_type, "type_spec") or
                    std.mem.eql(u8, child_type, "const_spec") or
                    std.mem.eql(u8, child_type, "var_spec")) {
                    // Extract from spec nodes
                    try extractSymbolFromSpec(child, source, node_type);
                } else if (std.mem.eql(u8, child_type, "identifier") or
                           std.mem.eql(u8, child_type, "type_identifier")) {
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
    
    // Special handling for Python global assignments
    if (std.mem.eql(u8, node_type, "assignment")) { // module-level assignment
        if (node.child(0)) |left| {
            if (std.mem.eql(u8, left.kind(), "identifier")) {
                const start = left.startByte();
                const end = left.endByte();
                const name = source[start..end];
                const line = left.startPoint().row + 1;
                
                std.debug.print("{s}\t{d}\tassignment\n", .{ name, line });
            }
        }
    }
    
    // Special handling for JavaScript/TypeScript variable declarations
    if (std.mem.eql(u8, node_type, "lexical_declaration") or
        std.mem.eql(u8, node_type, "variable_declaration")) {
        // Find variable_declarator children
        var j: u32 = 0;
        while (j < node.childCount()) : (j += 1) {
            if (node.child(j)) |child| {
                if (std.mem.eql(u8, child.kind(), "variable_declarator")) {
                    // Get the identifier (first child of declarator)
                    if (child.child(0)) |id_node| {
                        if (std.mem.eql(u8, id_node.kind(), "identifier")) {
                            const start = id_node.startByte();
                            const end = id_node.endByte();
                            const name = source[start..end];
                            const line = id_node.startPoint().row + 1;
                            
                            std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, node_type });
                        }
                    }
                }
            }
        }
    }
    
    // Special handling for TypeScript public field definitions
    if (std.mem.eql(u8, node_type, "public_field_definition")) {
        // Find the property_identifier
        var k: u32 = 0;
        while (k < node.childCount()) : (k += 1) {
            if (node.child(k)) |child| {
                if (std.mem.eql(u8, child.kind(), "property_identifier")) {
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