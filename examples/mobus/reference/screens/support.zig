//! Frequently visible supporting surfaces; fixed input and original layouts.
const std = @import("std");
const c = @import("common.zig");
pub fn profile(r: *c.R, f: c.F) void {
    for (f.entries, 0..) |entry, i| {
        const y = f.offset + @as(i16, @intCast(i)) * 28;
        if (y + 28 >= 0 and y < 64) {
            var b: [64]u8 = undefined;
            c.text(r, .font2, 0, y, std.fmt.bufPrint(&b, "{s}:", .{entry.sender}) catch unreachable, false, true, true, false);
            c.text(r, .font2, 0, y + 14, entry.text, false, true, true, false);
        }
    }
}
pub fn list(r: *c.R, f: c.F) void {
    const count: @TypeOf(f.selected) = @intCast(f.entries.len);
    const first = std.math.clamp(f.selected - 3, 0, @max(0, count - 4));
    for (@as(usize, @intCast(first))..@as(usize, @intCast(@min(count, first + 4)))) |i| {
        const y = @as(i16, @intCast(i)) * 16 - first * 16;
        const sel = f.selected == @as(i16, @intCast(i));
        if (sel) c.rect(r, 0, y, 128, 16, true, true);
        const label = f.entries[i].text;
        var b: [128]u8 = undefined;
        const str = if (i > 0 and label.len >= 12) std.fmt.bufPrint(&b, "{s}...{s}", .{ label[0..6], label[label.len - 3 ..] }) catch unreachable else label;
        c.text(r, .font2, 10, y, str, false, true, !sel, sel);
    }
}
pub fn language(r: *c.R, f: c.F) void {
    c.text(r, if (f.selected == 0) .font2 else .misaki8, 64, if (f.selected == 0) 1 else 6, if (f.selected == 0) "Select Language" else "ゲンゴセンタク", true, false, true, false);
    for ([_][]const u8{ "English", "ニホンゴ" }, 0..) |label, i| {
        const sel = f.selected == @as(i16, @intCast(i));
        const yy: @TypeOf(f.selected) = if (i == 0) 20 else 40;
        if (sel) c.rect(r, 8, if (i == 0) 20 else 38, 112, if (i == 0) 16 else 14, true, true);
        c.text(r, if (i == 0) .font2 else .misaki8, 64, yy, label, true, false, !sel, sel);
    }
}
pub fn keyboard(r: *c.R, f: c.F) void {
    c.text(r, .font2, 0, 0, f.title, false, true, true, false);
    r.hline(0, 14, 128, true);
    r.hline(0, 45, 128, true);
    c.text(r, .font2, 0, 15, f.message, false, true, true, false);
    const row = "abcdefghijklm";
    for (row, 0..) |_, i| c.text(r, .font2, @as(i16, @intCast(i)) * 8, 46, row[i .. i + 1], false, true, i != 1, i == 1);
    const fg = true;
    c.raster.fillTriangle(r, 114, 52, 118, 45, 118, 60, false);
    for ([_][4]i16{ .{ 118, 45, 127, 45 }, .{ 127, 45, 127, 60 }, .{ 127, 60, 118, 60 }, .{ 118, 45, 114, 52 }, .{ 114, 52, 118, 60 }, .{ 120, 50, 124, 54 }, .{ 124, 50, 120, 54 } }) |p| c.raster.line(r, p[0], p[1], p[2], p[3], fg);
}
pub fn hello(r: *c.R, f: c.F) void {
    c.text(r, .font2, 64, 18, if (f.reveal == 0) "_" else "CQ CQ", true, false, true, false);
    if (f.reveal != 0) c.text(r, .font2, 64, 34, "DE Mimoc K", true, false, true, false);
}
pub fn openComposer(r: *c.R, f: c.F) void {
    c.rect(r, 3, 3, 122, 58, true, false);
    const localized: c.fonts.Kind = if (std.mem.eql(u8, f.locale, "ja")) .misaki8 else .font2;
    c.text(r, localized, 64, 5, f.title, true, false, true, false);
    r.hline(7, 17, 114, true);
    var b: [1024]u8 = undefined;
    const str = std.fmt.bufPrint(&b, "{s}{s}", .{ f.message, f.morse }) catch unreachable;
    c.tail(r, str, 7, 20, 114, 2, 12, true, false);
    if (f.alphabet.len > 0) c.text(r, localized, 7, 42, f.alphabet, false, false, true, false) else if (f.morse.len > 0) c.text(r, localized, 7, 42, f.morse, false, false, true, false);
    r.hline(7, 49, 114, true);
    c.text(r, .custom7, 7, 51, f.status, false, false, true, false);
}
pub fn scanList(r: *c.R, f: c.F) void {
    if (f.entries.len == 0) {
        const font = c.fonts.Font{ .kind = .font2 };
        c.text(r, .font2, 64 - @divTrunc(font.measure("Scanning..."), 2), 28, "Scanning.", false, false, true, false);
    } else for (f.entries, 0..) |e, i| {
        const y = @as(i16, @intCast(i)) * 16;
        const selected = i == 0;
        if (selected) c.rect(r, 0, y, 128, 16, true, true);
        c.text(r, .font2, 10, y, e.text, false, true, !selected, selected);
    }
}
fn pixel(r: *c.R, b: []const u8, x: i16, y: i16) void {
    if (x < 0 or x >= 128 or y < 0 or y >= 64) return;
    r.pixel(x, y, !c.bitmapPixel(b, x - 3, y - 3));
}
pub fn draw(r: *c.R, f: c.F) void {
    const b = c.bitmap(f);
    for (0..58) |y| for (0..122) |x| {
        if (c.bitmapPixel(&b, @intCast(x), @intCast(y))) r.pixel(3 + @as(i16, @intCast(x)), 3 + @as(i16, @intCast(y)), true);
    };
    if (f.anchor) {
        if (f.mode == 1) {
            var x = f.ax;
            var y = f.ay;
            const dx = @as(i16, @intCast(@abs(f.cx - x)));
            const dy = -@as(i16, @intCast(@abs(f.cy - y)));
            const sx: i16 = if (x < f.cx) 1 else -1;
            const sy: i16 = if (y < f.cy) 1 else -1;
            var err = dx + dy;
            while (true) {
                pixel(r, &b, x, y);
                if (x == f.cx and y == f.cy) break;
                const e = 2 * err;
                if (e >= dy) {
                    err += dy;
                    x += sx;
                }
                if (e <= dx) {
                    err += dx;
                    y += sy;
                }
            }
        } else {
            const l = @min(f.ax, f.cx);
            const right = @max(f.ax, f.cx);
            const top = @min(f.ay, f.cy);
            const bottom = @max(f.ay, f.cy);
            var x = l;
            while (x <= right) : (x += 1) {
                pixel(r, &b, x, top);
                pixel(r, &b, x, bottom);
            }
            var y = top;
            while (y <= bottom) : (y += 1) {
                pixel(r, &b, l, y);
                pixel(r, &b, right, y);
            }
        }
    }
    pixel(r, &b, f.cx, f.cy);
    pixel(r, &b, f.cx - 1, f.cy);
    pixel(r, &b, f.cx + 1, f.cy);
    pixel(r, &b, f.cx, f.cy - 1);
    pixel(r, &b, f.cx, f.cy + 1);
}
