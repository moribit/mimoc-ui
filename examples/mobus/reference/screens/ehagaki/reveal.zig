//! Integer-only port of ehagaki_text_reveal.hpp, bounded caller-owned output.
const std = @import("std");
const ui = @import("mimoc_ui");
const tables = @import("../../reveal_tables.zig");
fn code(ch: u8) []const u8 {
    const lower = std.ascii.toLower(ch);
    for (tables.morse) |entry| if (entry.b.len == 1 and entry.b[0] == lower) return entry.a;
    return "._.";
}
pub fn text(src: []const u8, remaining: *i64, out: []u8) struct { value: []const u8, done: bool } {
    var pos: usize = 0;
    var n: usize = 0;
    while (pos < src.len) {
        var bytes: usize = ui.font.codepointBytes(src, pos);
        var roman: ?[]const u8 = null;
        var best: usize = 0;
        for (tables.kana) |entry| {
            if (std.mem.startsWith(u8, src[pos..], entry.b) and (entry.b.len > best or (entry.b.len == best and (roman == null or entry.a.len < roman.?.len)))) {
                best = entry.b.len;
                roman = entry.a;
            }
        }
        if (std.mem.startsWith(u8, src[pos..], "ー")) {
            roman = "-";
            best = 3;
        }
        if (roman) |letters| {
            bytes = best;
            var alphabet: [8]u8 = undefined;
            var count: usize = 0;
            for (letters) |letter| {
                const symbols = code(letter);
                const duration = @as(i64, @intCast(symbols.len)) * 60000 + 120000;
                if (remaining.* < duration) {
                    const shown = @min(symbols.len, @as(usize, @intCast(@divTrunc(@max(0, remaining.*), 60000) + 1)));
                    @memcpy(out[n..][0..count], alphabet[0..count]);
                    n += count;
                    @memcpy(out[n..][0..shown], symbols[0..shown]);
                    n += shown;
                    remaining.* = -1;
                    return .{ .value = out[0..n], .done = false };
                }
                remaining.* -= duration;
                alphabet[count] = letter;
                count += 1;
            }
            if (remaining.* < 180000) {
                @memcpy(out[n..][0..count], alphabet[0..count]);
                n += count;
                remaining.* = -1;
                return .{ .value = out[0..n], .done = false };
            }
            remaining.* -= 180000;
        } else {
            const symbols = code(src[pos]);
            const duration = @as(i64, @intCast(symbols.len)) * 60000 + 120000;
            if (remaining.* < duration) {
                const shown = @min(symbols.len, @as(usize, @intCast(@divTrunc(@max(0, remaining.*), 60000) + 1)));
                @memcpy(out[n..][0..shown], symbols[0..shown]);
                n += shown;
                remaining.* = -1;
                return .{ .value = out[0..n], .done = false };
            }
            remaining.* -= duration;
        }
        @memcpy(out[n..][0..bytes], src[pos..][0..bytes]);
        n += bytes;
        pos += bytes;
    }
    return .{ .value = out[0..n], .done = true };
}
