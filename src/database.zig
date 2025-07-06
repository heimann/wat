const std = @import("std");
const c = @cImport({
    @cInclude("sqlite3.h");
});

// Writer for error output
const stderr = std.io.getStdErr().writer();

const DatabaseError = error{
    OpenFailed,
    PrepareFailed,
    ExecuteFailed,
    BindFailed,
    StepFailed,
    FinalizeFailed,
};

pub const Database = struct {
    db: ?*c.sqlite3,
    
    const Self = @This();
    
    pub fn init(path: [:0]const u8) !Self {
        var db: ?*c.sqlite3 = null;
        const result = c.sqlite3_open(path.ptr, &db);
        if (result != c.SQLITE_OK) {
            if (db) |d| {
                stderr.print("SQLite error: {s}\n", .{c.sqlite3_errmsg(d)}) catch {};
                _ = c.sqlite3_close(d);
            }
            return DatabaseError.OpenFailed;
        }
        
        const instance = Self{ .db = db };
        try instance.createTables();
        return instance;
    }
    
    pub fn deinit(self: *Self) void {
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
            self.db = null;
        }
    }
    
    fn createTables(self: Self) !void {
        const schema =
            \\CREATE TABLE IF NOT EXISTS files (
            \\    id INTEGER PRIMARY KEY,
            \\    path TEXT UNIQUE NOT NULL,
            \\    last_modified INTEGER NOT NULL,
            \\    language TEXT NOT NULL,
            \\    hash TEXT
            \\);
            \\
            \\CREATE TABLE IF NOT EXISTS symbols (
            \\    id INTEGER PRIMARY KEY,
            \\    file_id INTEGER NOT NULL,
            \\    name TEXT NOT NULL,
            \\    line INTEGER NOT NULL,
            \\    column INTEGER,
            \\    node_type TEXT NOT NULL,
            \\    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
            \\);
            \\
            \\CREATE TABLE IF NOT EXISTS refs (
            \\    id INTEGER PRIMARY KEY,
            \\    file_id INTEGER NOT NULL,
            \\    name TEXT NOT NULL,
            \\    line INTEGER NOT NULL,
            \\    column INTEGER,
            \\    context TEXT,
            \\    is_definition INTEGER DEFAULT 0,
            \\    FOREIGN KEY (file_id) REFERENCES files(id) ON DELETE CASCADE
            \\);
            \\
            \\CREATE TABLE IF NOT EXISTS deps (
            \\    id INTEGER PRIMARY KEY,
            \\    symbol_id INTEGER NOT NULL,
            \\    depends_on TEXT NOT NULL,
            \\    dependency_type TEXT NOT NULL,
            \\    FOREIGN KEY (symbol_id) REFERENCES symbols(id) ON DELETE CASCADE
            \\);
            \\
            \\CREATE INDEX IF NOT EXISTS idx_symbols_name ON symbols(name);
            \\CREATE INDEX IF NOT EXISTS idx_symbols_file ON symbols(file_id);
            \\CREATE INDEX IF NOT EXISTS idx_refs_name ON refs(name);
            \\CREATE INDEX IF NOT EXISTS idx_refs_file ON refs(file_id);
            \\CREATE INDEX IF NOT EXISTS idx_deps_symbol ON deps(symbol_id);
            \\CREATE INDEX IF NOT EXISTS idx_deps_depends_on ON deps(depends_on);
        ;
        
        try self.exec(schema);
    }
    
    fn exec(self: Self, sql: []const u8) !void {
        var err_msg: [*c]u8 = undefined;
        const result = c.sqlite3_exec(
            self.db,
            sql.ptr,
            null,
            null,
            &err_msg
        );
        
        if (result != c.SQLITE_OK) {
            stderr.print("SQL error: {s}\n", .{err_msg}) catch {};
            c.sqlite3_free(err_msg);
            return DatabaseError.ExecuteFailed;
        }
    }
    
    pub fn beginTransaction(self: Self) !void {
        try self.exec("BEGIN TRANSACTION");
    }
    
    pub fn commit(self: Self) !void {
        try self.exec("COMMIT");
    }
    
    pub fn rollback(self: Self) !void {
        try self.exec("ROLLBACK");
    }
    
    pub fn insertFile(self: Self, path: []const u8, last_modified: i64, language: []const u8) !i64 {
        const sql = "INSERT OR REPLACE INTO files (path, last_modified, language) VALUES (?, ?, ?)";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_text(stmt, 1, path.ptr, @intCast(path.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_int64(stmt, 2, last_modified);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 3, language.ptr, @intCast(language.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
        
        return c.sqlite3_last_insert_rowid(self.db);
    }
    
    pub fn insertSymbol(
        self: Self,
        file_id: i64,
        name: []const u8,
        line: u32,
        node_type: []const u8,
    ) !i64 {
        const sql = "INSERT INTO symbols (file_id, name, line, node_type) VALUES (?, ?, ?, ?)";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, file_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 2, name.ptr, @intCast(name.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_int(stmt, 3, @intCast(line));
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 4, node_type.ptr, @intCast(node_type.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
        
        return c.sqlite3_last_insert_rowid(self.db);
    }
    
    pub fn findSymbol(self: Self, name: []const u8, allocator: std.mem.Allocator) ![]Symbol {
        const sql = 
            \\SELECT s.name, s.line, s.node_type, f.path
            \\FROM symbols s
            \\JOIN files f ON s.file_id = f.id
            \\WHERE s.name = ?
            \\ORDER BY f.path, s.line
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_text(stmt, 1, name.ptr, @intCast(name.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        var symbols = std.ArrayList(Symbol).init(allocator);
        errdefer symbols.deinit();
        
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const sym_name = std.mem.span(c.sqlite3_column_text(stmt, 0));
            const line = @as(u32, @intCast(c.sqlite3_column_int(stmt, 1)));
            const node_type = std.mem.span(c.sqlite3_column_text(stmt, 2));
            const path = std.mem.span(c.sqlite3_column_text(stmt, 3));
            
            try symbols.append(.{
                .name = try allocator.dupe(u8, sym_name),
                .line = line,
                .node_type = try allocator.dupe(u8, node_type),
                .path = try allocator.dupe(u8, path),
            });
        }
        
        return symbols.toOwnedSlice();
    }
    
    pub fn needsReindex(self: Self, path: []const u8, last_modified: i64) !bool {
        const sql = "SELECT last_modified FROM files WHERE path = ?";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_text(stmt, 1, path.ptr, @intCast(path.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result == c.SQLITE_ROW) {
            const stored_modified = c.sqlite3_column_int64(stmt, 0);
            return last_modified > stored_modified;
        }
        
        // File not in database, needs indexing
        return true;
    }
    
    pub fn deleteFileSymbols(self: Self, file_id: i64) !void {
        const sql = "DELETE FROM symbols WHERE file_id = ?";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, file_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
    }
    
    pub fn deleteFileReferences(self: Self, file_id: i64) !void {
        const sql = "DELETE FROM refs WHERE file_id = ?";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, file_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
    }
    
    pub fn insertReference(
        self: Self,
        file_id: i64,
        name: []const u8,
        line: u32,
        column: u32,
        context: ?[]const u8,
        is_definition: bool,
    ) !void {
        const sql = "INSERT INTO refs (file_id, name, line, column, context, is_definition) VALUES (?, ?, ?, ?, ?, ?)";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, file_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 2, name.ptr, @intCast(name.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_int(stmt, 3, @intCast(line));
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_int(stmt, 4, @intCast(column));
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        if (context) |ctx| {
            result = c.sqlite3_bind_text(stmt, 5, ctx.ptr, @intCast(ctx.len), c.SQLITE_STATIC);
        } else {
            result = c.sqlite3_bind_null(stmt, 5);
        }
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_int(stmt, 6, if (is_definition) 1 else 0);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
    }
    
    pub fn insertDependency(
        self: Self,
        symbol_id: i64,
        depends_on: []const u8,
        dependency_type: []const u8,
    ) !void {
        const sql = "INSERT INTO deps (symbol_id, depends_on, dependency_type) VALUES (?, ?, ?)";
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, symbol_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 2, depends_on.ptr, @intCast(depends_on.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_bind_text(stmt, 3, dependency_type.ptr, @intCast(dependency_type.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
    }
    
    pub fn deleteFileDependencies(self: Self, file_id: i64) !void {
        const sql = 
            \\DELETE FROM deps 
            \\WHERE symbol_id IN (SELECT id FROM symbols WHERE file_id = ?)
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, file_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        result = c.sqlite3_step(stmt);
        if (result != c.SQLITE_DONE) {
            return DatabaseError.StepFailed;
        }
    }
    
    pub fn getSymbolWithSignature(self: Self, symbol_id: i64, allocator: std.mem.Allocator) !?SymbolWithSignature {
        const sql = 
            \\SELECT s.name, s.line, s.node_type, f.path
            \\FROM symbols s
            \\JOIN files f ON s.file_id = f.id
            \\WHERE s.id = ?
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_int64(stmt, 1, symbol_id);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        if (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const name = std.mem.span(c.sqlite3_column_text(stmt, 0));
            const line = @as(u32, @intCast(c.sqlite3_column_int(stmt, 1)));
            const node_type = std.mem.span(c.sqlite3_column_text(stmt, 2));
            const path = std.mem.span(c.sqlite3_column_text(stmt, 3));
            
            return SymbolWithSignature{
                .id = symbol_id,
                .name = try allocator.dupe(u8, name),
                .line = line,
                .node_type = try allocator.dupe(u8, node_type),
                .path = try allocator.dupe(u8, path),
                .signature = null, // Will be filled later
            };
        }
        
        return null;
    }
    
    pub fn findEntryPoints(self: Self, allocator: std.mem.Allocator) ![]Symbol {
        const sql = 
            \\SELECT s.name, s.line, s.node_type, f.path
            \\FROM symbols s
            \\JOIN files f ON s.file_id = f.id
            \\WHERE s.name = 'main' OR s.name LIKE 'pub %'
            \\ORDER BY s.name
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        const result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        var symbols = std.ArrayList(Symbol).init(allocator);
        errdefer symbols.deinit();
        
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const name = std.mem.span(c.sqlite3_column_text(stmt, 0));
            const line = @as(u32, @intCast(c.sqlite3_column_int(stmt, 1)));
            const node_type = std.mem.span(c.sqlite3_column_text(stmt, 2));
            const path = std.mem.span(c.sqlite3_column_text(stmt, 3));
            
            // For now, only include actual main functions
            if (std.mem.eql(u8, name, "main")) {
                try symbols.append(.{
                    .name = try allocator.dupe(u8, name),
                    .line = line,
                    .node_type = try allocator.dupe(u8, node_type),
                    .path = try allocator.dupe(u8, path),
                });
            }
        }
        
        return symbols.toOwnedSlice();
    }
    
    pub fn findDependencies(self: Self, symbol_name: []const u8, allocator: std.mem.Allocator) ![]Dependency {
        const sql = 
            \\SELECT DISTINCT d.depends_on, d.dependency_type
            \\FROM deps d
            \\JOIN symbols s ON d.symbol_id = s.id
            \\WHERE s.name = ?
            \\ORDER BY d.depends_on
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_text(stmt, 1, symbol_name.ptr, @intCast(symbol_name.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        var dependencies = std.ArrayList(Dependency).init(allocator);
        errdefer dependencies.deinit();
        
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const depends_on = std.mem.span(c.sqlite3_column_text(stmt, 0));
            const dependency_type = std.mem.span(c.sqlite3_column_text(stmt, 1));
            
            try dependencies.append(.{
                .depends_on = try allocator.dupe(u8, depends_on),
                .dependency_type = try allocator.dupe(u8, dependency_type),
            });
        }
        
        return dependencies.toOwnedSlice();
    }
    
    pub fn findReferences(self: Self, name: []const u8, include_defs: bool, allocator: std.mem.Allocator) ![]Reference {
        const sql = if (include_defs)
            \\SELECT r.name, r.line, r.column, f.path, r.context, r.is_definition
            \\FROM refs r
            \\JOIN files f ON r.file_id = f.id
            \\WHERE r.name = ?
            \\ORDER BY f.path, r.line
        else
            \\SELECT r.name, r.line, r.column, f.path, r.context, r.is_definition
            \\FROM refs r
            \\JOIN files f ON r.file_id = f.id
            \\WHERE r.name = ? AND r.is_definition = 0
            \\ORDER BY f.path, r.line
        ;
        
        var stmt: ?*c.sqlite3_stmt = null;
        defer {
            if (stmt) |s| _ = c.sqlite3_finalize(s);
        }
        
        var result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            return DatabaseError.PrepareFailed;
        }
        
        result = c.sqlite3_bind_text(stmt, 1, name.ptr, @intCast(name.len), c.SQLITE_STATIC);
        if (result != c.SQLITE_OK) return DatabaseError.BindFailed;
        
        var references = std.ArrayList(Reference).init(allocator);
        errdefer references.deinit();
        
        while (c.sqlite3_step(stmt) == c.SQLITE_ROW) {
            const ref_name = std.mem.span(c.sqlite3_column_text(stmt, 0));
            const line = @as(u32, @intCast(c.sqlite3_column_int(stmt, 1)));
            const column = @as(u32, @intCast(c.sqlite3_column_int(stmt, 2)));
            const path = std.mem.span(c.sqlite3_column_text(stmt, 3));
            const context_ptr = c.sqlite3_column_text(stmt, 4);
            const context = if (context_ptr != null) std.mem.span(context_ptr) else null;
            const is_definition = c.sqlite3_column_int(stmt, 5) != 0;
            
            try references.append(.{
                .name = try allocator.dupe(u8, ref_name),
                .line = line,
                .column = column,
                .path = try allocator.dupe(u8, path),
                .context = if (context) |ctx| try allocator.dupe(u8, ctx) else null,
                .is_definition = is_definition,
            });
        }
        
        return references.toOwnedSlice();
    }
};

pub const Symbol = struct {
    name: []const u8,
    line: u32,
    node_type: []const u8,
    path: []const u8,
    
    pub fn deinit(self: *Symbol, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.node_type);
        allocator.free(self.path);
    }
};

pub const Reference = struct {
    name: []const u8,
    line: u32,
    column: u32,
    path: []const u8,
    context: ?[]const u8,
    is_definition: bool,
    
    pub fn deinit(self: *Reference, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.path);
        if (self.context) |ctx| {
            allocator.free(ctx);
        }
    }
};

pub const Dependency = struct {
    depends_on: []const u8,
    dependency_type: []const u8,
    
    pub fn deinit(self: *Dependency, allocator: std.mem.Allocator) void {
        allocator.free(self.depends_on);
        allocator.free(self.dependency_type);
    }
};

pub const SymbolWithSignature = struct {
    id: i64,
    name: []const u8,
    line: u32,
    node_type: []const u8,
    path: []const u8,
    signature: ?[]const u8,
    
    pub fn deinit(self: *SymbolWithSignature, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.node_type);
        allocator.free(self.path);
        if (self.signature) |sig| {
            allocator.free(sig);
        }
    }
};

pub fn deinitSymbols(symbols: []Symbol, allocator: std.mem.Allocator) void {
    for (symbols) |*sym| {
        sym.deinit(allocator);
    }
    allocator.free(symbols);
}

pub fn deinitReferences(references: []Reference, allocator: std.mem.Allocator) void {
    for (references) |*ref| {
        ref.deinit(allocator);
    }
    allocator.free(references);
}

pub fn deinitDependencies(dependencies: []Dependency, allocator: std.mem.Allocator) void {
    for (dependencies) |*dep| {
        dep.deinit(allocator);
    }
    allocator.free(dependencies);
}