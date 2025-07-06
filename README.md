# wat - Tree-sitter based code analysis tool

A lightweight, plugin-based code analysis tool that uses tree-sitter to build fast, accurate symbol indexes for codebases. Designed to provide LLMs and command-line users with precise code context without the overhead of full language servers.

## Vision

While LSPs are excellent for human developers working in IDEs, LLMs and automation tools need something different:
- **Fast, deterministic symbol lookup** - No server startup overhead
- **Surgical context extraction** - Get exactly the code context needed
- **Bundled language support** - Works with 10+ languages out of the box
- **Scriptable** - Easy to integrate into any workflow

By bundling common languages directly, `wat` provides instant support for most codebases without any configuration or setup required.

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
# Index a project
wat index .

# Query symbols
wat find MyFunction
wat refs MyStruct
wat context parseConfig --lines=10
wat deps parseConfig

# Language auto-detection
wat *.rs  # Rust files
wat *.go  # Go files
wat *.ts  # TypeScript files
```

## Roadmap

### Phase 1: Core Infrastructure ✅
- [x] Basic tree-sitter integration
- [x] Symbol extraction for Zig
- [x] Command-line interface

### Phase 2: Multi-Language Support
- [ ] Bundle tree-sitter grammars for: Go, Elixir, Java, Python, JavaScript, TypeScript, Rust, Zig, HTML, C
- [ ] Language auto-detection based on file extensions
- [ ] Language-specific symbol extraction rules
- [ ] Unified symbol output format across languages

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

### Phase 5: Extended Language Support
- [ ] Add more languages based on user demand
- [ ] Support for configuration files (YAML, TOML, JSON)
- [ ] Support for markup languages (Markdown, AsciiDoc)
- [ ] Custom language definitions via config files

### Phase 6: LLM-Optimized Features
- [ ] Context window management
- [ ] Token-efficient output formats
- [ ] Semantic context expansion
- [ ] API for tool integration

## Architecture

```
wat
├── Core
│   ├── Language Manager (bundled grammars)
│   ├── Tree-sitter Interface
│   └── CLI Framework
├── Languages
│   ├── Go
│   ├── Elixir
│   ├── Java
│   ├── Python
│   ├── JavaScript
│   ├── TypeScript
│   ├── Rust
│   ├── Zig
│   ├── HTML
│   └── C
├── Indexer
│   ├── Symbol extraction
│   └── Database storage
└── Query Engine
    ├── Symbol lookup
    ├── Reference finding
    └── Context building
```

### Bundled Languages

All language support is compiled directly into the binary:
- **Zero configuration** - Works out of the box
- **Fast startup** - No dynamic loading overhead
- **Reliable** - No missing dependencies
- **Small footprint** - ~30MB binary with 10 languages

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