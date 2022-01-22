// https://github.com/paulsmith/texteditor-zig/blob/main/src/main.zig

const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;
const io = std.io;
const heap = std.heap;
const mem = std.mem;
const os = std.os;

const _c = @cImport({
    @cInclude("ctype.h");
    @cInclude("limits.h");
    @cInclude("sys/ioctl.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("termios.h");
    @cInclude("unistd.h");
});

const kilo_version = "0.0.1";

pub fn main() anyerror!void {
    var gpa_allocator = gpa.allocator();
    defer {
        const leaked = gpa.deinit();
        if (leaked) panic("leaked memory", null);
    }
    var editor = try Editor.new(gpa_allocator);
    defer gpa_allocator.destroy(editor);
    const args = try std.process.argsAlloc(gpa_allocator);
    defer std.process.argsFree(gpa_allocator, args);
    if (args.len == 2) try editor.open(args[1]);
    try editor.enableRawMode();
    defer editor.disableRawMode();
    while (true) {
        try editor.refreshScreen();
        try editor.processKeyPress();
        if (editor.shutting_down) break;
    }
    editor.free();
    try stdout.writeAll("\x1b[2J");
    try stdout.writeAll("\x1b[H");
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    stdout.writeAll("\x1b[2J") catch {};
    stdout.writeAll("\x1b[H") catch {};
    std.builtin.default_panic(msg, error_return_trace);
}

var gpa = heap.GeneralPurposeAllocator(.{}){};
const StringArrayList = std.ArrayList([]u8);

const Editor = struct {
    orig_termios: os.termios,
    screen_rows: u16,
    cols: u16,
    cx: i16,
    cy: i16,
    row_offset: usize,
    col_offset: usize,
    rows: StringArrayList,
    shutting_down: bool,
    allocator: mem.Allocator,

    const Self = @This();

    fn new(allocator: mem.Allocator) !*Self {
        const ws = try getWindowSize();
        var editor = try allocator.create(Self);
        editor.* = .{
            .orig_termios = undefined,
            .screen_rows = ws.rows,
            .cols = ws.cols,
            .cx = 0,
            .cy = 0,
            .row_offset = 0,
            .col_offset = 0,
            .rows = StringArrayList.init(allocator),
            .shutting_down = false,
            .allocator = allocator,
        };
        return editor;
    }

    fn free(self: *Self) void {
        for (self.rows.items) |row| self.allocator.free(row);
        self.rows.deinit();
    }

    const max_size = 1 * 1024 * 1024;

    fn open(self: *Self, filename: []u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        while (try file.reader().readUntilDelimiterOrEofAlloc(self.allocator, '\n', max_size)) |line| {
            try self.rows.append(line);
        }
    }

    fn enableRawMode(self: *Self) !void {
        self.orig_termios = try os.tcgetattr(stdin_fd);
        var raw = self.orig_termios;
        raw.iflag &= ~@as(os.system.tcflag_t, os.system.BRKINT | os.system.ICRNL | os.system.INPCK | os.system.ISTRIP | os.system.IXON);
        raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);
        raw.cflag |= os.system.CS8;
        raw.lflag &= ~@as(os.system.tcflag_t, os.system.ECHO | os.system.ICANON | os.system.IEXTEN | os.system.ISIG);
        raw.cc[_c.VMIN] = 0;
        raw.cc[_c.VTIME] = 1;
        try os.tcsetattr(stdin_fd, os.TCSA.FLUSH, raw);
    }

    fn disableRawMode(self: *Self) void {
        os.tcsetattr(stdin_fd, os.TCSA.FLUSH, self.orig_termios) catch panic("tcsetattr", null);
    }

    fn moveCursor(self: *Self, movement: Movement) void {
        switch (movement) {
            .arrow_left => {
                if (self.cx > 0) self.cx -= 1;
            },
            .arrow_right => {
                if (self.cx < self.cols - 1) self.cx += 1;
            },
            .arrow_up => {
                if (self.cy > 0) self.cy -= 1;
            },
            .arrow_down => {
                if (self.cy < self.rows.items.len - 1) self.cy += 1;
            },
            .page_up, .page_down => {
                var n = self.screen_rows;
                while (n > 0) : (n -= 1) self.moveCursor(if (movement == .page_up) .arrow_up else .arrow_down);
            },
            .home_key => self.cx = 0,
            .end_key => self.cx = @intCast(i16, self.cols) - 1,
        }
    }

    fn processKeyPress(self: *Self) !void {
        const key = try self.readKey();
        switch (key) {
            .char => |ch| switch (ch) {
                ctrlKey('q') => self.shutting_down = true,
                else => {},
            },
            .movement => |m| self.moveCursor(m),
            .delete => {},
        }
    }

    fn readKey(self: *Self) !Key {
        _ = self;
        const c = try readByte();
        switch (c) {
            '\x1b' => {
                const c1 = readByte() catch return Key{ .char = '\x1b' };
                if (c1 == '[') {
                    const c2 = readByte() catch return Key{ .char = '\x1b' };
                    switch (c2) {
                        'A' => return Key{ .movement = .arrow_up },
                        'B' => return Key{ .movement = .arrow_down },
                        'C' => return Key{ .movement = .arrow_right },
                        'D' => return Key{ .movement = .arrow_left },
                        'F' => return Key{ .movement = .end_key },
                        'H' => return Key{ .movement = .home_key },
                        '1' => {
                            const c3 = readByte() catch return Key{ .char = '\x1b' };
                            if (c3 == '~') return Key{ .movement = .home_key };
                        },
                        '3' => {
                            const c3 = readByte() catch return Key{ .char = '\x1b' };
                            if (c3 == '~') return Key.delete;
                        },
                        '4' => {
                            const c3 = readByte() catch return Key{ .char = '\x1b' };
                            if (c3 == '~') return Key{ .movement = .end_key };
                        },
                        '5' => {
                            const c3 = readByte() catch return Key{ .char = '\x1b' };
                            if (c3 == '~') return Key{ .movement = .page_up };
                        },
                        '6' => {
                            const c3 = readByte() catch return Key{ .char = '\x1b' };
                            if (c3 == '~') return Key{ .movement = .page_down };
                        },
                        else => {},
                    }
                } else if (c1 == 'O') {
                    const c2 = readByte() catch return Key{ .char = '\x1b' };
                    switch (c2) {
                        'F' => return Key{ .movement = .end_key },
                        'H' => return Key{ .movement = .home_key },
                        else => {},
                    }
                }
            },
            ctrlKey('n') => return Key{
                .movement = .arrow_down,
            },
            ctrlKey('p') => return Key{
                .movement = .arrow_up,
            },
            ctrlKey('f') => return Key{
                .movement = .arrow_right,
            },
            ctrlKey('b') => return Key{
                .movement = .arrow_left,
            },
            else => {},
        }
        return Key{ .char = c };
    }

    fn drawRows(self: *Self, writer: anytype) !void {
        var y: usize = 0;
        while (y < self.screen_rows) : (y += 1) {
            const file_row = y + self.row_offset;
            if (file_row >= self.rows.items.len) {
                if (self.rows.items.len == 0 and y == self.screen_rows / 3) {
                    var welcome = try fmt.allocPrint(self.allocator, "Kilo self -- version {s}", .{kilo_version});
                    defer self.allocator.free(welcome);
                    if (welcome.len > self.cols) welcome = welcome[0..self.cols];
                    var padding = (self.cols - welcome.len) / 2;
                    if (padding > 0) {
                        try writer.writeAll("~");
                        padding -= 1;
                    }
                    while (padding > 0) : (padding -= 1) try writer.writeAll(" ");
                    try writer.writeAll(welcome);
                } else {
                    try writer.writeAll("~");
                }
            } else {
                const row = self.rows.items[file_row];
                var len = row.len;
                if (len > self.cols) len = self.cols;
                try writer.writeAll(row[0..len]);
            }
            try writer.writeAll("\x1b[K");
            if (y < self.screen_rows - 1) try writer.writeAll("\r\n");
        }
    }

    fn scroll(self: *Self) void {
        if (self.cy < self.row_offset) {
            self.row_offset = @intCast(usize, self.cy);
        }
        if (self.cy >= self.row_offset + self.screen_rows) {
            self.row_offset = @intCast(usize, self.cy - @intCast(i16, self.screen_rows) + 1);
        }
    }

    fn refreshScreen(self: *Self) !void {
        self.scroll();
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();
        var writer = buf.writer();
        try writer.writeAll("\x1b[?25l");
        try writer.writeAll("\x1b[H");
        try self.drawRows(writer);
        try writer.print("\x1b[{d};{d}H", .{ (self.cy - @intCast(i16, self.row_offset)) + 1, self.cx + 1 });
        try writer.writeAll("\x1b[?25h");
        try stdout.writeAll(buf.items);
    }
};

inline fn ctrlKey(comptime ch: u8) u8 {
    return ch & 0x1f;
}

const stdin = io.getStdIn().reader();
const stdout = io.getStdOut().writer();

fn readByte() !u8 {
    var buf: [1]u8 = undefined;
    // const n = try stdin.read(buf[0..]);
    return buf[0];
}

const Movement = enum {
    arrow_left,
    arrow_right,
    arrow_up,
    arrow_down,
    page_up,
    page_down,
    home_key,
    end_key,
};

const Key = union(enum) {
    char: u8,
    movement: Movement,
    delete: void,
};

const WindowSize = struct {
    rows: u16,
    cols: u16,
};

fn getWindowSize() !WindowSize {
    var ws: os.system.winsize = undefined;
    switch (os.errno(os.system.ioctl(stdin_fd, _c.TIOCGWINSZ, &ws))) {
        std.c.E.SUCCESS => return WindowSize{ .rows = ws.ws_row, .cols = ws.ws_col },
        // EBADF => return error.BadFileDescriptor,
        // EINVAL => return error.InvalidRequest,
        // ENOTTY => return error.NotATerminal,
        else => |err| return os.unexpectedErrno(err),
    }
}

const stdin_fd = io.getStdIn().handle;
