const std = @import("std");
const tree_sitter = @import("tree-sitter");

extern fn tree_sitter_zig() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_go() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_python() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_javascript() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_typescript() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_rust() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_c() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_java() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_elixir() callconv(.C) *tree_sitter.Language;

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
    } else if (std.mem.endsWith(u8, file_path, ".rs")) {
        return tree_sitter_rust();
    } else if (std.mem.endsWith(u8, file_path, ".c") or std.mem.endsWith(u8, file_path, ".h")) {
        return tree_sitter_c();
    } else if (std.mem.endsWith(u8, file_path, ".java")) {
        return tree_sitter_java();
    } else if (std.mem.endsWith(u8, file_path, ".ex") or std.mem.endsWith(u8, file_path, ".exs")) {
        return tree_sitter_elixir();
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
        std.debug.print("Usage: {s} <file> [--debug]\n", .{args[0]});
        return;
    }

    const file_path = args[1];
    const debug_mode = args.len > 2 and std.mem.eql(u8, args[2], "--debug");
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
        try extractSymbols(root_node, file_content, 0, debug_mode);
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

const IdentifierInfo = struct {
    name: []const u8,
    line: u32,
};

fn extractIdentifierFromDeclarator(declarator: tree_sitter.Node, source: []const u8) ?IdentifierInfo {
    var current = declarator;
    
    // Traverse through declarators to find the identifier
    while (true) {
        const node_type = current.kind();
        
        if (std.mem.eql(u8, node_type, "identifier")) {
            const start = current.startByte();
            const end = current.endByte();
            return IdentifierInfo{
                .name = source[start..end],
                .line = current.startPoint().row + 1,
            };
        }
        
        // Navigate through nested declarators
        if (std.mem.eql(u8, node_type, "function_declarator") or
            std.mem.eql(u8, node_type, "array_declarator") or
            std.mem.eql(u8, node_type, "pointer_declarator") or
            std.mem.eql(u8, node_type, "init_declarator") or
            std.mem.eql(u8, node_type, "parenthesized_declarator")) {
            // Look for first child that might contain identifier
            var i: u32 = 0;
            while (i < current.childCount()) : (i += 1) {
                if (current.child(i)) |child| {
                    const child_type = child.kind();
                    if (std.mem.eql(u8, child_type, "identifier") or
                        std.mem.eql(u8, child_type, "function_declarator") or
                        std.mem.eql(u8, child_type, "array_declarator") or
                        std.mem.eql(u8, child_type, "pointer_declarator") or
                        std.mem.eql(u8, child_type, "parenthesized_declarator")) {
                        current = child;
                        break;
                    }
                }
            } else {
                return null;
            }
        } else {
            return null;
        }
    }
}

fn extractSymbols(node: tree_sitter.Node, source: []const u8, depth: usize, debug_mode: bool) !void {
    const node_type = node.kind();
    
    // Debug: print all node types to understand the grammar
    if (debug_mode and node.isNamed()) {
        std.debug.print("DEBUG: {s}\n", .{node_type});
    }
    
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
        std.mem.eql(u8, node_type, "internal_module") or
        // Rust node types
        std.mem.eql(u8, node_type, "function_item") or
        std.mem.eql(u8, node_type, "struct_item") or
        std.mem.eql(u8, node_type, "enum_item") or
        std.mem.eql(u8, node_type, "trait_item") or
        std.mem.eql(u8, node_type, "impl_item") or
        std.mem.eql(u8, node_type, "const_item") or
        std.mem.eql(u8, node_type, "static_item") or
        std.mem.eql(u8, node_type, "type_item") or
        std.mem.eql(u8, node_type, "mod_item") or
        std.mem.eql(u8, node_type, "macro_definition") or
        // C node types
        std.mem.eql(u8, node_type, "function_definition") or
        std.mem.eql(u8, node_type, "declaration") or
        std.mem.eql(u8, node_type, "type_definition") or
        std.mem.eql(u8, node_type, "struct_specifier") or
        std.mem.eql(u8, node_type, "enum_specifier") or
        std.mem.eql(u8, node_type, "union_specifier") or
        std.mem.eql(u8, node_type, "preproc_def") or
        // Java node types
        std.mem.eql(u8, node_type, "class_declaration") or
        std.mem.eql(u8, node_type, "interface_declaration") or
        std.mem.eql(u8, node_type, "enum_declaration") or
        std.mem.eql(u8, node_type, "method_declaration") or
        std.mem.eql(u8, node_type, "constructor_declaration")) {
        
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
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "function_definition")) {
                    // C function definitions have function_declarator child
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        std.debug.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type });
                        break;
                    }
                } else if (std.mem.eql(u8, child_type, "init_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C variable declarations
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        std.debug.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type });
                    }
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C function declarations (prototypes)
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        std.debug.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type });
                    }
                } else if ((std.mem.eql(u8, child_type, "parenthesized_declarator") or
                            std.mem.eql(u8, child_type, "pointer_declarator")) and
                           std.mem.eql(u8, node_type, "type_definition")) {
                    // C typedef for function pointers
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        std.debug.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type });
                        break;
                    }
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
    
    // Special handling for Java enum constants
    if (std.mem.eql(u8, node_type, "enum_constant")) {
        if (node.child(0)) |id_node| {
            if (std.mem.eql(u8, id_node.kind(), "identifier")) {
                const start = id_node.startByte();
                const end = id_node.endByte();
                const name = source[start..end];
                const line = id_node.startPoint().row + 1;
                
                std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, node_type });
            }
        }
    }
    
    // Special handling for Java field declarations
    if (std.mem.eql(u8, node_type, "field_declaration")) {
        var j: u32 = 0;
        while (j < node.childCount()) : (j += 1) {
            if (node.child(j)) |child| {
                if (std.mem.eql(u8, child.kind(), "variable_declarator")) {
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
    
    // Special handling for Elixir calls (defmodule, def, defp, etc.)
    if (std.mem.eql(u8, node_type, "call")) {
        if (node.child(0)) |first_child| {
            if (std.mem.eql(u8, first_child.kind(), "identifier")) {
                const start = first_child.startByte();
                const end = first_child.endByte();
                const call_type = source[start..end];
                
                
                // Check if it's a definition call
                if (std.mem.eql(u8, call_type, "defmodule") or
                    std.mem.eql(u8, call_type, "def") or
                    std.mem.eql(u8, call_type, "defp") or
                    std.mem.eql(u8, call_type, "defmacro") or
                    std.mem.eql(u8, call_type, "defprotocol") or
                    std.mem.eql(u8, call_type, "defimpl")) {
                    
                    // Get the name from arguments
                    if (node.child(1)) |args| {
                        if (std.mem.eql(u8, args.kind(), "arguments")) {
                            if (args.child(0)) |name_node| {
                                // Handle module names (aliases)
                                if (std.mem.eql(u8, name_node.kind(), "alias")) {
                                    // For now, just get the whole alias text
                                    const n_start = name_node.startByte();
                                    const n_end = name_node.endByte();
                                    const name = source[n_start..n_end];
                                    const line = name_node.startPoint().row + 1;
                                    std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, call_type });
                                } else if (std.mem.eql(u8, name_node.kind(), "identifier") or
                                           std.mem.eql(u8, name_node.kind(), "atom")) {
                                    const n_start = name_node.startByte();
                                    const n_end = name_node.endByte();
                                    var name = source[n_start..n_end];
                                    // Remove leading : from atoms
                                    if (name.len > 0 and name[0] == ':') {
                                        name = name[1..];
                                    }
                                    const line = name_node.startPoint().row + 1;
                                    std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, call_type });
                                } else if (std.mem.eql(u8, name_node.kind(), "call")) {
                                    // Function definitions with pattern matching
                                    if (name_node.child(0)) |func_name| {
                                        if (std.mem.eql(u8, func_name.kind(), "identifier")) {
                                            const n_start = func_name.startByte();
                                            const n_end = func_name.endByte();
                                            const name = source[n_start..n_end];
                                            const line = func_name.startPoint().row + 1;
                                            std.debug.print("{s}\t{d}\t{s}\n", .{ name, line, call_type });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try extractSymbols(child, source, depth + 1, debug_mode);
        }
    }
}