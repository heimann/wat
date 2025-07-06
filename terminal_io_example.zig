const std = @import("std");
const os = std.os;
const fs = std.fs;
const io = std.io;

// ANSI escape codes
const ESC = "\x1b";
const CLEAR_SCREEN = ESC ++ "[2J";
const CURSOR_HOME = ESC ++ "[H";
const CURSOR_HIDE = ESC ++ "[?25l";
const CURSOR_SHOW = ESC ++ "[?25h";
const CURSOR_UP = ESC ++ "[A";
const CURSOR_DOWN = ESC ++ "[B";
const CURSOR_RIGHT = ESC ++ "[C";
const CURSOR_LEFT = ESC ++ "[D";
const CLEAR_LINE = ESC ++ "[2K";
const MOVE_TO = ESC ++ "[{d};{d}H"; // row;col

pub fn main() !void {
    // Open the terminal device
    const tty = try fs.cwd().openFile("/dev/tty", .{ .read = true, .write = true });
    defer tty.close();

    // Get the current terminal settings
    const original_termios = try os.tcgetattr(tty.handle);
    
    // Make a copy to modify
    var raw = original_termios;
    
    // Disable canonical mode (line buffering) and echo
    // This allows reading input character by character
    raw.lflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.ECHO | os.linux.ICANON | os.linux.ISIG | os.linux.IEXTEN,
    );
    
    // Disable input processing
    raw.iflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.IXON | os.linux.ICRNL | os.linux.BRKINT | os.linux.INPCK | os.linux.ISTRIP,
    );
    
    // Set character size
    raw.cflag &= ~@as(os.linux.tcflag_t, os.linux.CSIZE);
    raw.cflag |= os.linux.CS8;
    
    // Disable output processing
    raw.oflag &= ~@as(os.linux.tcflag_t, os.linux.OPOST);
    
    // Set minimum characters to read and timeout
    raw.cc[os.system.V.TIME] = 0;  // No timeout
    raw.cc[os.system.V.MIN] = 1;   // Read 1 character at a time
    
    // Apply the new settings
    try os.tcsetattr(tty.handle, .FLUSH, raw);
    
    // Restore original settings on exit
    defer os.tcsetattr(tty.handle, .FLUSH, original_termios) catch {};
    
    const writer = tty.writer();
    
    // Clear screen and hide cursor
    try writer.print("{s}{s}{s}", .{ CLEAR_SCREEN, CURSOR_HOME, CURSOR_HIDE });
    defer writer.print("{s}", .{CURSOR_SHOW}) catch {};
    
    // Draw a simple UI
    try writer.print("=== Terminal I/O Demo ===\n\r", .{});
    try writer.print("Use arrow keys to move, 'q' to quit\n\r", .{});
    try writer.print("Press 'c' to clear screen\n\r", .{});
    try writer.print("\n\r", .{});
    
    var cursor_row: u32 = 5;
    var cursor_col: u32 = 1;
    
    // Move cursor to starting position
    try writer.print(ESC ++ "[{d};{d}H", .{ cursor_row, cursor_col });
    try writer.print("*", .{});
    
    // Main input loop
    while (true) {
        var buffer: [3]u8 = undefined;
        const n = try tty.read(&buffer);
        
        // Clear the current position
        try writer.print(ESC ++ "[{d};{d}H", .{ cursor_row, cursor_col });
        try writer.print(" ", .{});
        
        if (n == 1) {
            switch (buffer[0]) {
                'q' => {
                    // Clean exit
                    try writer.print("{s}{s}", .{ CLEAR_SCREEN, CURSOR_HOME });
                    try writer.print("Goodbye!\n\r", .{});
                    break;
                },
                'c' => {
                    // Clear screen and redraw UI
                    try writer.print("{s}{s}", .{ CLEAR_SCREEN, CURSOR_HOME });
                    try writer.print("=== Terminal I/O Demo ===\n\r", .{});
                    try writer.print("Use arrow keys to move, 'q' to quit\n\r", .{});
                    try writer.print("Press 'c' to clear screen\n\r", .{});
                    try writer.print("\n\r", .{});
                },
                '\x1b' => {
                    // ESC sequence - might be arrow key
                    if (n >= 3 and buffer[1] == '[') {
                        switch (buffer[2]) {
                            'A' => if (cursor_row > 5) cursor_row -= 1, // Up
                            'B' => if (cursor_row < 20) cursor_row += 1, // Down
                            'C' => if (cursor_col < 70) cursor_col += 1, // Right
                            'D' => if (cursor_col > 1) cursor_col -= 1, // Left
                            else => {},
                        }
                    }
                },
                else => {
                    // Show what key was pressed at the bottom
                    try writer.print(ESC ++ "[22;1H" ++ CLEAR_LINE, .{});
                    try writer.print(ESC ++ "[22;1H", .{});
                    try writer.print("Pressed: '{c}' (ASCII: {d})\r", .{ buffer[0], buffer[0] });
                },
            }
        } else if (n == 3 and buffer[0] == '\x1b' and buffer[1] == '[') {
            // Arrow key handling
            switch (buffer[2]) {
                'A' => if (cursor_row > 5) cursor_row -= 1, // Up
                'B' => if (cursor_row < 20) cursor_row += 1, // Down
                'C' => if (cursor_col < 70) cursor_col += 1, // Right
                'D' => if (cursor_col > 1) cursor_col -= 1, // Left
                else => {},
            }
        }
        
        // Draw cursor at new position
        try writer.print(ESC ++ "[{d};{d}H", .{ cursor_row, cursor_col });
        try writer.print("*", .{});
    }
}