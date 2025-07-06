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
./zig-out/bin/wat myfile.js   # JavaScript
./zig-out/bin/wat myfile.ts   # TypeScript
./zig-out/bin/wat myfile.rs   # Rust
./zig-out/bin/wat myfile.c    # C
./zig-out/bin/wat myfile.h    # C headers
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

### Phase 2: Multi-Language Support (In Progress)
- [x] Bundle tree-sitter grammars for: Go, Python, JavaScript, TypeScript, Rust, C
- [ ] Bundle tree-sitter grammars for: Java, Elixir, HTML
- [x] Language auto-detection based on file extensions  
- [x] Language-specific symbol extraction rules
- [x] Unified symbol output format across languages

**Current Status:**
- ✅ Zig (built-in) - functions, types, variables, tests
- ✅ Go (v0.23.4) - functions, types, constants, variables
- ✅ Python (v0.23.6) - functions, classes, assignments (includes scanner.c)
- ✅ JavaScript (v0.23.1) - functions, classes, methods, const/let/var (includes scanner.c)
- ✅ TypeScript (v0.23.2) - interfaces, type aliases, enums, namespaces, all JS features (includes scanner.c)
- ✅ Rust (v0.24.0) - functions, structs, enums, traits, impl blocks, macros, modules (includes scanner.c)
- ✅ C (v0.24.1) - functions, structs, enums, unions, typedefs, macros, variables (no scanner.c)
- 📋 Java - Planned
- 📋 Elixir - Planned
- 📋 HTML - Planned

Binary size: ~9.8MB (grows ~0.5-1.3MB per language)

### Phase 3: Persistent Index
- [ ] SQLite-based symbol database
  - Files table: track path, last_modified, language
  - Symbols table: name, line, node_type with file reference
  - Indexed by symbol name for fast lookups
- [ ] Index entire repositories with `wat index <path>`
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
- [ ] Consider plugin architecture after 10+ languages for maintainability

### Phase 6: LLM-Optimized Features
- [ ] Context window management
- [ ] Token-efficient output formats (JSON, compact formats)
- [ ] Token count estimation for extracted context
- [ ] Semantic context expansion
- [ ] API for tool integration (REST/gRPC)
- [ ] LSP bridge for IDE integration (optional)

## Architecture

```
wat
├── Core
│   ├── Language Manager (bundled grammars)
│   ├── Tree-sitter Interface
│   └── CLI Framework
├── Languages
│   ├── Go ✓
│   ├── Elixir
│   ├── Java ✓
│   ├── Python ✓
│   ├── JavaScript ✓
│   ├── TypeScript ✓
│   ├── Rust ✓
│   ├── Zig ✓
│   ├── HTML
│   └── C ✓
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
- Performance optimizations (parallel processing, streaming)
- Query interface design
- Testing on real-world codebases
- Error handling improvements

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

#### 10. Update Documentation

Update the README.md:
- Add the language to the "Current Features" usage examples
- Update the Phase 2 progress with a checkmark
- Add the language to the "Current Status" list with version info
- Update the binary size if it's grown significantly

#### 11. Test and Commit

Run `make test` to ensure everything works, then commit with a descriptive message that includes:
- Language version added
- Whether it needs scanner.c
- What symbol types are supported
- Binary size impact

## Continuing Development

If you're picking up development in a new Claude Code instance:

### Quick Status Check
```bash
# See what languages are supported
./zig-out/bin/wat tests/fixtures/simple.zig  # Should work
./zig-out/bin/wat tests/fixtures/simple.go   # Should work
./zig-out/bin/wat tests/fixtures/simple.py   # Should work
./zig-out/bin/wat tests/fixtures/simple.js   # Should work
./zig-out/bin/wat tests/fixtures/simple.ts   # Should work
./zig-out/bin/wat tests/fixtures/simple.rs   # Should work
./zig-out/bin/wat tests/fixtures/simple.c    # Should work

# Run tests
make test  # Should show all 7 languages passing

# Check binary size
ls -lh ./zig-out/bin/wat  # Should be ~9.8MB with 7 languages
```

### Next Steps
1. ~~**TypeScript** is next~~ ✅ Complete!
   - Added scanner.c support
   - Supports .ts and .tsx extensions
   - Includes interfaces, type aliases, enums, namespaces
2. ~~**Rust** is next~~ ✅ Complete!
   - Added support for structs, enums, traits, impl blocks
   - Includes scanner.c support
   - Extracts macros and modules
3. ~~**C** is next for foundational support~~ ✅ Complete!
   - Simpler grammar (no scanner.c needed)
   - Supports .c and .h files
   - Extracts functions, structs, unions, enums, typedefs, macros, variables
4. Remember to check for scanner.c files (Python and JS have them)
5. Each language adds ~0.5-1.3MB to binary size
6. Keep the "extract everything" philosophy - include private methods, local variables, etc.

### Key Files to Know
- `src/main.zig` - Language detection and symbol extraction logic
- `build.zig` - Grammar compilation configuration  
- `build.zig.zon` - Grammar dependencies
- `tests/test_smoke.sh` - Test script that verifies all languages work
- `tests/fixtures/simple.*` - Test files for each language

### Design Decisions Made
- Extract ALL symbols (including `__init__`, local variables, etc.)
- Use simple tab-separated output format
- Bundle all grammars into single binary (no plugins)
- Support common file extensions (.js/.mjs, etc.)

## License

TODO: Add license
