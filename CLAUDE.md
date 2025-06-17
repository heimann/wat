# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`wat` is a tree-sitter based code analysis tool designed for LLMs and command-line users to extract precise code context without LSP overhead. Currently supports Zig symbol extraction with a planned plugin architecture for multiple languages.

## Build Commands

```bash
# First time - fetch dependencies
zig build --fetch

# Build the project
zig build

# Run on a file
./zig-out/bin/wat <file.zig>

# Build and run
zig build run -- <file.zig>
```

## Architecture

The project uses tree-sitter for parsing and currently has a monolithic structure that will evolve into a plugin-based system:

1. **Tree-sitter Integration**: Dependencies defined in `build.zig.zon`
   - `tree_sitter`: Core tree-sitter Zig bindings
   - `tree_sitter_zig`: Zig language grammar (C parser compiled directly)

2. **Symbol Extraction**: The `extractSymbols` function in `src/main.zig` walks the AST looking for specific node types:
   - `function_declaration`, `test_declaration`
   - `variable_declaration`, `struct_declaration`
   - `enum_declaration`, `union_declaration`
   - `error_set_declaration`

3. **Grammar Linking**: The Zig grammar is linked via:
   - `extern fn tree_sitter_zig()` declaration
   - Direct compilation of `parser.c` from the grammar dependency
   - No modification of cached dependencies - they're compiled as-is

## Key Design Decisions

- **No LSP**: Designed for batch operations and LLM context extraction, not real-time editing
- **Plugin Architecture**: Future versions will allow `wat plugin add <language>` instead of bundling all grammars
- **Tree-sitter Based**: Provides accurate parsing without implementing custom parsers

## Current Limitations

- Only supports Zig files
- No persistent index (re-parses every time)
- Basic ctags-style output only
- No language detection (must be Zig files)