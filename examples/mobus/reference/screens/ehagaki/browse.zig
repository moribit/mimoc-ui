//! Post image is application-owned; bounded title/body use actual Japanese glyphs.
const std = @import("std");
const c = @import("../common.zig");
fn rows(r: *c.R, str: []const u8, y: i16, first: usize, max: usize) usize {
    const ls = c.wrap(str, 116, .viewer);
    for (ls.spans[0..ls.len], 0..) |line, i| {
        if (i >= first and i < first + max) c.mixed(r, line, 5, y + @as(i16, @intCast(i - first)) * 9, .viewer, true, false);
    }
    return ls.len;
}
pub fn render(r: *c.R, f: c.F) void {
    c.rect(r, 2, 2, 124, 60, true, false);
    const b = c.bitmap(f);
    if (f.front) {
        for (0..58) |y| for (0..122) |x| {
            if (c.bitmapPixel(&b, @intCast(x), @intCast(y))) r.pixel(3 + @as(i16, @intCast(x)), 3 + @as(i16, @intCast(y)), true);
        };
    } else {
        var title = f.title;
        var body = f.message;
        var tb: [128]u8 = undefined;
        var bb: [808]u8 = undefined;
        if (f.reveal >= 0) {
            var remaining = f.reveal;
            const t = @import("reveal.zig").text(title, &remaining, &tb);
            title = t.value;
            body = if (t.done) @import("reveal.zig").text(body, &remaining, &bb).value else "";
        }
        const tl = c.wrap(title, 116, .viewer).len;
        const bl = c.wrap(body, 116, .viewer).len;
        const tex = tl - @min(tl, 2);
        const bex = bl - @min(bl, 3);
        const maximum = tex + bex;
        const scroll = @min(@as(usize, @intCast(f.scroll)), maximum);
        _ = rows(r, title, 4, @min(scroll, tex), 2);
        r.hline(3, 22, 122, true);
        _ = rows(r, body, 25, scroll - @min(scroll, tex), 3);
        if (f.scroll > 0) {
            r.pixel(123, 5, true);
            r.pixel(122, 6, true);
            r.pixel(124, 6, true);
        }
        if (f.scroll < maximum) {
            r.pixel(122, 47, true);
            r.pixel(124, 47, true);
            r.pixel(123, 48, true);
        }
    }
    if (f.page_overlay) {
        const str = "2/5";
        const width = (c.fonts.Font{ .kind = .font2 }).measure(str) + 4;
        const x = 125 - width;
        c.rect(r, x, 51, width, 11, false, true);
        c.text(r, .font2, x + 2, 51, str, false, true, true, false);
        for ([_]i16{ 4, 123 }, 0..) |tip, i| {
            c.rect(r, if (i == 0) 3 else 119, 27, 6, 11, false, true);
            var off: i16 = 0;
            while (off <= 3) : (off += 1) {
                const xx = tip + if (i == 0) off else -off;
                r.pixel(xx, 32 - off, true);
                r.pixel(xx, 32 + off, true);
            }
        }
    }
    c.notice(r, f.notice);
    if (f.flip > 0) {
        c.rect(r, 0, 0, f.flip, 64, false, true);
        c.rect(r, 128 - f.flip, 0, f.flip, 64, false, true);
        r.vline(f.flip, 2, 60, true);
        r.vline(127 - f.flip, 2, 60, true);
    }
}
