const std = @import("std");
const tree_sitter = @import("tree-sitter");
const Database = @import("database.zig").Database;

extern fn tree_sitter_zig() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_go() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_python() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_javascript() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_typescript() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_rust() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_c() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_java() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_elixir() callconv(.C) *tree_sitter.Language;
extern fn tree_sitter_html() callconv(.C) *tree_sitter.Language;

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
    } else if (std.mem.endsWith(u8, file_path, ".html") or std.mem.endsWith(u8, file_path, ".htm")) {
        return tree_sitter_html();
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
        printUsage(args[0]);
        return;
    }

    // Check for commands
    if (std.mem.eql(u8, args[1], "index")) {
        if (args.len < 3) {
            std.debug.print("Usage: {s} index <directory>\n", .{args[0]});
            return;
        }
        try indexCommand(allocator, args[2]);
    } else if (std.mem.eql(u8, args[1], "find")) {
        if (args.len < 3) {
            std.debug.print("Usage: {s} find <symbol>\n", .{args[0]});
            return;
        }
        try findCommand(allocator, args[2]);
    } else if (std.mem.eql(u8, args[1], "refs")) {
        if (args.len < 3) {
            std.debug.print("Usage: {s} refs <symbol> [--with-context] [--include-defs]\n", .{args[0]});
            return;
        }
        
        var with_context = false;
        var include_defs = false;
        
        // Parse flags
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--with-context")) {
                with_context = true;
            } else if (std.mem.eql(u8, args[i], "--include-defs")) {
                include_defs = true;
            }
        }
        
        try refsCommand(allocator, args[2], with_context, include_defs);
    } else {
        // Default: process single file
        const file_path = args[1];
        const debug_mode = args.len > 2 and std.mem.eql(u8, args[2], "--debug");
        try processFile(allocator, file_path, debug_mode, null);
    }
}

fn isSymbolNode(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "class_declaration") or
        std.mem.eql(u8, node_type, "class_definition") or
        std.mem.eql(u8, node_type, "const_declaration") or
        std.mem.eql(u8, node_type, "const_item") or
        std.mem.eql(u8, node_type, "constructor_declaration") or
        std.mem.eql(u8, node_type, "declaration") or
        std.mem.eql(u8, node_type, "enum_declaration") or
        std.mem.eql(u8, node_type, "enum_item") or
        std.mem.eql(u8, node_type, "enum_specifier") or
        std.mem.eql(u8, node_type, "error_set_declaration") or
        std.mem.eql(u8, node_type, "function_declaration") or
        std.mem.eql(u8, node_type, "function_definition") or
        std.mem.eql(u8, node_type, "function_item") or
        std.mem.eql(u8, node_type, "impl_item") or
        std.mem.eql(u8, node_type, "interface_declaration") or
        std.mem.eql(u8, node_type, "internal_module") or
        std.mem.eql(u8, node_type, "macro_definition") or
        std.mem.eql(u8, node_type, "method_declaration") or
        std.mem.eql(u8, node_type, "method_definition") or
        std.mem.eql(u8, node_type, "mod_item") or
        std.mem.eql(u8, node_type, "preproc_def") or
        std.mem.eql(u8, node_type, "static_item") or
        std.mem.eql(u8, node_type, "struct_declaration") or
        std.mem.eql(u8, node_type, "struct_item") or
        std.mem.eql(u8, node_type, "struct_specifier") or
        std.mem.eql(u8, node_type, "test_declaration") or
        std.mem.eql(u8, node_type, "trait_item") or
        std.mem.eql(u8, node_type, "type_alias_declaration") or
        std.mem.eql(u8, node_type, "type_declaration") or
        std.mem.eql(u8, node_type, "type_definition") or
        std.mem.eql(u8, node_type, "type_item") or
        std.mem.eql(u8, node_type, "union_declaration") or
        std.mem.eql(u8, node_type, "union_specifier") or
        std.mem.eql(u8, node_type, "var_declaration") or
        std.mem.eql(u8, node_type, "variable_declaration");
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
    
    // Check for symbol-like nodes
    if (isSymbolNode(node_type)) {
        
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
    
    // Special handling for HTML elements with id attributes
    if (std.mem.eql(u8, node_type, "element")) {
        // Find start_tag child
        var tag_idx: u32 = 0;
        while (tag_idx < node.childCount()) : (tag_idx += 1) {
            if (node.child(tag_idx)) |tag_child| {
                if (std.mem.eql(u8, tag_child.kind(), "start_tag")) {
                    // Look for attributes
                    var attr_idx: u32 = 0;
                    while (attr_idx < tag_child.childCount()) : (attr_idx += 1) {
                        if (tag_child.child(attr_idx)) |attr| {
                            if (std.mem.eql(u8, attr.kind(), "attribute")) {
                                // Check if this is an id attribute
                                if (attr.child(0)) |attr_name| {
                                    if (std.mem.eql(u8, attr_name.kind(), "attribute_name")) {
                                        const name_start = attr_name.startByte();
                                        const name_end = attr_name.endByte();
                                        const attr_name_str = source[name_start..name_end];
                                        
                                        if (std.mem.eql(u8, attr_name_str, "id")) {
                                            // Get the attribute value - look through all children
                                            var val_idx: u32 = 0;
                                            while (val_idx < attr.childCount()) : (val_idx += 1) {
                                                if (attr.child(val_idx)) |attr_child| {
                                                    const child_kind = attr_child.kind();
                                                    if (std.mem.eql(u8, child_kind, "attribute_value") or
                                                        std.mem.eql(u8, child_kind, "quoted_attribute_value")) {
                                                        const value_start = attr_child.startByte();
                                                        const value_end = attr_child.endByte();
                                                        var id_value = source[value_start..value_end];
                                                        
                                                        // Remove quotes if present
                                                        if (id_value.len >= 2 and 
                                                            (id_value[0] == '"' or id_value[0] == '\'') and
                                                            (id_value[id_value.len - 1] == '"' or id_value[id_value.len - 1] == '\'')) {
                                                            id_value = id_value[1..id_value.len - 1];
                                                        }
                                                        
                                                        const line = attr_child.startPoint().row + 1;
                                                        std.debug.print("{s}\t{d}\tid_attribute\n", .{ id_value, line });
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break;
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

fn printUsage(program_name: []const u8) void {
    std.debug.print("Usage:\n", .{});
    std.debug.print("  {s} <file> [--debug]                         Extract symbols from a single file\n", .{program_name});
    std.debug.print("  {s} index <directory>                        Index all supported files in directory\n", .{program_name});
    std.debug.print("  {s} find <symbol>                            Find symbol in indexed database\n", .{program_name});
    std.debug.print("  {s} refs <symbol> [--with-context] [--include-defs]  Find references to symbol\n", .{program_name});
    std.debug.print("\nOptions for refs:\n", .{});
    std.debug.print("  --with-context   Show the line of code containing each reference\n", .{});
    std.debug.print("  --include-defs   Include symbol definitions in the results\n", .{});
}

fn processFile(allocator: std.mem.Allocator, file_path: []const u8, debug_mode: bool, db: ?*Database) !void {
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
        
        if (db) |database| {
            // Get file info
            const stat = try std.fs.cwd().statFile(file_path);
            const last_modified = @as(i64, @intCast(@divFloor(stat.mtime, std.time.ns_per_s)));
            
            // Get language name
            const lang_name = getLanguageName(file_path) orelse "unknown";
            
            // Insert file into database
            const file_id = try database.insertFile(file_path, last_modified, lang_name);
            
            // Delete old symbols and references for this file
            try database.deleteFileSymbols(file_id);
            try database.deleteFileReferences(file_id);
            
            // Extract symbols to database
            var context = DatabaseContext{
                .db = database,
                .file_id = file_id,
                .allocator = allocator,
            };
            try extractSymbolsToDatabase(root_node, file_content, 0, &context);
            
            // Extract references to database
            try extractReferencesToDatabase(root_node, file_content, 0, &context);
        } else {
            // Original behavior: print to stdout
            try extractSymbols(root_node, file_content, 0, debug_mode);
        }
    } else {
        std.debug.print("Failed to parse file\n", .{});
    }
}

fn getLanguageName(file_path: []const u8) ?[]const u8 {
    if (std.mem.endsWith(u8, file_path, ".zig")) return "zig";
    if (std.mem.endsWith(u8, file_path, ".go")) return "go";
    if (std.mem.endsWith(u8, file_path, ".py")) return "python";
    if (std.mem.endsWith(u8, file_path, ".js") or std.mem.endsWith(u8, file_path, ".mjs")) return "javascript";
    if (std.mem.endsWith(u8, file_path, ".ts") or std.mem.endsWith(u8, file_path, ".tsx")) return "typescript";
    if (std.mem.endsWith(u8, file_path, ".rs")) return "rust";
    if (std.mem.endsWith(u8, file_path, ".c") or std.mem.endsWith(u8, file_path, ".h")) return "c";
    if (std.mem.endsWith(u8, file_path, ".java")) return "java";
    if (std.mem.endsWith(u8, file_path, ".ex") or std.mem.endsWith(u8, file_path, ".exs")) return "elixir";
    if (std.mem.endsWith(u8, file_path, ".html") or std.mem.endsWith(u8, file_path, ".htm")) return "html";
    return null;
}

fn indexCommand(allocator: std.mem.Allocator, path: []const u8) !void {
    // Open or create database
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    std.debug.print("Indexing directory: {s}\n", .{path});
    
    try db.beginTransaction();
    errdefer db.rollback() catch {};
    
    var indexed_count: u32 = 0;
    try indexDirectory(allocator, path, &db, &indexed_count);
    
    try db.commit();
    std.debug.print("Indexed {d} files\n", .{indexed_count});
}

fn indexDirectory(allocator: std.mem.Allocator, path: []const u8, db: *Database, count: *u32) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    
    var it = dir.iterate();
    while (try it.next()) |entry| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name });
        defer allocator.free(full_path);
        
        switch (entry.kind) {
            .directory => {
                // Skip hidden directories and common non-source directories
                if (!std.mem.startsWith(u8, entry.name, ".") and
                    !std.mem.eql(u8, entry.name, "node_modules") and
                    !std.mem.eql(u8, entry.name, "target") and
                    !std.mem.eql(u8, entry.name, "zig-out") and
                    !std.mem.eql(u8, entry.name, "zig-cache")) {
                    try indexDirectory(allocator, full_path, db, count);
                }
            },
            .file => {
                if (detectLanguage(entry.name) != null) {
                    // Check if file needs reindexing
                    const stat = try dir.statFile(entry.name);
                    const last_modified = @as(i64, @intCast(@divFloor(stat.mtime, std.time.ns_per_s)));
                    
                    if (try db.needsReindex(full_path, last_modified)) {
                        std.debug.print("Indexing: {s}\n", .{full_path});
                        processFile(allocator, full_path, false, db) catch |err| {
                            std.debug.print("Error indexing {s}: {}\n", .{ full_path, err });
                            continue;
                        };
                        count.* += 1;
                    }
                }
            },
            else => {},
        }
    }
}

fn findCommand(allocator: std.mem.Allocator, symbol_name: []const u8) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    const symbols = try db.findSymbol(symbol_name, allocator);
    defer @import("database.zig").deinitSymbols(symbols, allocator);
    
    if (symbols.len == 0) {
        std.debug.print("Symbol '{s}' not found\n", .{symbol_name});
        return;
    }
    
    // Print in ctags format
    for (symbols) |sym| {
        std.debug.print("{s}\t{s}\t{d}\t{s}\n", .{ sym.name, sym.path, sym.line, sym.node_type });
    }
}

fn refsCommand(allocator: std.mem.Allocator, symbol_name: []const u8, with_context: bool, include_defs: bool) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    const references = try db.findReferences(symbol_name, include_defs, allocator);
    defer @import("database.zig").deinitReferences(references, allocator);
    
    if (references.len == 0) {
        std.debug.print("No references to '{s}' found\n", .{symbol_name});
        return;
    }
    
    // Print header
    if (include_defs) {
        std.debug.print("References and definitions of '{s}':\n", .{symbol_name});
    } else {
        std.debug.print("References to '{s}':\n", .{symbol_name});
    }
    
    // Print references
    for (references) |ref| {
        if (ref.is_definition) {
            std.debug.print("[DEF] ", .{});
        }
        
        if (with_context and ref.context != null) {
            std.debug.print("{s}:{d}:{d}\n", .{ ref.path, ref.line, ref.column });
            std.debug.print("    {s}\n", .{ref.context.?});
            
            // Print a caret under the column position
            if (ref.column > 0) {
                var spaces: usize = 4; // 4 spaces for indentation
                var col: usize = 0;
                for (ref.context.?) |c| {
                    if (col >= ref.column - 1) break;
                    if (c == '\t') {
                        spaces += 4; // Assume tab width of 4
                    } else {
                        spaces += 1;
                    }
                    col += 1;
                }
                // Print spaces followed by carets for the length of the symbol
                var j: usize = 0;
                while (j < spaces) : (j += 1) {
                    std.debug.print(" ", .{});
                }
                // Print carets for the length of the symbol name
                j = 0;
                while (j < symbol_name.len) : (j += 1) {
                    std.debug.print("^", .{});
                }
                std.debug.print("\n", .{});
            }
        } else {
            std.debug.print("{s}:{d}:{d}\n", .{ ref.path, ref.line, ref.column });
        }
    }
}

const DatabaseContext = struct {
    db: *Database,
    file_id: i64,
    allocator: std.mem.Allocator,
};

fn extractSymbolsToDatabase(node: tree_sitter.Node, source: []const u8, depth: usize, context: *DatabaseContext) !void {
    const node_type = node.kind();
    
    // Check for symbol-like nodes
    if (isSymbolNode(node_type)) {
        // Extract symbol name and insert to database
        var found = false;
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.kind();
                // For Go, we need to look at spec nodes
                if (std.mem.eql(u8, child_type, "type_spec") or
                    std.mem.eql(u8, child_type, "const_spec") or
                    std.mem.eql(u8, child_type, "var_spec")) {
                    try extractSymbolFromSpecToDatabase(child, source, node_type, context);
                    found = true;
                } else if (std.mem.eql(u8, child_type, "identifier") or
                           std.mem.eql(u8, child_type, "type_identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    const name = source[start..end];
                    const line = child.startPoint().row + 1;
                    const column = child.startPoint().column + 1;
                    
                    try context.db.insertSymbol(context.file_id, name, line, node_type);
                    
                    // Also store as a definition reference
                    const context_line = getLineContext(source, start, end);
                    try context.db.insertReference(context.file_id, name, line, column, context_line, true);
                    
                    found = true;
                    break;
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "function_definition")) {
                    // C function definitions have function_declarator child
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                        break;
                    }
                } else if (std.mem.eql(u8, child_type, "init_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C variable declarations
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                    }
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C function declarations (prototypes)
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                    }
                } else if ((std.mem.eql(u8, child_type, "parenthesized_declarator") or
                            std.mem.eql(u8, child_type, "pointer_declarator")) and
                           std.mem.eql(u8, node_type, "type_definition")) {
                    // C typedef for function pointers
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                        break;
                    }
                }
            }
        }
    }
    
    // Special handling for Python global assignments
    if (std.mem.eql(u8, node_type, "assignment")) {
        if (node.child(0)) |left| {
            if (std.mem.eql(u8, left.kind(), "identifier")) {
                const start = left.startByte();
                const end = left.endByte();
                const name = source[start..end];
                const line = left.startPoint().row + 1;
                
                try context.db.insertSymbol(context.file_id, name, line, "assignment");
            }
        }
    }
    
    // Special handling for JavaScript/TypeScript variable declarations
    if (std.mem.eql(u8, node_type, "lexical_declaration") or
        std.mem.eql(u8, node_type, "variable_declaration")) {
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
                            
                            try context.db.insertSymbol(context.file_id, name, line, node_type);
                        }
                    }
                }
            }
        }
    }
    
    // Special handling for TypeScript public field definitions
    if (std.mem.eql(u8, node_type, "public_field_definition")) {
        var k: u32 = 0;
        while (k < node.childCount()) : (k += 1) {
            if (node.child(k)) |child| {
                if (std.mem.eql(u8, child.kind(), "property_identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    const name = source[start..end];
                    const line = child.startPoint().row + 1;
                    
                    try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                
                try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                            
                            try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                
                if (std.mem.eql(u8, call_type, "defmodule") or
                    std.mem.eql(u8, call_type, "def") or
                    std.mem.eql(u8, call_type, "defp") or
                    std.mem.eql(u8, call_type, "defmacro") or
                    std.mem.eql(u8, call_type, "defprotocol") or
                    std.mem.eql(u8, call_type, "defimpl")) {
                    
                    if (node.child(1)) |args| {
                        if (std.mem.eql(u8, args.kind(), "arguments")) {
                            if (args.child(0)) |name_node| {
                                if (std.mem.eql(u8, name_node.kind(), "alias")) {
                                    const n_start = name_node.startByte();
                                    const n_end = name_node.endByte();
                                    const name = source[n_start..n_end];
                                    const line = name_node.startPoint().row + 1;
                                    try context.db.insertSymbol(context.file_id, name, line, call_type);
                                } else if (std.mem.eql(u8, name_node.kind(), "identifier") or
                                           std.mem.eql(u8, name_node.kind(), "atom")) {
                                    const n_start = name_node.startByte();
                                    const n_end = name_node.endByte();
                                    var name = source[n_start..n_end];
                                    if (name.len > 0 and name[0] == ':') {
                                        name = name[1..];
                                    }
                                    const line = name_node.startPoint().row + 1;
                                    try context.db.insertSymbol(context.file_id, name, line, call_type);
                                } else if (std.mem.eql(u8, name_node.kind(), "call")) {
                                    if (name_node.child(0)) |func_name| {
                                        if (std.mem.eql(u8, func_name.kind(), "identifier")) {
                                            const n_start = func_name.startByte();
                                            const n_end = func_name.endByte();
                                            const name = source[n_start..n_end];
                                            const line = func_name.startPoint().row + 1;
                                            try context.db.insertSymbol(context.file_id, name, line, call_type);
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
    
    // Special handling for HTML elements with id attributes
    if (std.mem.eql(u8, node_type, "element")) {
        var tag_idx: u32 = 0;
        while (tag_idx < node.childCount()) : (tag_idx += 1) {
            if (node.child(tag_idx)) |tag_child| {
                if (std.mem.eql(u8, tag_child.kind(), "start_tag")) {
                    var attr_idx: u32 = 0;
                    while (attr_idx < tag_child.childCount()) : (attr_idx += 1) {
                        if (tag_child.child(attr_idx)) |attr| {
                            if (std.mem.eql(u8, attr.kind(), "attribute")) {
                                if (attr.child(0)) |attr_name| {
                                    if (std.mem.eql(u8, attr_name.kind(), "attribute_name")) {
                                        const name_start = attr_name.startByte();
                                        const name_end = attr_name.endByte();
                                        const attr_name_str = source[name_start..name_end];
                                        
                                        if (std.mem.eql(u8, attr_name_str, "id")) {
                                            var val_idx: u32 = 0;
                                            while (val_idx < attr.childCount()) : (val_idx += 1) {
                                                if (attr.child(val_idx)) |attr_child| {
                                                    const child_kind = attr_child.kind();
                                                    if (std.mem.eql(u8, child_kind, "attribute_value") or
                                                        std.mem.eql(u8, child_kind, "quoted_attribute_value")) {
                                                        const value_start = attr_child.startByte();
                                                        const value_end = attr_child.endByte();
                                                        var id_value = source[value_start..value_end];
                                                        
                                                        if (id_value.len >= 2 and 
                                                            (id_value[0] == '"' or id_value[0] == '\'') and
                                                            (id_value[id_value.len - 1] == '"' or id_value[id_value.len - 1] == '\'')) {
                                                            id_value = id_value[1..id_value.len - 1];
                                                        }
                                                        
                                                        const line = attr_child.startPoint().row + 1;
                                                        try context.db.insertSymbol(context.file_id, id_value, line, "id_attribute");
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try extractSymbolsToDatabase(child, source, depth + 1, context);
        }
    }
}

fn getLineContext(source: []const u8, line_start_byte: u32, line_end_byte: u32) []const u8 {
    // Find the start of the line
    var start = line_start_byte;
    while (start > 0 and source[start - 1] != '\n') {
        start -= 1;
    }
    
    // Find the end of the line
    var end = line_end_byte;
    while (end < source.len and source[end] != '\n') {
        end += 1;
    }
    
    return source[start..end];
}

fn extractSymbolFromSpecToDatabase(spec_node: tree_sitter.Node, source: []const u8, parent_type: []const u8, context: *DatabaseContext) !void {
    var i: u32 = 0;
    while (i < spec_node.childCount()) : (i += 1) {
        if (spec_node.child(i)) |child| {
            if (std.mem.eql(u8, child.kind(), "identifier") or 
                std.mem.eql(u8, child.kind(), "type_identifier")) {
                const start = child.startByte();
                const end = child.endByte();
                const name = source[start..end];
                const line = child.startPoint().row + 1;
                
                try context.db.insertSymbol(context.file_id, name, line, parent_type);
                break;
            }
        }
    }
}

fn extractReferencesToDatabase(node: tree_sitter.Node, source: []const u8, depth: usize, context: *DatabaseContext) !void {
    const node_type = node.kind();
    
    // Check if this is an identifier node (potential reference)
    if (std.mem.eql(u8, node_type, "identifier") or
        std.mem.eql(u8, node_type, "type_identifier") or
        std.mem.eql(u8, node_type, "property_identifier") or
        std.mem.eql(u8, node_type, "field_identifier")) {
        
        // Skip if this identifier is part of a definition
        if (node.parent()) |parent| {
            const parent_type = parent.kind();
            // Skip if parent is a symbol definition node
            if (isSymbolNode(parent_type)) {
                // This is a definition, not a reference
                return;
            }
            // Skip if parent is a spec node (Go definitions)
            if (std.mem.eql(u8, parent_type, "type_spec") or
                std.mem.eql(u8, parent_type, "const_spec") or
                std.mem.eql(u8, parent_type, "var_spec")) {
                return;
            }
        }
        
        const start = node.startByte();
        const end = node.endByte();
        const name = source[start..end];
        const point = node.startPoint();
        const line = point.row + 1;
        const column = point.column + 1;
        
        // Get the context line
        const context_line = getLineContext(source, start, end);
        
        // Insert as reference (not a definition)
        try context.db.insertReference(context.file_id, name, line, column, context_line, false);
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try extractReferencesToDatabase(child, source, depth + 1, context);
        }
    }
}