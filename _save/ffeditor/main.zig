const std = @import("std");
const fmt = std.fmt;
const os = std.os;
const c = @import("c_imports.zig").c;

pub fn main() !void {
    const stdin_file = std.io.getStdIn();
    var keybuf: [32]u8 = undefined;

    var num_chars_read: usize = 0;
    while (num_chars_read == 0) {
        num_chars_read = try stdin_file.read(keybuf[0..1]);
    }
}
