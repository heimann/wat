const std = @import("std");

pub const GitIgnore = struct {
    allocator: std.mem.Allocator,
    patterns: std.ArrayList(Pattern),
    
    const Self = @This();
    
    const Pattern = struct {
        pattern: []const u8,
        is_negation: bool,
        is_directory: bool,
        is_absolute: bool,
    };
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .patterns = std.ArrayList(Pattern).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.patterns.items) |pattern| {
            self.allocator.free(pattern.pattern);
        }
        self.patterns.deinit();
    }
    
    pub fn loadFromFile(self: *Self, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();
        
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);
        
        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            
            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') continue;
            
            try self.addPattern(trimmed);
        }
    }
    
    pub fn addPattern(self: *Self, pattern: []const u8) !void {
        var is_negation = false;
        var is_directory = false;
        var is_absolute = false;
        var actual_pattern = pattern;
        
        // Check for negation
        if (pattern[0] == '!') {
            is_negation = true;
            actual_pattern = pattern[1..];
        }
        
        // Check if pattern is directory-only
        if (std.mem.endsWith(u8, actual_pattern, "/")) {
            is_directory = true;
            actual_pattern = actual_pattern[0 .. actual_pattern.len - 1];
        }
        
        // Check if pattern is absolute (starts with /)
        if (actual_pattern.len > 0 and actual_pattern[0] == '/') {
            is_absolute = true;
            actual_pattern = actual_pattern[1..];
        }
        
        const pattern_copy = try self.allocator.dupe(u8, actual_pattern);
        try self.patterns.append(.{
            .pattern = pattern_copy,
            .is_negation = is_negation,
            .is_directory = is_directory,
            .is_absolute = is_absolute,
        });
    }
    
    pub fn shouldIgnore(self: *Self, path: []const u8, is_directory: bool) bool {
        var ignored = false;
        
        // Check each pattern in order (later patterns can override earlier ones)
        for (self.patterns.items) |pattern| {
            if (pattern.is_directory and !is_directory) continue;
            
            if (self.matchesPattern(path, pattern)) {
                ignored = !pattern.is_negation;
            }
        }
        
        return ignored;
    }
    
    fn matchesPattern(self: *Self, path: []const u8, pattern: Pattern) bool {
        _ = self;
        
        // Simple pattern matching (can be enhanced with proper glob support)
        if (pattern.is_absolute) {
            // Absolute patterns match from the root
            return matchesSimple(path, pattern.pattern);
        } else {
            // Non-absolute patterns can match anywhere in the path
            if (matchesSimple(path, pattern.pattern)) return true;
            
            // Check if pattern matches any parent directory
            var iter = std.mem.tokenizeScalar(u8, path, '/');
            while (iter.next()) |segment| {
                if (matchesSimple(segment, pattern.pattern)) return true;
            }
            
            // Check if pattern matches the end of the path
            if (std.mem.endsWith(u8, path, pattern.pattern)) return true;
        }
        
        return false;
    }
    
    fn matchesSimple(text: []const u8, pattern: []const u8) bool {
        // Simple glob matching supporting * wildcard
        if (std.mem.indexOf(u8, pattern, "*") == null) {
            // No wildcards, exact match
            return std.mem.eql(u8, text, pattern);
        }
        
        // Handle patterns with wildcards
        if (std.mem.eql(u8, pattern, "*")) return true;
        
        // Handle *.ext patterns
        if (std.mem.startsWith(u8, pattern, "*.")) {
            const ext = pattern[1..];
            return std.mem.endsWith(u8, text, ext);
        }
        
        // Handle prefix* patterns  
        if (std.mem.endsWith(u8, pattern, "*")) {
            const prefix = pattern[0 .. pattern.len - 1];
            return std.mem.startsWith(u8, text, prefix);
        }
        
        // For now, treat other * patterns as simple contains
        const pattern_without_star = std.mem.trim(u8, pattern, "*");
        return std.mem.indexOf(u8, text, pattern_without_star) != null;
    }
};

// Additional patterns to always ignore (similar to git's default ignores)
pub const DEFAULT_IGNORES = [_][]const u8{
    ".git",
    "_build",     // Elixir build directory
    "deps",       // Elixir dependencies
    ".elixir_ls", // Elixir language server
    "node_modules",
    "target",     // Rust
    "zig-out",
    "zig-cache",
    ".zig-cache",
    "__pycache__",
    "*.pyc",
    ".pytest_cache",
    "venv",
    ".venv",
    "env",
    ".env",
    "dist",
    "build",
    ".next",
    ".nuxt",
    ".output",
    "coverage",
    ".nyc_output",
    ".gradle",
    ".idea",
    ".vscode",
    "*.log",
    ".DS_Store",
    "Thumbs.db",
};