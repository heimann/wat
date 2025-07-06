const std = @import("std");
const os = std.os;
const io = std.io;

// ANSI escape codes
pub const ansi = struct {
    pub const clear_screen = "\x1b[2J";
    pub const cursor_home = "\x1b[H";
    pub const cursor_hide = "\x1b[?25l";
    pub const cursor_show = "\x1b[?25h";
    pub const clear_line = "\x1b[2K";
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const reverse = "\x1b[7m";
    
    pub fn cursor_to(row: u32, col: u32) [32]u8 {
        var buf: [32]u8 = undefined;
        const slice = std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ row, col }) catch unreachable;
        var result: [32]u8 = undefined;
        @memcpy(result[0..slice.len], slice);
        @memset(result[slice.len..], 0);
        return result;
    }
    
    pub fn fg_color(color: u8) [16]u8 {
        var buf: [16]u8 = undefined;
        const slice = std.fmt.bufPrint(&buf, "\x1b[38;5;{d}m", .{color}) catch unreachable;
        var result: [16]u8 = undefined;
        @memcpy(result[0..slice.len], slice);
        @memset(result[slice.len..], 0);
        return result;
    }
};

pub const Terminal = struct {
    tty: std.fs.File,
    orig_termios: ?std.posix.termios = null,
    writer: std.fs.File.Writer,
    reader: std.fs.File.Reader,
    
    const Self = @This();
    
    pub fn init() !Self {
        const tty = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
        return Self{
            .tty = tty,
            .writer = tty.writer(),
            .reader = tty.reader(),
        };
    }
    
    pub fn deinit(self: *Self) void {
        if (self.orig_termios) |orig| {
            std.posix.tcsetattr(self.tty.handle, .FLUSH, orig) catch {};
        }
        self.tty.close();
    }
    
    pub fn enterRawMode(self: *Self) !void {
        // Save original terminal settings
        self.orig_termios = try std.posix.tcgetattr(self.tty.handle);
        
        // Modify terminal settings for raw mode
        var raw = self.orig_termios.?;
        
        // Input flags
        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;
        
        // Output flags
        raw.oflag.OPOST = false;
        
        // Control flags
        raw.cflag.CSIZE = .CS8;
        
        // Local flags
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;
        
        // Control characters
        raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
        
        // Apply raw mode settings
        try std.posix.tcsetattr(self.tty.handle, .FLUSH, raw);
    }
    
    pub fn exitRawMode(self: *Self) !void {
        if (self.orig_termios) |orig| {
            try std.posix.tcsetattr(self.tty.handle, .FLUSH, orig);
        }
    }
    
    pub fn readKey(self: *Self) !?Key {
        var buf: [4]u8 = undefined;
        const n = try self.reader.read(&buf);
        
        if (n == 0) return null;
        
        // Handle escape sequences
        if (buf[0] == '\x1b') {
            if (n == 1) return .escape;
            if (n >= 3 and buf[1] == '[') {
                switch (buf[2]) {
                    'A' => return .arrow_up,
                    'B' => return .arrow_down,
                    'C' => return .arrow_right,
                    'D' => return .arrow_left,
                    else => {},
                }
            }
            return .escape;
        }
        
        // Handle control characters and DEL
        if (buf[0] < 32 or buf[0] == 127) {
            switch (buf[0]) {
                '\r', '\n' => return .enter,
                '\t' => return .tab,
                127, 8 => return .backspace,
                3 => return .ctrl_c,
                4 => return .ctrl_d,
                else => {
                    if (buf[0] < 32) {
                        return .{ .ctrl = @intCast(buf[0] + 'a' - 1) };
                    }
                },
            }
        }
        
        // Regular character
        return .{ .char = buf[0] };
    }
    
    pub fn getSize(self: *Self) !struct { rows: u16, cols: u16 } {
        var ws: std.posix.winsize = undefined;
        const TIOCGWINSZ: u32 = 0x5413; // Linux specific
        
        if (std.posix.system.ioctl(self.tty.handle, TIOCGWINSZ, @intFromPtr(&ws)) != 0) {
            return error.GetSizeFailed;
        }
        
        return .{ .rows = ws.row, .cols = ws.col };
    }
    
    pub fn clearScreen(self: *Self) !void {
        try self.writer.writeAll(ansi.clear_screen);
        try self.writer.writeAll(ansi.cursor_home);
    }
    
    pub fn hideCursor(self: *Self) !void {
        try self.writer.writeAll(ansi.cursor_hide);
    }
    
    pub fn showCursor(self: *Self) !void {
        try self.writer.writeAll(ansi.cursor_show);
    }
    
    pub fn moveCursor(self: *Self, row: u32, col: u32) !void {
        const seq = ansi.cursor_to(row, col);
        try self.writer.writeAll(std.mem.sliceTo(&seq, 0));
    }
};

pub const Key = union(enum) {
    char: u8,
    enter,
    escape,
    backspace,
    tab,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
    ctrl_c,
    ctrl_d,
    ctrl: u8,
};