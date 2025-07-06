const std = @import("std");
const Database = @import("database.zig").Database;
const Symbol = @import("database.zig").Symbol;
const SymbolMatch = @import("database.zig").SymbolMatch;
const terminal = @import("terminal.zig");

const MAX_RESULTS = 100;
const VIEWPORT_SIZE = 20;

pub const InteractiveFinder = struct {
    allocator: std.mem.Allocator,
    db: *Database,
    term: terminal.Terminal,
    query: std.ArrayList(u8),
    results: []SymbolMatch,
    selected: usize,
    viewport_start: usize,
    action_template: []const u8,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator, db: *Database, action_template: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .db = db,
            .term = try terminal.Terminal.init(),
            .query = std.ArrayList(u8).init(allocator),
            .results = &.{},
            .selected = 0,
            .viewport_start = 0,
            .action_template = action_template,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.term.deinit();
        self.query.deinit();
        if (self.results.len > 0) {
            @import("database.zig").deinitSymbolMatches(self.results, self.allocator);
        }
    }
    
    pub fn run(self: *Self) !?SelectedAction {
        try self.term.enterRawMode();
        defer self.term.exitRawMode() catch {};
        
        try self.term.hideCursor();
        defer self.term.showCursor() catch {};
        
        // Initial search with empty query
        try self.updateResults();
        try self.render();
        
        while (true) {
            const key = try self.term.readKey() orelse continue;
            
            switch (key) {
                .escape, .ctrl_c => return null,
                .enter => {
                    if (self.results.len > 0 and self.selected < self.results.len) {
                        return SelectedAction{
                            .symbol = self.results[self.selected].symbol,
                            .action_template = self.action_template,
                        };
                    }
                },
                .backspace => {
                    if (self.query.items.len > 0) {
                        _ = self.query.pop();
                        try self.updateResults();
                        try self.render();
                    }
                },
                .arrow_up => {
                    if (self.selected > 0) {
                        self.selected -= 1;
                        self.updateViewport();
                        try self.render();
                    }
                },
                .arrow_down => {
                    if (self.selected + 1 < self.results.len) {
                        self.selected += 1;
                        self.updateViewport();
                        try self.render();
                    }
                },
                .char => |c| {
                    if (c >= 32 and c < 127) { // Printable ASCII
                        try self.query.append(c);
                        try self.updateResults();
                        try self.render();
                    }
                },
                else => {},
            }
        }
    }
    
    fn updateResults(self: *Self) !void {
        // Free previous results
        if (self.results.len > 0) {
            @import("database.zig").deinitSymbolMatches(self.results, self.allocator);
        }
        
        if (self.query.items.len == 0) {
            // Show all symbols when query is empty
            const symbols = try self.db.findSymbol("", self.allocator);
            defer @import("database.zig").deinitSymbols(symbols, self.allocator);
            
            // Convert to SymbolMatch format
            var matches = try self.allocator.alloc(SymbolMatch, @min(symbols.len, MAX_RESULTS));
            for (symbols[0..matches.len], 0..) |sym, i| {
                matches[i] = .{
                    .symbol = .{
                        .name = try self.allocator.dupe(u8, sym.name),
                        .line = sym.line,
                        .node_type = try self.allocator.dupe(u8, sym.node_type),
                        .path = try self.allocator.dupe(u8, sym.path),
                    },
                    .score = 100,
                    .match_type = try self.allocator.dupe(u8, "exact"),
                };
            }
            self.results = matches;
        } else {
            // Fuzzy search
            self.results = try self.db.findSymbolFuzzy(self.query.items, self.allocator);
        }
        
        // Reset selection
        self.selected = 0;
        self.viewport_start = 0;
    }
    
    fn updateViewport(self: *Self) void {
        // Ensure selected item is visible
        if (self.selected < self.viewport_start) {
            self.viewport_start = self.selected;
        } else if (self.selected >= self.viewport_start + VIEWPORT_SIZE) {
            self.viewport_start = self.selected - VIEWPORT_SIZE + 1;
        }
    }
    
    fn render(self: *Self) !void {
        try self.term.clearScreen();
        
        const size = try self.term.getSize();
        const available_rows = size.rows -| 4; // Reserve rows for header/footer
        const display_rows = @min(available_rows, VIEWPORT_SIZE);
        
        // Header
        try self.term.moveCursor(1, 1);
        try self.term.writer.writeAll(terminal.ansi.bold);
        try self.term.writer.writeAll("wat: interactive symbol search");
        try self.term.writer.writeAll(terminal.ansi.reset);
        
        // Query line
        try self.term.moveCursor(2, 1);
        try self.term.writer.print("> {s}_", .{self.query.items});
        
        // Results
        const viewport_end = @min(self.viewport_start + display_rows, self.results.len);
        for (self.viewport_start..viewport_end, 0..) |i, row| {
            try self.term.moveCursor(@intCast(row + 4), 1);
            
            if (i == self.selected) {
                try self.term.writer.writeAll(terminal.ansi.reverse);
            }
            
            const match = self.results[i];
            const type_color = switch (match.score) {
                100 => terminal.ansi.fg_color(10), // Green for exact
                80 => terminal.ansi.fg_color(11),  // Yellow for prefix
                60 => terminal.ansi.fg_color(14),  // Cyan for suffix
                else => terminal.ansi.fg_color(8),  // Gray for contains
            };
            
            // Format: [type:score] name path:line
            try self.term.writer.writeAll(std.mem.sliceTo(&type_color, 0));
            try self.term.writer.print("[{s}:{d}]", .{ match.match_type, match.score });
            try self.term.writer.writeAll(terminal.ansi.reset);
            
            if (i == self.selected) {
                try self.term.writer.writeAll(terminal.ansi.reverse);
            }
            
            try self.term.writer.print(" {s} {s}:{d}", .{
                match.symbol.name,
                match.symbol.path,
                match.symbol.line,
            });
            
            try self.term.writer.writeAll(terminal.ansi.reset);
        }
        
        // Footer
        try self.term.moveCursor(size.rows - 1, 1);
        try self.term.writer.writeAll(terminal.ansi.dim);
        try self.term.writer.print("{d} matches | ↑↓ navigate | Enter select | ESC cancel", .{self.results.len});
        try self.term.writer.writeAll(terminal.ansi.reset);
        
        // Preview line (if selected)
        if (self.selected < self.results.len) {
            try self.term.moveCursor(size.rows, 1);
            try self.term.writer.writeAll(terminal.ansi.dim);
            const sym = self.results[self.selected].symbol;
            try self.term.writer.print("Preview: {s} {s}", .{ sym.node_type, sym.name });
            try self.term.writer.writeAll(terminal.ansi.reset);
        }
    }
};

pub const SelectedAction = struct {
    symbol: Symbol,
    action_template: []const u8,
    
    pub fn execute(self: SelectedAction, allocator: std.mem.Allocator) !void {
        // Parse action template and replace placeholders
        var action = std.ArrayList(u8).init(allocator);
        defer action.deinit();
        
        var i: usize = 0;
        while (i < self.action_template.len) {
            if (std.mem.startsWith(u8, self.action_template[i..], "{file}")) {
                try action.appendSlice(self.symbol.path);
                i += 6;
            } else if (std.mem.startsWith(u8, self.action_template[i..], "{line}")) {
                try action.writer().print("{d}", .{self.symbol.line});
                i += 6;
            } else if (std.mem.startsWith(u8, self.action_template[i..], "{name}")) {
                try action.appendSlice(self.symbol.name);
                i += 6;
            } else {
                try action.append(self.action_template[i]);
                i += 1;
            }
        }
        
        // Execute the command
        var child = std.process.Child.init(&.{"sh", "-c", action.items}, allocator);
        try child.spawn();
        _ = try child.wait();
    }
};