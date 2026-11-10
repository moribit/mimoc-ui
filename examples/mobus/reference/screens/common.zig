//! Legacy rendering helpers; metrics are the captured original font metrics.
const std = @import("std");
pub const ui = @import("mimoc_ui");
pub const R = ui.mono1.Renderer;
pub const fonts = @import("../fonts.zig");
pub const raster = ui.raster_compat;
pub const F = @import("../product_fixtures.zig").Fixture;
pub fn rect(r: *R, x: i16, y: i16, w: i16, h: i16, on: bool, fill: bool) void {
    const b = ui.geometry.Rect{ .x = x, .y = y, .w = w, .h = h };
    if (fill) r.fillRect(b, on) else r.rect(b, on);
}
pub fn text(r: *R, font_kind: fonts.Kind, x: i16, y: i16, str: []const u8, center: bool, printing: bool, fg: bool, bg: bool) void {
    var f = fonts.Font{ .kind = font_kind, .printing = printing };
    f.draw(r, if (center) x - @divTrunc(f.measure(str), 2) else x, y, str, fg, bg);
}
pub fn chatKind(cp: u21) fonts.Kind {
    return if (cp >= 0x30a0 and cp <= 0x30ff) .b12 else if (cp >= 0x3000 and cp <= 0x30ff) .japan12 else .font2;
}
pub const Style = enum { talk, history, viewer };
pub fn kind(style: Style, cp: u21) fonts.Kind {
    return switch (style) {
        .talk => chatKind(cp),
        .history => if (cp < 128) .custom7 else .misaki8,
        .viewer => if (cp < 128) .custom7 else .japan8,
    };
}
pub fn mixed(r: *R, str: []const u8, x: i16, y: i16, style: Style, fg: bool, bg: bool) void {
    var pos: usize = 0;
    var pen = x;
    while (pos < str.len) {
        const cp = ui.font.decode(str, pos);
        const end = pos + cp.length;
        const k = kind(style, cp.scalar);
        const off: i16 = switch (style) {
            .talk => if (cp.scalar < 128) 0 else 3,
            .history => if (cp.scalar < 128) 2 else 4,
            .viewer => 0,
        };
        text(r, k, pen, y + off, str[pos..end], false, false, fg, bg);
        pen += (fonts.Font{ .kind = k }).measure(str[pos..end]);
        pos = end;
    }
}
pub const Lines = struct { spans: [80][]const u8 = undefined, len: usize = 0 };
pub fn wrap(str: []const u8, width: i16, style: Style) Lines {
    var out: Lines = .{};
    var start: usize = 0;
    var pos: usize = 0;
    var used: i16 = 0;
    while (pos < str.len) {
        const cp = ui.font.decode(str, pos);
        const end = pos + cp.length;
        if (cp.scalar == '\r') {
            pos = end;
            continue;
        }
        if (cp.scalar == '\n') {
            out.spans[out.len] = str[start..pos];
            out.len += 1;
            start = end;
            used = 0;
            pos = end;
            continue;
        }
        const w = (fonts.Font{ .kind = kind(style, cp.scalar) }).measure(str[pos..end]);
        if (pos > start and used + w > width) {
            out.spans[out.len] = str[start..pos];
            out.len += 1;
            start = pos;
            used = 0;
        }
        used += w;
        pos = end;
    }
    if (pos > start or out.len == 0) {
        out.spans[out.len] = str[start..pos];
        out.len += 1;
    }
    return out;
}
pub fn tail(r: *R, str: []const u8, x: i16, y: i16, width: i16, visible: usize, height: i16, fg: bool, bg: bool) void {
    const lines = wrap(str, width, .talk);
    const first = lines.len - @min(visible, lines.len);
    for (lines.spans[first..lines.len], 0..) |line, i| mixed(r, line, x, y + @as(i16, @intCast(i)) * height, .talk, fg, bg);
}
pub fn input(f: F, buf: []u8, cursor: bool) []const u8 {
    return std.fmt.bufPrint(buf, "{s}{s}{s}{s}", .{ f.message, f.morse, f.alphabet, if (cursor) "|" else "" }) catch unreachable;
}
pub fn language(r: *R, f: F, fg: bool, bg: bool) void {
    if (!f.overlay) return;
    raster.roundRect(r, 52, 24, 24, 18, 2, bg, true);
    raster.roundRect(r, 52, 24, 24, 18, 2, fg, false);
    text(r, .font2, 64, 25, if (f.lang == 1) "JP" else "EN", true, false, fg, bg);
}
pub fn notice(r: *R, str: []const u8) void {
    if (str.len == 0) return;
    const w = @min(124, (fonts.Font{ .kind = .custom7 }).measure(str) + 6);
    const x = @divTrunc(128 - w, 2);
    rect(r, x, 53, w, 11, false, true);
    text(r, .custom7, x + 3, 53, str, false, false, true, false);
}
pub fn status(r: *R, f: F) void {
    text(r, .font2, 64, if (f.subtitle.len > 0 or f.two_lines) 18 else 26, f.title, true, false, true, false);
    if (f.subtitle.len > 0) text(r, .font2, 64, 34, f.subtitle, true, false, true, false);
}
pub fn bitmap(f: F) [885]u8 {
    var b: [885]u8 = @splat(0);
    if (f.image) for (10..38) |y| {
        for (12..90) |x| {
            if ((x + y) % 7 == 0 or (y >= 20 and y < 28 and x >= 30 and x < 60)) {
                const bit = y * 122 + x;
                b[bit / 8] |= @as(u8, 128) >> @as(u3, @intCast(bit % 8));
            }
        }
    };
    if (f.bitmap_text) {
        const cols = @import("../canvas_font.zig").a_columns;
        for (0..7) |y| for (0..5) |x| {
            if (cols[x] & (@as(u8, 1) << @as(u3, @intCast(y))) != 0) {
                const bit = (20 + y) * 122 + 30 + x;
                b[bit / 8] |= @as(u8, 128) >> @as(u3, @intCast(bit % 8));
            }
        };
    }
    return b;
}
pub fn bitmapPixel(b: []const u8, x: i16, y: i16) bool {
    if (x < 0 or x >= 122 or y < 0 or y >= 58) return false;
    const bit = @as(usize, @intCast(y)) * 122 + @as(usize, @intCast(x));
    return b[bit / 8] & (@as(u8, 128) >> @as(u3, @intCast(bit % 8))) != 0;
}
