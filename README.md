# wat - Tree-sitter based code analysis tool

A lightweight code analysis tool that uses tree-sitter to build fast, accurate symbol indexes for codebases. Designed to provide LLMs and command-line users with precise code context without the overhead of full language servers.

## Vision

While LSPs are excellent for human developers working in IDEs, LLMs and automation tools need something different:
- **Fast, deterministic symbol lookup** - No server startup overhead
- **Surgical context extraction** - Get exactly the code context needed
- **Language agnostic** - One tool for many languages via tree-sitter grammars
- **Scriptable** - Easy to integrate into any workflow

## Current Features

- Extract symbols (functions, types, variables) from Zig files
- Simple ctags-like output format
- Tree-sitter based parsing for accurate results

## Usage

```bash
# Build the project
zig build

# Extract symbols from a file
./zig-out/bin/wat myfile.zig
```

## Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Basic tree-sitter integration
- [x] Symbol extraction for Zig
- [x] Command-line interface

### Phase 2: Persistent Index
- [ ] SQLite-based symbol database
- [ ] Index entire repositories
- [ ] Incremental updates for changed files
- [ ] Fast symbol queries

### Phase 3: Smart Context Extraction
- [ ] `wat find <symbol>` - Find symbol definition
- [ ] `wat refs <symbol>` - Find all references
- [ ] `wat context <symbol>` - Get symbol with smart context
- [ ] `wat deps <symbol>` - Show symbol dependencies

### Phase 4: Multi-language Support
- [ ] Plugin system for tree-sitter grammars
- [ ] Support for Go, Rust, TypeScript, Python
- [ ] Language-specific symbol extraction rules

### Phase 5: LLM-Optimized Features
- [ ] Context window management
- [ ] Token-efficient output formats
- [ ] Semantic context expansion
- [ ] API for tool integration

## Architecture

```
wat
├── Parser (tree-sitter)
│   └── Language grammars
├── Indexer
│   ├── Symbol extraction
│   └── Database storage
├── Query Engine
│   ├── Symbol lookup
│   ├── Reference finding
│   └── Context building
└── CLI Interface
```

## Why Not Just Use LSP?

LSPs are designed for real-time, interactive development:
- Heavyweight server processes
- Complex protocol overhead
- Focused on IDE features (hover, complete, etc.)
- Often require project configuration

`wat` is designed for batch analysis and context extraction:
- Simple CLI tool
- Fast one-shot operations
- Focused on code structure understanding
- Zero configuration

## Building

Requirements:
- Zig 0.14.1 or later
- Internet connection for initial dependency fetch

```bash
zig build --fetch  # First time only
zig build
```

## Contributing

This project is in early development. Key areas for contribution:
- Adding support for more languages
- Improving symbol extraction accuracy
- Performance optimizations
- Query interface design

## License

TODO: Add license