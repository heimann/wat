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

- Extract symbols (functions, types, variables) from multiple languages
- Simple ctags-like output format  
- Tree-sitter based parsing for accurate results
- Language auto-detection based on file extensions

### Symbol Extraction Philosophy

`wat` extracts **all** symbols it finds, including:
- Private/internal symbols (e.g., Python's `__init__` methods)
- Class constants (shown as assignments in Python)
- Helper functions marked as private

This "extract everything" approach is intentional:
- Matches traditional ctags behavior
- LLMs benefit from seeing implementation details
- Enables comprehensive codebase analysis
- Filtering can be added later if needed

The tool aims to be a faithful reporter of what's in the code, not a judge of what's "useful".

## Usage (Current)

```bash
# Build the project
zig build

# Extract symbols from a file
./zig-out/bin/wat myfile.zig  # Zig
./zig-out/bin/wat myfile.go   # Go
./zig-out/bin/wat myfile.py   # Python
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

### Adding a New Language

To add support for a new language, follow these steps:

#### 1. Find the Grammar

First, get the latest tree-sitter grammar for your language:

```bash
# Find the latest release
gh api repos/tree-sitter/tree-sitter-LANGUAGE/releases/latest | jq -r '.tag_name'

# Get the commit hash for that release
gh api repos/tree-sitter/tree-sitter-LANGUAGE/git/refs/tags/TAG | jq -r '.object.sha'
```

#### 2. Add Grammar Dependency

Add the grammar to `build.zig.zon`:

```zig
.tree_sitter_language = .{
    .url = "git+https://github.com/tree-sitter/tree-sitter-LANGUAGE#COMMIT_HASH",
    // Leave hash empty for now
},
```

#### 3. Update Build Configuration

Add to `build.zig`:

```zig
const tree_sitter_language = b.dependency("tree_sitter_language", .{});
exe.addCSourceFile(.{
    .file = tree_sitter_language.path("src/parser.c"),
    .flags = &.{"-std=c11"},
});
// Check if the language has a scanner.c file (for languages like Python)
// If so, add it too:
exe.addCSourceFile(.{
    .file = tree_sitter_language.path("src/scanner.c"),
    .flags = &.{"-std=c11"},
});
exe.addIncludePath(tree_sitter_language.path("src"));
```

#### 4. Get the Hash

Run `zig build --fetch` to get the hash, then update `build.zig.zon` with it.

#### 5. Add Language Detection

Update `src/main.zig`:

```zig
// Add extern declaration
extern fn tree_sitter_language() callconv(.C) *tree_sitter.Language;

// Add to detectLanguage function
} else if (std.mem.endsWith(u8, file_path, ".ext")) {
    return tree_sitter_language();
```

#### 6. Identify Node Types

Create a test file and enable debug mode to see node types:

```zig
// Temporarily uncomment in extractSymbols:
if (node.isNamed()) {
    std.debug.print("DEBUG: {s}\n", .{node_type});
}
```

Run: `./zig-out/bin/wat test.ext 2>&1 | grep "DEBUG:" | sort | uniq`

#### 7. Add Symbol Extraction

Add the language's node types to the symbol extraction in `extractSymbols`:

```zig
// Language node types
std.mem.eql(u8, node_type, "function_declaration") or  // or whatever the language uses
std.mem.eql(u8, node_type, "class_declaration") or
```

Some languages have special requirements:
- **Go**: Uses spec nodes (`type_spec`, `const_spec`, `var_spec`)
- **Python**: Uses `assignment` nodes for global variables
- Check the grammar's structure and adapt accordingly

#### 8. Create Test Fixture

Create `tests/fixtures/simple.LANGUAGE` with examples of all symbol types the language supports.

#### 9. Update Tests

Add to `tests/test_smoke.sh`:

```bash
echo "Testing LANGUAGE support..."
EXPECTED_LANGUAGE=$(cat <<'EOF'
symbol1	LINE	NODE_TYPE
symbol2	LINE	NODE_TYPE
EOF
)

ACTUAL_LANGUAGE=$(./zig-out/bin/wat tests/fixtures/simple.LANGUAGE 2>&1 | sort)
EXPECTED_LANGUAGE_SORTED=$(echo "$EXPECTED_LANGUAGE" | sort)

if [ "$ACTUAL_LANGUAGE" = "$EXPECTED_LANGUAGE_SORTED" ]; then
    echo "✓ LANGUAGE test passed"
else
    echo "✗ LANGUAGE test failed"
    # ... error output
    exit 1
fi
```

#### 10. Test and Commit

Run `make test` to ensure everything works, then commit with a descriptive message.

## License

TODO: Add license