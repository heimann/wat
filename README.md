# wat - Tree-sitter based code analysis tool

A lightweight, plugin-based code analysis tool that uses tree-sitter to build fast, accurate symbol indexes for codebases. Designed to provide LLMs and command-line users with precise code context without the overhead of full language servers.

You can think of wat like a modern ctags replacement, built on top of tree-sitter.

## Vision

While LSPs are excellent for human developers working in IDEs, LLMs and automation tools need something different:

- **Fast, deterministic symbol lookup** - No server startup overhead
- **Surgical context extraction** - Get exactly the code context needed
- **Bundled language support** - Works with 10+ languages out of the box
- **Scriptable** - Easy to integrate into any workflow

By bundling common languages directly, `wat` provides instant support for most codebases without any configuration or setup required.

`wat` is also very useful for building developer tooling, where you might not want to be running a full LSP.

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

This "extract everything" approach is, for now, intentional:

- Matches traditional ctags behavior
- LLMs benefit from seeing implementation details
- Enables comprehensive codebase analysis
- Filtering can be added later if needed

The tool, by default, aims to be a faithful reporter of what's in the code, not a judge of what's "useful".

## Usage (Current)

```bash
# Build the project
make install

# Extract symbols from a single file (prints to stdout)
wat myfile.zig  # Zig
wat myfile.go   # Go
wat myfile.py   # Python
wat myfile.js   # JavaScript
wat myfile.ts   # TypeScript
wat myfile.rs   # Rust
wat myfile.c    # C
wat myfile.h    # C headers
wat myfile.java # Java
wat myfile.ex   # Elixir
wat myfile.exs  # Elixir scripts
wat myfile.html # HTML (extracts id attributes)

# Index a directory (creates wat.db in current directory)
wat index         # Indexes current directory (respects .gitignore)
wat index src/    # Index specific directory
wat index .

# Find symbols in the indexed database
wat find main
wat find parseConfig

# Enhanced find with additional information
wat find Database --with-context       # Show line of code
wat find Database --with-refs          # Show reference count
wat find Database --with-deps          # Show dependency count
wat find Database --full-context       # Show full definition with docs

# Fuzzy matching (automatic when no exact match found)
wat find Data                          # Auto-fuzzy: finds Database, DatabaseError, etc.
wat find init --fuzzy                  # Force fuzzy: finds init, initialize, initConfig
wat find base --fuzzy                  # Force fuzzy: finds Database, database, base_url

# Strict mode (disable automatic fuzzy fallback)
wat find Data --strict                 # No match: returns error if not found exactly

# Control match info column for consistent output
wat find Database --match-info always  # Always show [exact:100] column
wat find Data --match-info never       # Never show match type column
wat find Data --match-info smart       # Default: show only for fuzzy matches

# Interactive fuzzy finder with real-time search
wat find --interactive                # Opens TUI with fuzzy search
wat find --interactive --action "code -g {file}:{line}"  # Custom editor
wat find --interactive --action "grep -n {name} {file}"  # Custom action

# Combine multiple flags
wat find main --with-context --with-refs --with-deps
wat find extract --fuzzy --with-context

# Find references to symbols
wat refs Database
wat refs parseString

# Show references with code context
wat refs detectLanguage --with-context

# Include definitions in reference results
wat refs detectLanguage --include-defs

# Both flags combined
wat refs detectLanguage --with-context --include-defs

# Get full context of symbol definitions with documentation
wat context Database
wat context myFunction

# Show what a symbol depends on
wat deps processFile
wat deps Database

# Show call tree structure of the application
wat map
wat map --entry processFile --depth 3
wat map --entry main --depth 5
```

## Advanced Features

### Interactive Fuzzy Finder

The `wat find --interactive` command provides a terminal UI for real-time symbol search:

```bash
# Launch interactive finder with default editor
wat find --interactive

# Use Visual Studio Code
wat find --interactive --action "code -g {file}:{line}"

# Use custom command with placeholders
wat find --interactive --action "echo Found {name} at {file}:{line}"
```

Features:

- Real-time fuzzy search as you type
- Arrow keys for navigation (↑/↓)
- Enter to select and execute action
- ESC or Ctrl-C to cancel
- Color-coded match types:
  - Green [exact:100] - Exact matches
  - Yellow [prefix:80] - Prefix matches
  - Cyan [suffix:60] - Suffix matches
  - Gray [contains:40] - Contains matches
- Viewport scrolling for large result sets
- Shows match count and navigation help

The action template supports placeholders:

- `{file}` - Full path to the file
- `{line}` - Line number of the symbol
- `{name}` - Symbol name

### Call Tree Visualization

The `wat map` command shows the call hierarchy of your application:

```bash
# Show full call tree starting from main()
wat map

# Start from a specific function
wat map --entry processFile

# Limit depth to avoid deep recursion
wat map --depth 3

# Combine options
wat map --entry handleRequest --depth 5
```

Example output:

```
Call Map:
============================================================
main()
│  ├─ parseArgs()
│  ├─ Database.init()
│  │  ├─ sqlite3_open()
│  │  └─ createTables()
│  └─ processCommand()
│     ├─ indexDirectory()
│     │  └─ processFile()
│     └─ findSymbol()
```

## Current Status

**What's Working:**

- Symbol extraction from 10 languages (Zig, Go, Python, JavaScript, TypeScript, Rust, C, Java, Elixir, HTML)
- Persistent SQLite database for fast symbol lookups
- Incremental indexing based on file modification times
- Reference tracking with code context
- Rich output formatting with `--with-context` flag
- Full context extraction with documentation comments
- Dependency analysis showing what symbols depend on
- Fuzzy matching with `--fuzzy` flag for finding symbols with partial names

**Recent Additions:**

- Enhanced `wat refs` command with context display and definition tracking
- Symbol definitions stored as special references
- Caret indicators showing exact symbol location in code
- Ability to include/exclude definitions in reference results
- `wat context` command shows full symbol definitions with documentation comments
- `wat deps` command analyzes and displays symbol dependencies
- `wat map` command shows call tree structure of the application
- Fuzzy matching support with `--fuzzy` flag for partial name matches (prefix, suffix, contains)
- Interactive fuzzy finder with `--interactive` flag for real-time search and navigation

## Roadmap

### Phase 1: Core Infrastructure ✅

- [x] Basic tree-sitter integration
- [x] Symbol extraction for Zig
- [x] Command-line interface

### Phase 2: Multi-Language Support ✅

- [x] Bundle tree-sitter grammars for: Go, Python, JavaScript, TypeScript, Rust, C, Java, Elixir, HTML
- [x] Language auto-detection based on file extensions
- [x] Language-specific symbol extraction rules
- [x] Unified symbol output format across languages

**Language Support:**

- ✅ Zig (built-in) - functions, types, variables, tests
- ✅ Go (v0.23.4) - functions, types, constants, variables
- ✅ Python (v0.23.6) - functions, classes, assignments (includes scanner.c)
- ✅ JavaScript (v0.23.1) - functions, classes, methods, const/let/var (includes scanner.c)
- ✅ TypeScript (v0.23.2) - interfaces, type aliases, enums, namespaces, all JS features (includes scanner.c)
- ✅ Rust (v0.24.0) - functions, structs, enums, traits, impl blocks, macros, modules (includes scanner.c)
- ✅ C (v0.24.1) - functions, structs, enums, unions, typedefs, macros, variables (no scanner.c)
- ✅ Java (v0.23.5) - classes, interfaces, methods, fields, constructors, enums, enum constants (no scanner.c)
- ✅ Elixir (v0.3.4) - modules, functions (def/defp), macros, protocols, implementations (includes scanner.c)
- ✅ HTML (v0.23.2) - extracts id attributes from elements (includes scanner.c)

Binary size: ~14MB with 10 languages (grows ~0.5-1.3MB per language)

### Phase 3: Persistent Index ✅

- [x] SQLite-based symbol database
  - Files table: track path, last_modified, language
  - Symbols table: name, line, node_type with file reference
  - Refs table: track all symbol references with context
  - Indexed by symbol name for fast lookups
- [x] Index entire repositories with `wat index [path]`
- [x] Incremental updates for changed files
- [x] Fast symbol queries with `wat find <symbol>`
- [x] Respects `.gitignore` files to exclude dependencies and build artifacts
- [x] Default to current directory when no path specified

**Current Implementation:**

- Database is stored as `wat.db` in the current working directory
- Commands must be run from the same directory to access the same database
- References are extracted with full line context for rich display
- Symbol definitions are also stored as special references
- Automatically ignores common directories: deps, \_build, node_modules, target, etc.
- TODO: Make database location configurable (e.g., `--db` flag, project root detection, or ~/.wat/)

### Phase 4: Smart Context Extraction ✅

- [x] `wat find <symbol>` - Find symbol definition with automatic fuzzy matching
  - `--with-context` - Show line of code containing symbol
  - `--with-refs` - Show count of references
  - `--full-context` - Show full symbol definition with documentation
  - `--with-deps` - Show count of dependencies
  - `--fuzzy` - Force fuzzy matching (automatic when no exact match)
  - `--strict` - Disable automatic fuzzy matching fallback
  - `--match-info <mode>` - Control match type column: smart (default), always, never
  - `--interactive` - Launch interactive TUI fuzzy finder
  - `--action <cmd>` - Custom action template for interactive mode (default: $EDITOR)
- [x] `wat refs <symbol>` - Find all references
  - `--with-context` - Show line of code with caret indicators
  - `--include-defs` - Include definitions marked with [DEF]
- [x] `wat context <symbol>` - Get symbol with smart context (full function/type definition with documentation)
- [x] `wat deps <symbol>` - Show symbol dependencies (calls, type usage, imports)
- [x] `wat map` - Show call tree structure of the application
  - `--entry` - Specify entry point (default: main)
  - `--depth` - Limit tree depth (default: 10)

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
│   ├── Elixir ✓
│   ├── Java ✓
│   ├── Python ✓
│   ├── JavaScript ✓
│   ├── TypeScript ✓
│   ├── Rust ✓
│   ├── Zig ✓
│   ├── HTML ✓
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
- **Small footprint** - ~13MB binary with 9 languages, targeting ~30MB with 10+ languages

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

## Installation

### Quick Install (Recommended)

```bash
# Build and install to ~/.local/bin
make install

# Or use the install script
./install.sh
```

### Manual Installation Options

```bash
# Option 1: Copy binary to ~/.local/bin
mkdir -p ~/.local/bin
cp ./zig-out/bin/wat ~/.local/bin/

# Option 2: Create a symlink (great for development)
ln -sf $(pwd)/zig-out/bin/wat ~/.local/bin/wat

# Option 3: Install system-wide
sudo cp ./zig-out/bin/wat /usr/local/bin/
```

### Other Make Targets

```bash
make install         # Build release version and install
make install-debug   # Install debug build
make install-link    # Install as symlink (for development)
make uninstall      # Remove installed binary
```

After installation, make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$PATH:$HOME/.local/bin"  # Add to ~/.bashrc or ~/.zshrc
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
./zig-out/bin/wat tests/fixtures/simple.java # Should work
./zig-out/bin/wat tests/fixtures/simple.ex   # Should work
./zig-out/bin/wat tests/fixtures/simple.html # Should work

# Run tests
make test  # Should show all 10 languages passing

# Check binary size
ls -lh ./zig-out/bin/wat  # Should be ~14MB with 10 languages
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

MIT License - see [LICENSE](LICENSE) file for details.
