# wat - Tree-sitter based code analysis tool

A lightweight, plugin-based code analysis tool that uses tree-sitter to build fast, accurate symbol indexes for codebases. Designed to provide LLMs and command-line users with precise code context without the overhead of full language servers.

## Vision

While LSPs are excellent for human developers working in IDEs, LLMs and automation tools need something different:
- **Fast, deterministic symbol lookup** - No server startup overhead
- **Surgical context extraction** - Get exactly the code context needed
- **Plugin-based language support** - Install only the languages you need
- **Scriptable** - Easy to integrate into any workflow

The plugin architecture keeps the core tool lightweight while allowing users to add support for exactly the languages they need, similar to how package managers or editor plugins work.

## Current Features

- Extract symbols (functions, types, variables) from Zig files
- Simple ctags-like output format
- Tree-sitter based parsing for accurate results

## Usage (Current)

```bash
# Build the project
zig build

# Extract symbols from a file (currently Zig only)
./zig-out/bin/wat myfile.zig
```

## Usage (Future)

```bash
# Install wat
wat install

# Add language support
wat plugin add zig
wat plugin add rust
wat plugin add typescript

# Index a project
wat index .

# Query symbols
wat find MyFunction
wat refs MyStruct
wat context parseConfig --lines=10
```

## Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Basic tree-sitter integration
- [x] Symbol extraction for Zig
- [x] Command-line interface

### Phase 2: Plugin System
- [ ] Plugin architecture design
- [ ] Plugin manifest format
- [ ] Dynamic loading of tree-sitter grammars
- [ ] Plugin installation/removal commands
- [ ] Plugin repository/registry

### Phase 3: Persistent Index
- [ ] SQLite-based symbol database
- [ ] Index entire repositories
- [ ] Incremental updates for changed files
- [ ] Fast symbol queries

### Phase 4: Smart Context Extraction
- [ ] `wat find <symbol>` - Find symbol definition
- [ ] `wat refs <symbol>` - Find all references
- [ ] `wat context <symbol>` - Get symbol with smart context
- [ ] `wat deps <symbol>` - Show symbol dependencies

### Phase 5: Language Plugins
- [ ] Create plugin template/SDK
- [ ] Core language plugins: Go, Rust, TypeScript, Python
- [ ] Language-specific symbol extraction rules
- [ ] Community plugin repository

### Phase 6: LLM-Optimized Features
- [ ] Context window management
- [ ] Token-efficient output formats
- [ ] Semantic context expansion
- [ ] API for tool integration

## Architecture

```
wat
├── Core
│   ├── Plugin Manager
│   ├── Tree-sitter Interface
│   └── CLI Framework
├── Indexer
│   ├── Symbol extraction
│   └── Database storage
├── Query Engine
│   ├── Symbol lookup
│   ├── Reference finding
│   └── Context building
└── Plugins (~/.wat/plugins/)
    ├── zig/
    │   ├── grammar.so
    │   ├── queries.scm
    │   └── manifest.json
    └── rust/
        ├── grammar.so
        ├── queries.scm
        └── manifest.json
```

### Plugin Structure

Each language plugin provides:
- **grammar.so** - Compiled tree-sitter grammar
- **queries.scm** - Tree-sitter queries for symbol extraction
- **manifest.json** - Plugin metadata (version, dependencies, etc.)

Plugins are installed to `~/.wat/plugins/` and loaded dynamically at runtime.

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