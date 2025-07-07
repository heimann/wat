# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`wat` is a tree-sitter based code analysis tool designed for LLMs and command-line users to extract precise code context without LSP overhead. It's like a modern ctags replacement with advanced features for symbol extraction, reference tracking, and dependency analysis.

## Build Commands

```bash
# First time setup - fetch dependencies
zig build --fetch

# Build the project
zig build

# Build release version (optimized)
zig build -Doptimize=ReleaseSafe

# Install to ~/.local/bin
make install

# Run tests
make test

# Clean build artifacts
make clean
```

## Development Commands

```bash
# Run on a file
./zig-out/bin/wat <file>

# Build and run
zig build run -- <file>

# Install debug build for testing
make install-debug

# Install as symlink (for development)
make install-link
```

## Architecture

The project uses tree-sitter for parsing with support for 10 languages bundled directly into the binary:

1. **Core Components**:
   - `src/main.zig`: Main entry point, language detection, command routing
   - `src/database.zig`: SQLite-based persistent storage for symbols and references
   - `src/gitignore.zig`: .gitignore parsing for filtering files during indexing
   - `src/interactive.zig`: Terminal UI for interactive fuzzy search

2. **Language Support**: Grammars are linked via `build.zig` and `build.zig.zon`:
   - Each language has an `extern fn tree_sitter_<lang>()` declaration
   - Grammar C files are compiled directly from dependencies
   - Languages with scanners: Python, JavaScript, TypeScript, Rust, Elixir, HTML
   - Languages without scanners: Zig, Go, C, Java

3. **Symbol Extraction**: The `extractSymbols` function walks ASTs looking for language-specific node types:
   - Functions, methods, constructors
   - Types, classes, interfaces, structs
   - Variables, constants, fields
   - Language-specific constructs (Go specs, Python assignments, Rust macros, etc.)

## Key Design Principles

- **Extract Everything**: Include private symbols, internal methods, constants - be comprehensive
- **No Configuration**: Works out of the box with zero setup
- **Fast Operations**: Designed for batch processing, not real-time editing
- **Language Bundling**: All grammars compiled into single ~14MB binary

## Testing

Tests are in `tests/test_smoke.sh` which verifies symbol extraction for all supported languages. Test fixtures are in `tests/fixtures/simple.*` - one per language showing all supported symbol types.

## Adding New Languages

See the detailed guide in README.md under "Adding a New Language". Key steps:
1. Add grammar dependency to `build.zig.zon`
2. Update `build.zig` to compile parser.c (and scanner.c if needed)
3. Add extern declaration and file extension detection in `src/main.zig`
4. Identify node types and update `extractSymbols`
5. Create test fixture and update test script

## Database Schema

SQLite database (`wat.db`) structure:
- `files`: path, last_modified, language
- `symbols`: name, file_id, line, node_type
- `refs`: symbol_id, file_id, line, context, is_definition

The database is created in the current working directory and supports incremental updates based on file modification times.