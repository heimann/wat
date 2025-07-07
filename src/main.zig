const std = @import("std");
const tree_sitter = @import("tree-sitter");
const Database = @import("database.zig").Database;
const GitIgnore = @import("gitignore.zig").GitIgnore;

// Writer instances for proper output handling
var stdout: std.fs.File.Writer = undefined;
var stderr: std.fs.File.Writer = undefined;

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

const MatchInfoMode = enum {
    smart,   // Show match info only for fuzzy matches (default)
    always,  // Always show match info column
    never,   // Never show match info column
};

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
    // Initialize writers
    stdout = std.io.getStdOut().writer();
    stderr = std.io.getStdErr().writer();
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2 or (args.len >= 2 and std.mem.eql(u8, args[1], "--help"))) {
        printUsage(args[0]);
        return;
    }

    // Check for commands
    if (std.mem.eql(u8, args[1], "index")) {
        if (args.len >= 3 and std.mem.eql(u8, args[2], "--help")) {
            try stderr.print("Usage: {s} index [directory]\n\n", .{args[0]});
            try stderr.print("Build a searchable index of symbols in the directory.\n", .{});
            try stderr.print("If no directory is specified, indexes the current directory.\n", .{});
            try stderr.print("Creates or updates wat.db in the current directory.\n", .{});
            try stderr.print("\nRespects .gitignore files to exclude dependencies and build artifacts.\n", .{});
            return;
        }
        const index_path = if (args.len >= 3) args[2] else ".";
        try indexCommand(allocator, index_path);
    } else if (std.mem.eql(u8, args[1], "find")) {
        // Check for --help or --interactive first
        var is_interactive = false;
        for (args[2..]) |arg| {
            if (std.mem.eql(u8, arg, "--interactive")) {
                is_interactive = true;
                break;
            }
        }
        
        if ((args.len < 3 and !is_interactive) or (args.len >= 3 and std.mem.eql(u8, args[2], "--help"))) {
            try stderr.print("Usage: {s} find <symbol> [options]\n", .{args[0]});
            try stderr.print("       {s} find --interactive [options]\n\n", .{args[0]});
            try stderr.print("Options:\n", .{});
            try stderr.print("  --with-context   Show the line of code containing the symbol\n", .{});
            try stderr.print("  --with-refs      Show count of references to the symbol\n", .{});
            try stderr.print("  --with-deps      Show count of dependencies from the symbol\n", .{});
            try stderr.print("  --full-context   Show full symbol definition with documentation\n", .{});
            try stderr.print("  --fuzzy          Force fuzzy matching (prefix, suffix, contains)\n", .{});
            try stderr.print("  --strict         Disable automatic fuzzy matching fallback\n", .{});
            try stderr.print("  --match-info <mode>  Control match type display: smart, always, never\n", .{});
            try stderr.print("                   smart: show for fuzzy matches only (default)\n", .{});
            try stderr.print("                   always: always show match type column\n", .{});
            try stderr.print("                   never: never show match type column\n", .{});
            try stderr.print("  --interactive    Launch interactive fuzzy finder\n", .{});
            try stderr.print("  --action <cmd>   Custom action for interactive mode (default: $EDITOR)\n", .{});
            try stderr.print("                   Placeholders: {{file}}, {{line}}, {{name}}\n", .{});
            try stderr.print("  --help           Show this help message\n", .{});
            try stderr.print("\nNote: Fuzzy matching is automatically used when no exact matches are found.\n", .{});
            try stderr.print("      Use --strict to disable this behavior.\n", .{});
            return;
        }
        
        var with_context = false;
        var with_refs = false;
        var full_context = false;
        var with_deps = false;
        var fuzzy = false;
        var strict = false;
        var match_info: MatchInfoMode = .smart;
        var interactive = false;
        var action_template: ?[]const u8 = null;
        
        // Parse flags - start from 2 if --interactive, else from 3
        const start_idx: usize = if (is_interactive) 2 else 3;
        var i: usize = start_idx;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--with-context")) {
                with_context = true;
            } else if (std.mem.eql(u8, args[i], "--with-refs")) {
                with_refs = true;
            } else if (std.mem.eql(u8, args[i], "--full-context")) {
                full_context = true;
            } else if (std.mem.eql(u8, args[i], "--with-deps")) {
                with_deps = true;
            } else if (std.mem.eql(u8, args[i], "--fuzzy")) {
                fuzzy = true;
            } else if (std.mem.eql(u8, args[i], "--strict")) {
                strict = true;
            } else if (std.mem.eql(u8, args[i], "--match-info") and i + 1 < args.len) {
                i += 1;
                if (std.mem.eql(u8, args[i], "always")) {
                    match_info = .always;
                } else if (std.mem.eql(u8, args[i], "never")) {
                    match_info = .never;
                } else if (std.mem.eql(u8, args[i], "smart")) {
                    match_info = .smart;
                } else {
                    try stderr.print("Invalid --match-info value: {s}. Use 'smart', 'always', or 'never'\n", .{args[i]});
                    return;
                }
            } else if (std.mem.eql(u8, args[i], "--interactive")) {
                interactive = true;
            } else if (std.mem.eql(u8, args[i], "--action") and i + 1 < args.len) {
                i += 1;
                action_template = args[i];
            }
        }
        
        // Handle interactive mode
        if (interactive) {
            const interactive_mod = @import("interactive.zig");
            
            var db = try Database.init("wat.db");
            defer db.deinit();
            
            const editor_env = std.process.getEnvVarOwned(allocator, "EDITOR") catch null;
            defer if (editor_env) |e| allocator.free(e);
            
            const action = action_template orelse blk: {
                if (editor_env) |editor| {
                    // Detect common editors and add appropriate syntax
                    if (std.mem.indexOf(u8, editor, "vim") != null or 
                        std.mem.indexOf(u8, editor, "nvim") != null) {
                        break :blk try std.fmt.allocPrint(allocator, "{s} +{{line}} {{file}}", .{editor});
                    } else if (std.mem.indexOf(u8, editor, "emacs") != null) {
                        break :blk try std.fmt.allocPrint(allocator, "{s} +{{line}} {{file}}", .{editor});
                    } else if (std.mem.indexOf(u8, editor, "nano") != null) {
                        break :blk try std.fmt.allocPrint(allocator, "{s} +{{line}} {{file}}", .{editor});
                    } else if (std.mem.indexOf(u8, editor, "code") != null) {
                        break :blk try std.fmt.allocPrint(allocator, "{s} -g {{file}}:{{line}}", .{editor});
                    } else {
                        // Default: just open the file
                        break :blk try std.fmt.allocPrint(allocator, "{s} {{file}}", .{editor});
                    }
                } else {
                    break :blk "vim +{line} {file}";
                }
            };
            const allocated_action = editor_env != null and action_template == null;
            defer if (allocated_action) allocator.free(action);
            
            var finder = try interactive_mod.InteractiveFinder.init(allocator, &db, action);
            defer finder.deinit();
            
            const selected = try finder.run();
            if (selected) |action_info| {
                try action_info.execute(allocator);
            }
            return;
        }
        
        const symbol_name = if (is_interactive) "" else args[2];
        try findCommand(allocator, symbol_name, with_context, with_refs, full_context, with_deps, fuzzy, strict, match_info);
    } else if (std.mem.eql(u8, args[1], "refs")) {
        if (args.len < 3 or (args.len >= 3 and std.mem.eql(u8, args[2], "--help"))) {
            try stderr.print("Usage: {s} refs <symbol> [options]\n\n", .{args[0]});
            try stderr.print("Find all references to a symbol in the codebase.\n\n", .{});
            try stderr.print("Options:\n", .{});
            try stderr.print("  --with-context   Show the line of code with caret indicators\n", .{});
            try stderr.print("  --include-defs   Include symbol definitions in results\n", .{});
            try stderr.print("  --help           Show this help message\n", .{});
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
    } else if (std.mem.eql(u8, args[1], "context")) {
        if (args.len < 3 or (args.len >= 3 and std.mem.eql(u8, args[2], "--help"))) {
            try stderr.print("Usage: {s} context <symbol>\n\n", .{args[0]});
            try stderr.print("Show the full definition of a symbol with documentation.\n", .{});
            return;
        }
        try contextCommand(allocator, args[2]);
    } else if (std.mem.eql(u8, args[1], "deps")) {
        if (args.len < 3 or (args.len >= 3 and std.mem.eql(u8, args[2], "--help"))) {
            try stderr.print("Usage: {s} deps <symbol>\n\n", .{args[0]});
            try stderr.print("Show what other symbols this symbol depends on.\n", .{});
            return;
        }
        try depsCommand(allocator, args[2]);
    } else if (std.mem.eql(u8, args[1], "map")) {
        // Check for help flag
        var show_help = false;
        for (args[2..]) |arg| {
            if (std.mem.eql(u8, arg, "--help")) {
                show_help = true;
                break;
            }
        }
        
        if (show_help) {
            try stderr.print("Usage: {s} map [options]\n\n", .{args[0]});
            try stderr.print("Show the call tree structure of the application.\n\n", .{});
            try stderr.print("Options:\n", .{});
            try stderr.print("  --entry <symbol>  Specify entry point (default: main)\n", .{});
            try stderr.print("  --depth <number>  Limit tree depth (default: 5)\n", .{});
            try stderr.print("  --help            Show this help message\n", .{});
            return;
        }
        
        var entry_point: ?[]const u8 = null;
        var max_depth: u32 = 5; // default depth
        
        // Parse options
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--entry") and i + 1 < args.len) {
                entry_point = args[i + 1];
                i += 1;
            } else if (std.mem.eql(u8, args[i], "--depth") and i + 1 < args.len) {
                max_depth = try std.fmt.parseInt(u32, args[i + 1], 10);
                i += 1;
            }
        }
        
        try mapCommand(allocator, entry_point, max_depth);
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
                
                stdout.print("{s}\t{d}\t{s}\n", .{ name, line, parent_type }) catch {};
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
                    
                    stdout.print("{s}\t{d}\t{s}\n", .{ name, line, node_type }) catch {};
                    break;
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "function_definition")) {
                    // C function definitions have function_declarator child
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        stdout.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type }) catch {};
                        break;
                    }
                } else if (std.mem.eql(u8, child_type, "init_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C variable declarations
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        stdout.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type }) catch {};
                    }
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C function declarations (prototypes)
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        stdout.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type }) catch {};
                    }
                } else if ((std.mem.eql(u8, child_type, "parenthesized_declarator") or
                            std.mem.eql(u8, child_type, "pointer_declarator")) and
                           std.mem.eql(u8, node_type, "type_definition")) {
                    // C typedef for function pointers
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        stdout.print("{s}\t{d}\t{s}\n", .{ id.name, id.line, node_type }) catch {};
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
                
                stdout.print("{s}\t{d}\tassignment\n", .{ name, line }) catch {};
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
                            
                            stdout.print("{s}\t{d}\t{s}\n", .{ name, line, node_type }) catch {};
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
                    
                    stdout.print("{s}\t{d}\t{s}\n", .{ name, line, node_type }) catch {};
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
                
                stdout.print("{s}\t{d}\t{s}\n", .{ name, line, node_type }) catch {};
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
                            
                            stdout.print("{s}\t{d}\t{s}\n", .{ name, line, node_type }) catch {};
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
                                    stdout.print("{s}\t{d}\t{s}\n", .{ name, line, call_type }) catch {};
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
                                    stdout.print("{s}\t{d}\t{s}\n", .{ name, line, call_type }) catch {};
                                } else if (std.mem.eql(u8, name_node.kind(), "call")) {
                                    // Function definitions with pattern matching
                                    if (name_node.child(0)) |func_name| {
                                        if (std.mem.eql(u8, func_name.kind(), "identifier")) {
                                            const n_start = func_name.startByte();
                                            const n_end = func_name.endByte();
                                            const name = source[n_start..n_end];
                                            const line = func_name.startPoint().row + 1;
                                            stdout.print("{s}\t{d}\t{s}\n", .{ name, line, call_type }) catch {};
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
                                                        stdout.print("{s}\t{d}\tid_attribute\n", .{ id_value, line }) catch {};
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
    stdout.print("Usage:\n", .{}) catch {};
    stdout.print("  {s} <file> [--debug]                         Extract symbols from a single file\n", .{program_name}) catch {};
    stdout.print("  {s} index <directory>                        Index all supported files in directory\n", .{program_name}) catch {};
    stdout.print("  {s} find <symbol> [options]                  Find symbol in indexed database\n", .{program_name}) catch {};
    stdout.print("  {s} refs <symbol> [options]                  Find references to symbol\n", .{program_name}) catch {};
    stdout.print("  {s} context <symbol>                         Show full context of symbol with documentation\n", .{program_name}) catch {};
    stdout.print("  {s} deps <symbol>                            Show dependencies of symbol\n", .{program_name}) catch {};
    stdout.print("  {s} map [options]                            Show call tree structure\n", .{program_name}) catch {};
    stdout.print("\nFor help on specific commands, use:\n", .{}) catch {};
    stdout.print("  {s} <command> --help\n", .{program_name}) catch {};
    stdout.print("\nTip: Use 'find <pattern> --fuzzy' for fuzzy matching\n", .{}) catch {};
}

fn processFile(allocator: std.mem.Allocator, file_path: []const u8, debug_mode: bool, db: ?*Database) !void {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024 * 10); // 10MB max
    defer allocator.free(file_content);

    // Initialize tree-sitter
    const parser = tree_sitter.Parser.create();
    defer parser.destroy();

    // Detect language based on file extension
    const language = detectLanguage(file_path) orelse {
        stderr.print("Unsupported file type: {s}\n", .{file_path}) catch {};
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
            
            // Delete old symbols, references, and dependencies for this file
            try database.deleteFileSymbols(file_id);
            try database.deleteFileReferences(file_id);
            try database.deleteFileDependencies(file_id);
            
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
        stderr.print("Failed to parse file\n", .{}) catch {};
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
    
    stdout.print("Indexing directory: {s}\n", .{path}) catch {};
    
    // Load gitignore patterns
    var gitignore = GitIgnore.init(allocator);
    defer gitignore.deinit();
    
    // Load .gitignore from the root directory being indexed
    const gitignore_path = try std.fmt.allocPrint(allocator, "{s}/.gitignore", .{path});
    defer allocator.free(gitignore_path);
    try gitignore.loadFromFile(gitignore_path);
    
    // Add default ignores
    for (@import("gitignore.zig").DEFAULT_IGNORES) |pattern| {
        try gitignore.addPattern(pattern);
    }
    
    try db.beginTransaction();
    errdefer db.rollback() catch {};
    
    var indexed_count: u32 = 0;
    try indexDirectoryWithIgnore(allocator, path, &db, &indexed_count, &gitignore, "");
    
    try db.commit();
    stdout.print("Indexed {d} files\n", .{indexed_count}) catch {};
}

fn indexDirectoryWithIgnore(allocator: std.mem.Allocator, path: []const u8, db: *Database, count: *u32, gitignore: *GitIgnore, relative_path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    
    var it = dir.iterate();
    while (try it.next()) |entry| {
        // Build relative path for gitignore checking
        const entry_relative = if (relative_path.len == 0)
            try allocator.dupe(u8, entry.name)
        else
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ relative_path, entry.name });
        defer allocator.free(entry_relative);
        
        // Check if this entry should be ignored
        if (gitignore.shouldIgnore(entry_relative, entry.kind == .directory)) {
            continue;
        }
        
        // Properly join paths avoiding double slashes
        const full_path = if (std.mem.endsWith(u8, path, "/"))
            try std.fmt.allocPrint(allocator, "{s}{s}", .{ path, entry.name })
        else
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, entry.name });
        defer allocator.free(full_path);
        
        switch (entry.kind) {
            .directory => {
                try indexDirectoryWithIgnore(allocator, full_path, db, count, gitignore, entry_relative);
            },
            .file => {
                if (detectLanguage(entry.name) != null) {
                    // Check if file needs reindexing
                    const stat = try dir.statFile(entry.name);
                    const last_modified = @as(i64, @intCast(@divFloor(stat.mtime, std.time.ns_per_s)));
                    
                    if (try db.needsReindex(full_path, last_modified)) {
                        stdout.print("Indexing: {s}\n", .{full_path}) catch {};
                        processFile(allocator, full_path, false, db) catch |err| {
                            stderr.print("Error indexing {s}: {}\n", .{ full_path, err }) catch {};
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

fn findCommand(allocator: std.mem.Allocator, symbol_name: []const u8, with_context: bool, with_refs: bool, full_context: bool, with_deps: bool, fuzzy: bool, strict: bool, match_info: MatchInfoMode) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    // Try exact match first
    const symbols = try db.findSymbol(symbol_name, allocator);
    defer @import("database.zig").deinitSymbols(symbols, allocator);
    
    // If no exact matches and strict mode is disabled, try fuzzy matching
    if (symbols.len == 0 and !strict) {
        const fuzzy_matches = try db.findSymbolFuzzy(symbol_name, allocator);
        defer @import("database.zig").deinitSymbolMatches(fuzzy_matches, allocator);
        
        if (fuzzy_matches.len == 0) {
            stderr.print("No symbols matching '{s}' found\n", .{symbol_name}) catch {};
            return;
        }
        
        // Process fuzzy matches
        if (!fuzzy) {
            // Automatic fallback - notify user
            stdout.print("No exact match for '{s}'. Showing fuzzy matches:\n", .{symbol_name}) catch {};
        } else {
            // Explicit fuzzy search
            stdout.print("Fuzzy matches for '{s}':\n", .{symbol_name}) catch {};
        }
        for (fuzzy_matches) |match| {
            // Print match info based on setting
            switch (match_info) {
                .always, .smart => {
                    try stdout.print("[{s}:{d}]\t", .{ match.match_type, match.score });
                },
                .never => {},
            }
            
            // Print standard fields
            try stdout.print("{s}\t{s}\t{d}\t{s}", .{ 
                match.symbol.name, 
                match.symbol.path, 
                match.symbol.line, 
                match.symbol.node_type 
            });
            
            // Add reference count if requested
            if (with_refs) {
                const refs_count = try db.getReferencesCount(match.symbol.name);
                try stdout.print("\trefs: {d}", .{refs_count});
            }
            
            // Add dependency count if requested
            if (with_deps) {
                const deps_count = try db.getDependenciesCount(match.symbol.name);
                try stdout.print("\tdeps: {d}", .{deps_count});
            }
            
            try stdout.print("\n", .{});
            
            // Show line context if requested
            if (with_context) {
                const file = try std.fs.cwd().openFile(match.symbol.path, .{});
                defer file.close();
                
                const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
                defer allocator.free(content);
                
                // Find the line
                var line_count: u32 = 1;
                var line_start: usize = 0;
                var line_end: usize = 0;
                
                for (content, 0..) |char, idx| {
                    if (char == '\n') {
                        if (line_count == match.symbol.line) {
                            line_end = idx;
                            break;
                        }
                        line_count += 1;
                        line_start = idx + 1;
                    }
                }
                
                // Handle last line without newline
                if (line_count == match.symbol.line and line_end == 0) {
                    line_end = content.len;
                }
                
                if (line_start < content.len and line_end > line_start) {
                    const line_content = content[line_start..line_end];
                    try stdout.print("  {s}\n", .{line_content});
                }
            }
        }
        return;
    }
    
    // If no exact matches and strict mode is enabled, report not found
    if (symbols.len == 0 and strict) {
        stderr.print("Symbol '{s}' not found\n", .{symbol_name}) catch {};
        return;
    }
    
    // Handle full context option (like context command)
    if (full_context) {
        for (symbols) |sym| {
            try stdout.print("{s} in {s}:{d}\n", .{ sym.name, sym.path, sym.line });
            try stdout.print("Type: {s}\n\n", .{sym.node_type});
            
            // Extract full context like contextCommand does
            const file = try std.fs.cwd().openFile(sym.path, .{});
            defer file.close();
            
            const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
            defer allocator.free(content);
            
            const lang = detectLanguage(sym.path) orelse {
                try stderr.print("Unsupported file type: {s}\n", .{sym.path});
                continue;
            };
            
            const parser = tree_sitter.Parser.create();
            defer tree_sitter.Parser.destroy(parser);
            try tree_sitter.Parser.setLanguage(parser, lang);
            
            const tree = parser.parseString(content, null);
            if (tree) |t| {
                defer t.destroy();
                const root = t.rootNode();
                
                if (findSymbolNode(root, sym.name, sym.line, content)) |symbol_node| {
                    const start_byte = symbol_node.startByte();
                    const end_byte = symbol_node.endByte();
                    const node_source = content[start_byte..end_byte];
                    
                    // Extract documentation
                    if (extractDocumentation(symbol_node, content, allocator)) |docs| {
                        defer allocator.free(docs);
                        try stdout.print("{s}\n", .{docs});
                    }
                    
                    // Print the symbol definition
                    try stdout.print("{s}\n", .{node_source});
                }
            }
            
            if (symbols.len > 1) {
                try stdout.print("\n{s}\n", .{"-" ** 60});
            }
        }
        return;
    }
    
    // Regular output with optional enhancements
    for (symbols) |sym| {
        // Print match info based on setting
        if (match_info == .always) {
            try stdout.print("[exact:100]\t", .{});
        }
        
        // Basic ctags format
        try stdout.print("{s}\t{s}\t{d}\t{s}", .{ sym.name, sym.path, sym.line, sym.node_type });
        
        // Add reference count if requested
        if (with_refs) {
            const refs_count = try db.getReferencesCount(sym.name);
            try stdout.print("\trefs: {d}", .{refs_count});
        }
        
        // Add dependency count if requested
        if (with_deps) {
            const deps_count = try db.getDependenciesCount(sym.name);
            try stdout.print("\tdeps: {d}", .{deps_count});
        }
        
        try stdout.print("\n", .{});
        
        // Show line context if requested
        if (with_context) {
            const file = try std.fs.cwd().openFile(sym.path, .{});
            defer file.close();
            
            const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
            defer allocator.free(content);
            
            // Find the line
            var line_count: u32 = 1;
            var line_start: usize = 0;
            var line_end: usize = 0;
            
            for (content, 0..) |char, idx| {
                if (char == '\n') {
                    if (line_count == sym.line) {
                        line_end = idx;
                        break;
                    }
                    line_count += 1;
                    line_start = idx + 1;
                }
            }
            
            // Handle last line without newline
            if (line_count == sym.line and line_end == 0) {
                line_end = content.len;
            }
            
            if (line_start < content.len and line_end > line_start) {
                const line_content = content[line_start..line_end];
                try stdout.print("  {s}\n", .{line_content});
            }
        }
    }
}

fn refsCommand(allocator: std.mem.Allocator, symbol_name: []const u8, with_context: bool, include_defs: bool) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    const references = try db.findReferences(symbol_name, include_defs, allocator);
    defer @import("database.zig").deinitReferences(references, allocator);
    
    if (references.len == 0) {
        stderr.print("No references to '{s}' found\n", .{symbol_name}) catch {};
        return;
    }
    
    // Print header
    if (include_defs) {
        stdout.print("References and definitions of '{s}':\n", .{symbol_name}) catch {};
    } else {
        stdout.print("References to '{s}':\n", .{symbol_name}) catch {};
    }
    
    // Print references
    for (references) |ref| {
        if (ref.is_definition) {
            stdout.print("[DEF] ", .{}) catch {};
        }
        
        if (with_context and ref.context != null) {
            stdout.print("{s}:{d}:{d}\n", .{ ref.path, ref.line, ref.column }) catch {};
            stdout.print("    {s}\n", .{ref.context.?}) catch {};
            
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
                    stdout.print(" ", .{}) catch {};
                }
                // Print carets for the length of the symbol name
                j = 0;
                while (j < symbol_name.len) : (j += 1) {
                    stdout.print("^", .{}) catch {};
                }
                stdout.print("\n", .{}) catch {};
            }
        } else {
            stdout.print("{s}:{d}:{d}\n", .{ ref.path, ref.line, ref.column }) catch {};
        }
    }
}

fn contextCommand(allocator: std.mem.Allocator, symbol_name: []const u8) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    // Find symbol definitions
    const symbols = try db.findSymbol(symbol_name, allocator);
    defer @import("database.zig").deinitSymbols(symbols, allocator);
    
    if (symbols.len == 0) {
        stderr.print("Symbol '{s}' not found\n", .{symbol_name}) catch {};
        return;
    }
    
    // For each symbol definition, extract full context
    for (symbols) |sym| {
        stdout.print("// {s} ({s}) at {s}:{d}\n", .{ sym.name, sym.node_type, sym.path, sym.line }) catch {};
        stdout.print("// " ++ "=" ** 60 ++ "\n", .{}) catch {};
        
        // Read the file content
        const file_content = std.fs.cwd().readFileAlloc(allocator, sym.path, 1024 * 1024 * 10) catch |err| {
            stderr.print("Error reading file {s}: {}\n", .{ sym.path, err }) catch {};
            continue;
        };
        defer allocator.free(file_content);
        
        // Parse the file to get the AST
        const parser = tree_sitter.Parser.create();
        defer parser.destroy();
        
        const language = detectLanguage(sym.path) orelse {
            stderr.print("Unsupported file type: {s}\n", .{sym.path}) catch {};
            continue;
        };
        parser.setLanguage(language) catch |err| {
            stderr.print("Error setting language: {}\n", .{err}) catch {};
            continue;
        };
        
        const tree = parser.parseString(file_content, null);
        if (tree) |t| {
            defer t.destroy();
            
            const root_node = t.rootNode();
            
            // Find the symbol node and extract its full context
            if (findSymbolNode(root_node, sym.name, sym.line, file_content)) |symbol_node| {
                // Extract documentation comments if any
                if (extractDocumentation(symbol_node, file_content, allocator)) |docs| {
                    defer allocator.free(docs);
                    stdout.print("{s}\n", .{docs}) catch {};
                }
                
                // Extract the full symbol definition
                const start = symbol_node.startByte();
                const end = symbol_node.endByte();
                const definition = file_content[start..end];
                
                stdout.print("{s}\n\n", .{definition}) catch {};
            } else {
                stdout.print("// Unable to extract full context\n\n", .{}) catch {};
            }
        } else {
            stderr.print("// Error parsing file\n\n", .{}) catch {};
        }
    }
}

fn findSymbolNode(node: tree_sitter.Node, target_name: []const u8, target_line: u32, source: []const u8) ?tree_sitter.Node {
    const node_type = node.kind();
    
    // Check if this is a symbol node
    if (isSymbolNode(node_type)) {
        // Try to find the identifier
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                const child_type = child.kind();
                
                // Special handling for Go spec nodes
                if (std.mem.eql(u8, child_type, "type_spec") or
                    std.mem.eql(u8, child_type, "const_spec") or
                    std.mem.eql(u8, child_type, "var_spec")) {
                    // Check inside the spec node
                    var j: u32 = 0;
                    while (j < child.childCount()) : (j += 1) {
                        if (child.child(j)) |spec_child| {
                            if (std.mem.eql(u8, spec_child.kind(), "identifier") or
                                std.mem.eql(u8, spec_child.kind(), "type_identifier")) {
                                const start = spec_child.startByte();
                                const end = spec_child.endByte();
                                const name = source[start..end];
                                const line = spec_child.startPoint().row + 1;
                                
                                if (std.mem.eql(u8, name, target_name) and line == target_line) {
                                    return node;
                                }
                            }
                        }
                    }
                }
                // Direct identifier check
                else if (std.mem.eql(u8, child_type, "identifier") or
                         std.mem.eql(u8, child_type, "type_identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    const name = source[start..end];
                    const line = child.startPoint().row + 1;
                    
                    if (std.mem.eql(u8, name, target_name) and line == target_line) {
                        return node;
                    }
                }
                // C function declarators
                else if (std.mem.eql(u8, child_type, "function_declarator")) {
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        if (std.mem.eql(u8, id.name, target_name) and id.line == target_line) {
                            return node;
                        }
                    }
                }
            }
        }
    }
    
    // Special case for Python assignments
    if (std.mem.eql(u8, node_type, "assignment")) {
        if (node.child(0)) |left| {
            if (std.mem.eql(u8, left.kind(), "identifier")) {
                const start = left.startByte();
                const end = left.endByte();
                const name = source[start..end];
                const line = left.startPoint().row + 1;
                
                if (std.mem.eql(u8, name, target_name) and line == target_line) {
                    return node;
                }
            }
        }
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            if (findSymbolNode(child, target_name, target_line, source)) |found| {
                return found;
            }
        }
    }
    
    return null;
}

fn extractDocumentation(node: tree_sitter.Node, source: []const u8, allocator: std.mem.Allocator) ?[]u8 {
    var docs = std.ArrayList(u8).init(allocator);
    defer docs.deinit();
    
    // Collect all consecutive comment nodes preceding the symbol
    var current_sibling = node.prevSibling();
    var comments_found = false;
    
    // We'll collect comments in reverse order then reverse the result
    var comment_nodes = std.ArrayList(tree_sitter.Node).init(allocator);
    defer comment_nodes.deinit();
    
    while (current_sibling) |sibling| {
        const sibling_type = sibling.kind();
        if (std.mem.eql(u8, sibling_type, "comment") or
            std.mem.eql(u8, sibling_type, "line_comment") or
            std.mem.eql(u8, sibling_type, "block_comment") or
            std.mem.eql(u8, sibling_type, "doc_comment")) {
            comment_nodes.append(sibling) catch break;
            comments_found = true;
            current_sibling = sibling.prevSibling();
        } else {
            // Stop if we hit a non-comment node
            break;
        }
    }
    
    if (!comments_found) {
        // Check parent node for documentation (some languages attach docs to parent)
        if (node.parent()) |parent| {
            current_sibling = parent.prevSibling();
            while (current_sibling) |sibling| {
                const sibling_type = sibling.kind();
                if (std.mem.eql(u8, sibling_type, "comment") or
                    std.mem.eql(u8, sibling_type, "line_comment") or
                    std.mem.eql(u8, sibling_type, "block_comment") or
                    std.mem.eql(u8, sibling_type, "doc_comment")) {
                    comment_nodes.append(sibling) catch break;
                    comments_found = true;
                    current_sibling = sibling.prevSibling();
                } else {
                    break;
                }
            }
        }
    }
    
    if (!comments_found) return null;
    
    // Process comments in the correct order (reverse of how we collected them)
    var i = comment_nodes.items.len;
    while (i > 0) {
        i -= 1;
        const comment_node = comment_nodes.items[i];
        const start = comment_node.startByte();
        const end = comment_node.endByte();
        const comment_text = source[start..end];
        
        if (docs.items.len > 0) {
            docs.append('\n') catch return null;
        }
        docs.appendSlice(comment_text) catch return null;
    }
    
    return docs.toOwnedSlice() catch null;
}

fn extractSymbolDependencies(node: tree_sitter.Node, source: []const u8, context: *DatabaseContext) !void {
    if (context.current_symbol_id == null) return;
    
    // Walk through the symbol body and find all identifiers that could be dependencies
    try extractDependenciesRecursive(node, source, context);
}

fn extractDependenciesRecursive(node: tree_sitter.Node, source: []const u8, context: *DatabaseContext) !void {
    const node_type = node.kind();
    
    // Handle function calls
    if (std.mem.eql(u8, node_type, "call_expression") or
        std.mem.eql(u8, node_type, "function_call_expression") or
        std.mem.eql(u8, node_type, "method_call_expression") or
        std.mem.eql(u8, node_type, "invocation_expression") or
        std.mem.eql(u8, node_type, "call")) {
        
        // Find the function identifier
        if (node.child(0)) |func_node| {
            if (std.mem.eql(u8, func_node.kind(), "identifier") or
                std.mem.eql(u8, func_node.kind(), "field_expression") or
                std.mem.eql(u8, func_node.kind(), "member_expression")) {
                
                const identifier = extractIdentifierName(func_node, source);
                if (identifier) |name| {
                    if (context.current_symbol_id) |symbol_id| {
                        context.db.insertDependency(symbol_id, name, "calls") catch {};
                    }
                }
            }
        }
    }
    
    // Handle type references
    else if (std.mem.eql(u8, node_type, "type_identifier") or
             std.mem.eql(u8, node_type, "type_reference") or
             std.mem.eql(u8, node_type, "named_type")) {
        const start = node.startByte();
        const end = node.endByte();
        const name = source[start..end];
        
        if (context.current_symbol_id) |symbol_id| {
            context.db.insertDependency(symbol_id, name, "uses_type") catch {};
        }
    }
    
    // Handle imports (language-specific)
    else if (std.mem.eql(u8, node_type, "import_statement") or
             std.mem.eql(u8, node_type, "import_declaration") or
             std.mem.eql(u8, node_type, "use_declaration")) {
        // Extract imported symbols
        var i: u32 = 0;
        while (i < node.childCount()) : (i += 1) {
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.kind(), "identifier") or
                    std.mem.eql(u8, child.kind(), "string_literal")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    var name = source[start..end];
                    
                    // Remove quotes from string literals
                    if (name.len > 2 and (name[0] == '"' or name[0] == '\'')) {
                        name = name[1..name.len-1];
                    }
                    
                    if (context.current_symbol_id) |symbol_id| {
                        context.db.insertDependency(symbol_id, name, "imports") catch {};
                    }
                }
            }
        }
    }
    
    // Recurse through children
    var i: u32 = 0;
    while (i < node.childCount()) : (i += 1) {
        if (node.child(i)) |child| {
            try extractDependenciesRecursive(child, source, context);
        }
    }
}

fn extractIdentifierName(node: tree_sitter.Node, source: []const u8) ?[]const u8 {
    const node_type = node.kind();
    
    if (std.mem.eql(u8, node_type, "identifier")) {
        const start = node.startByte();
        const end = node.endByte();
        return source[start..end];
    }
    
    // For field/member expressions, get the last identifier
    if (std.mem.eql(u8, node_type, "field_expression") or
        std.mem.eql(u8, node_type, "member_expression")) {
        var i = node.childCount();
        while (i > 0) {
            i -= 1;
            if (node.child(i)) |child| {
                if (std.mem.eql(u8, child.kind(), "identifier") or
                    std.mem.eql(u8, child.kind(), "property_identifier") or
                    std.mem.eql(u8, child.kind(), "field_identifier")) {
                    const start = child.startByte();
                    const end = child.endByte();
                    return source[start..end];
                }
            }
        }
    }
    
    return null;
}

fn depsCommand(allocator: std.mem.Allocator, symbol_name: []const u8) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    // Find dependencies for the symbol
    const dependencies = try db.findDependencies(symbol_name, allocator);
    defer @import("database.zig").deinitDependencies(dependencies, allocator);
    
    if (dependencies.len == 0) {
        stderr.print("No dependencies found for '{s}'\n", .{symbol_name}) catch {};
        return;
    }
    
    // Group dependencies by type
    stdout.print("Dependencies of '{s}':\n", .{symbol_name}) catch {};
    stdout.print("=" ** 40 ++ "\n", .{}) catch {};
    
    var current_type: ?[]const u8 = null;
    for (dependencies) |dep| {
        if (current_type == null or !std.mem.eql(u8, current_type.?, dep.dependency_type)) {
            current_type = dep.dependency_type;
            stdout.print("\n{s}:\n", .{dep.dependency_type}) catch {};
        }
        stdout.print("  - {s}\n", .{dep.depends_on}) catch {};
    }
}

fn mapCommand(allocator: std.mem.Allocator, entry_point: ?[]const u8, max_depth: u32) !void {
    var db = try Database.init("wat.db");
    defer db.deinit();
    
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    
    // Find entry points
    var symbols_to_process = std.ArrayList(MapNode).init(arena_allocator);
    defer symbols_to_process.deinit();
    
    if (entry_point) |ep| {
        // Start from specified entry point
        const symbols = try db.findSymbol(ep, arena_allocator);
        if (symbols.len == 0) {
            stderr.print("Entry point '{s}' not found\n", .{ep}) catch {};
            return;
        }
        
        for (symbols) |sym| {
            try symbols_to_process.append(.{
                .symbol = sym.name,
                .signature = try extractSignature(arena_allocator, &db, sym),
                .depth = 0,
            });
        }
    } else {
        // Find main functions
        const entry_points = try db.findEntryPoints(arena_allocator);
        if (entry_points.len == 0) {
            stderr.print("No entry points found\n", .{}) catch {};
            return;
        }
        
        // Group entry points by language
        stdout.print("Found {} entry points:\n", .{entry_points.len}) catch {};
        stdout.print("{s}\n", .{"-" ** 60}) catch {};
        
        for (entry_points, 0..) |sym, i| {
            stdout.print("{d}. [{s}] {s} in {s}:{d}\n", .{ 
                i + 1, 
                sym.language, 
                sym.name, 
                sym.path, 
                sym.line 
            }) catch {};
        }
        stdout.print("\n", .{}) catch {};
        
        // Process all entry points
        for (entry_points) |sym| {
            try symbols_to_process.append(.{
                .symbol = sym.name,
                .signature = try extractSignature(arena_allocator, &db, sym),
                .depth = 0,
            });
        }
    }
    
    // Print header
    stdout.print("Call Map:\n", .{}) catch {};
    stdout.print("=" ** 60 ++ "\n", .{}) catch {};
    
    // Process call tree
    var call_stack = std.ArrayList([]const u8).init(arena_allocator);
    defer call_stack.deinit();
    
    for (symbols_to_process.items) |node| {
        try printCallTree(arena_allocator, &db, node.symbol, node.signature, 0, max_depth, &call_stack);
    }
}

const MapNode = struct {
    symbol: []const u8,
    signature: ?[]const u8,
    depth: u32,
};

fn printCallTree(
    allocator: std.mem.Allocator,
    db: *Database,
    symbol: []const u8,
    signature: ?[]const u8,
    depth: u32,
    max_depth: u32,
    call_stack: *std.ArrayList([]const u8),
) !void {
    // Check if already in current call stack to detect cycles
    var is_cycle = false;
    for (call_stack.items) |stack_symbol| {
        if (std.mem.eql(u8, stack_symbol, symbol)) {
            is_cycle = true;
            break;
        }
    }
    
    // Add to call stack
    if (!is_cycle) {
        try call_stack.append(symbol);
    }
    
    // Print indentation
    var i: u32 = 0;
    while (i < depth) : (i += 1) {
        stdout.print("│  ", .{}) catch {};
    }
    
    if (depth > 0) {
        stdout.print("├─ ", .{}) catch {};
    }
    
    // Print symbol with signature
    if (signature) |sig| {
        stdout.print("{s}{s}", .{ symbol, sig }) catch {};
    } else {
        stdout.print("{s}", .{symbol}) catch {};
    }
    
    if (is_cycle) {
        stdout.print(" (cycle detected)\n", .{}) catch {};
        return;
    }
    
    stdout.print("\n", .{}) catch {};
    
    // Check depth limit
    if (depth >= max_depth) {
        i = 0;
        while (i <= depth) : (i += 1) {
            stdout.print("│  ", .{}) catch {};
        }
        stdout.print("└─ ...\n", .{}) catch {};
        if (!is_cycle) {
            _ = call_stack.pop();
        }
        return;
    }
    
    // If it's a cycle, don't process further
    if (is_cycle) {
        return;
    }
    
    // Get dependencies
    const dependencies = db.findDependencies(symbol, allocator) catch {
        _ = call_stack.pop();
        return;
    };
    defer @import("database.zig").deinitDependencies(dependencies, allocator);
    
    // Filter and collect function calls
    var calls = std.ArrayList([]const u8).init(allocator);
    defer calls.deinit();
    
    for (dependencies) |dep| {
        if (std.mem.eql(u8, dep.dependency_type, "calls")) {
            try calls.append(dep.depends_on);
        }
    }
    
    // Process function calls
    for (calls.items) |call| {
        // Try to get signature for the dependency
        const dep_symbols = db.findSymbol(call, allocator) catch {
            try printCallTree(allocator, db, call, null, depth + 1, max_depth, call_stack);
            continue;
        };
        defer @import("database.zig").deinitSymbols(dep_symbols, allocator);
        
        if (dep_symbols.len > 0) {
            const dep_sig = extractSignature(allocator, db, dep_symbols[0]) catch null;
            try printCallTree(allocator, db, call, dep_sig, depth + 1, max_depth, call_stack);
        } else {
            try printCallTree(allocator, db, call, null, depth + 1, max_depth, call_stack);
        }
    }
    
    // Pop from call stack when done
    _ = call_stack.pop();
}

fn extractSignature(allocator: std.mem.Allocator, _: *Database, symbol: @import("database.zig").Symbol) !?[]const u8 {
    // Get the source file content to extract actual signature
    const file = std.fs.cwd().openFile(symbol.path, .{}) catch {
        // If we can't read the file, fall back to generic signature
        return try getGenericSignature(allocator, symbol);
    };
    defer file.close();
    
    // Read a reasonable amount around the symbol line
    const file_size = try file.getEndPos();
    const read_size = @min(file_size, 4096); // Read up to 4KB
    const start_pos = if (symbol.line > 10) (symbol.line - 10) * 80 else 0; // Rough estimate
    
    try file.seekTo(@min(start_pos, file_size));
    const content = try allocator.alloc(u8, read_size);
    defer allocator.free(content);
    _ = try file.read(content);
    
    // Extract signature based on language
    if (std.mem.eql(u8, symbol.language, "python")) {
        return try extractPythonSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "javascript") or 
               std.mem.eql(u8, symbol.language, "typescript")) {
        return try extractJavaScriptSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "go")) {
        return try extractGoSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "rust")) {
        return try extractRustSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "elixir")) {
        return try extractElixirSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "java")) {
        return try extractJavaSignature(allocator, content, symbol);
    } else if (std.mem.eql(u8, symbol.language, "c") or 
               std.mem.eql(u8, symbol.language, "zig")) {
        return try extractCStyleSignature(allocator, content, symbol);
    }
    
    return try getGenericSignature(allocator, symbol);
}

fn getGenericSignature(allocator: std.mem.Allocator, symbol: @import("database.zig").Symbol) !?[]const u8 {
    if (std.mem.indexOf(u8, symbol.node_type, "function") != null or
        std.mem.indexOf(u8, symbol.node_type, "method") != null) {
        return try allocator.dupe(u8, "()");
    }
    return null;
}

// Simplified signature extractors - just show parameter count for now
fn extractPythonSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual Python signatures
    return try allocator.dupe(u8, "(...)");
}

fn extractJavaScriptSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual JavaScript signatures
    return try allocator.dupe(u8, "(...)");
}

fn extractGoSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual Go signatures
    return try allocator.dupe(u8, "() error");
}

fn extractRustSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual Rust signatures
    return try allocator.dupe(u8, "() -> Result");
}

fn extractElixirSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual Elixir signatures
    return try allocator.dupe(u8, "/0");
}

fn extractJavaSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual Java signatures
    return try allocator.dupe(u8, "()");
}

fn extractCStyleSignature(allocator: std.mem.Allocator, content: []const u8, symbol: @import("database.zig").Symbol) ![]const u8 {
    _ = content;
    _ = symbol;
    // TODO: Parse actual C/Zig signatures
    return try allocator.dupe(u8, "()");
}

const DatabaseContext = struct {
    db: *Database,
    file_id: i64,
    allocator: std.mem.Allocator,
    current_symbol_id: ?i64 = null,
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
                    
                    const symbol_id = try context.db.insertSymbol(context.file_id, name, line, node_type);
                    
                    // Also store as a definition reference
                    const context_line = getLineContext(source, start, end);
                    try context.db.insertReference(context.file_id, name, line, column, context_line, true);
                    
                    // Extract dependencies for this symbol
                    context.current_symbol_id = symbol_id;
                    try extractSymbolDependencies(node, source, context);
                    context.current_symbol_id = null;
                    
                    found = true;
                    break;
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "function_definition")) {
                    // C function definitions have function_declarator child
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        const symbol_id = try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        
                        // Extract dependencies for this symbol
                        context.current_symbol_id = symbol_id;
                        try extractSymbolDependencies(node, source, context);
                        context.current_symbol_id = null;
                        
                        found = true;
                        break;
                    }
                } else if (std.mem.eql(u8, child_type, "init_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C variable declarations
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        _ = try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                    }
                } else if (std.mem.eql(u8, child_type, "function_declarator") and
                           std.mem.eql(u8, node_type, "declaration")) {
                    // C function declarations (prototypes)
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        _ = try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
                        found = true;
                    }
                } else if ((std.mem.eql(u8, child_type, "parenthesized_declarator") or
                            std.mem.eql(u8, child_type, "pointer_declarator")) and
                           std.mem.eql(u8, node_type, "type_definition")) {
                    // C typedef for function pointers
                    if (extractIdentifierFromDeclarator(child, source)) |id| {
                        _ = try context.db.insertSymbol(context.file_id, id.name, id.line, node_type);
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
                
                _ = try context.db.insertSymbol(context.file_id, name, line, "assignment");
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
                            
                            _ = try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                    
                    _ = try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                
                _ = try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                            
                            _ = try context.db.insertSymbol(context.file_id, name, line, node_type);
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
                                    _ = try context.db.insertSymbol(context.file_id, name, line, call_type);
                                } else if (std.mem.eql(u8, name_node.kind(), "identifier") or
                                           std.mem.eql(u8, name_node.kind(), "atom")) {
                                    const n_start = name_node.startByte();
                                    const n_end = name_node.endByte();
                                    var name = source[n_start..n_end];
                                    if (name.len > 0 and name[0] == ':') {
                                        name = name[1..];
                                    }
                                    const line = name_node.startPoint().row + 1;
                                    _ = try context.db.insertSymbol(context.file_id, name, line, call_type);
                                } else if (std.mem.eql(u8, name_node.kind(), "call")) {
                                    if (name_node.child(0)) |func_name| {
                                        if (std.mem.eql(u8, func_name.kind(), "identifier")) {
                                            const n_start = func_name.startByte();
                                            const n_end = func_name.endByte();
                                            const name = source[n_start..n_end];
                                            const line = func_name.startPoint().row + 1;
                                            _ = try context.db.insertSymbol(context.file_id, name, line, call_type);
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
                                                        _ = try context.db.insertSymbol(context.file_id, id_value, line, "id_attribute");
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
                
                _ = try context.db.insertSymbol(context.file_id, name, line, parent_type);
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