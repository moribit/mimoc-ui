//! Frozen 122x58 contiguous MSB bitmap, menus and production CanvasOverlay.
const c = @import("../common.zig");
const cf = @import("../../canvas_font.zig");
fn inv(r: *c.R, b: []const u8, x: i16, y: i16) void {
    if (x < 0 or x >= 122 or y < 0 or y >= 58) return;
    r.pixel(x + 3, y + 3, !c.bitmapPixel(b, x, y));
}
fn dotted(r: *c.R, b: ?[]const u8, x: i16, y: i16, w: i16, h: i16) void {
    var xx: i16 = 0;
    while (xx < w) : (xx += 2) {
        dot(r, b, x + xx, y);
        if (h > 1) dot(r, b, x + xx, y + h - 1);
    }
    var yy: i16 = 2;
    while (yy < h - 1) : (yy += 2) {
        dot(r, b, x, y + yy);
        if (w > 1) dot(r, b, x + w - 1, y + yy);
    }
}
fn dot(r: *c.R, b: ?[]const u8, x: i16, y: i16) void {
    if (b) |bits| inv(r, bits, x, y) else r.pixel(x, y, true);
}
fn a(r: *c.R, x: i16, y: i16, normal: bool, on: bool) void {
    const w: usize = if (normal) 5 else 3;
    const h: usize = if (normal) 7 else 5;
    for (0..h) |yy| for (0..w) |xx| {
        const bit = if (normal) cf.a_columns[xx] & (@as(u8, 1) << @as(u3, @intCast(yy))) != 0 else cf.a_small[yy] & (@as(u8, 4) >> @as(u2, @intCast(xx))) != 0;
        if (bit) r.pixel(x + @as(i16, @intCast(xx)), y + @as(i16, @intCast(yy)), on);
    };
}
fn popup(r: *c.R, f: c.F, mode: i16) void {
    c.rect(r, 96, 8, 14, 29, false, true);
    c.rect(r, 96, 8, 14, 29, true, false);
    for (0..2) |ii| {
        const i: i16 = @intCast(ii);
        const y = 15 + i * 11;
        const sel = if (mode == 0) f.filled == (i == 1) else f.option == (i == 1);
        if (sel) c.rect(r, 98, y - 4, 10, 9, true, true);
        const color = !sel;
        if (mode == 0) c.rect(r, 100, y - 3, 7, 7, color, i == 1) else if (mode == 1) a(r, 103 - @as(i16, if (i == 0) 1 else 2), y - @as(i16, if (i == 0) 2 else 3), i == 1, color) else if (i == 0) {
            c.raster.line(r, 100, y, 106, y, color);
            c.raster.line(r, 103, y - 3, 103, y + 3, color);
            for ([_]i16{ 101, 105 }) |x| {
                r.pixel(x, y - 1, color);
                r.pixel(x, y + 1, color);
            }
            for ([_]i16{ 102, 104 }) |x| {
                r.pixel(x, y - 2, color);
                r.pixel(x, y + 2, color);
            }
        } else {
            c.rect(r, 100, y - 3, 5, 5, color, false);
            c.rect(r, 102, y - 1, 5, 5, sel, true);
            c.rect(r, 102, y - 1, 5, 5, color, false);
        }
    }
}
fn menu(r: *c.R, f: c.F) void {
    c.rect(r, 0, 0, 16, 64, false, true);
    r.vline(16, 0, 64, true);
    for (0..5) |ii| {
        const i: i16 = @intCast(ii);
        const x: i16 = 8;
        const y = 8 + i * 12;
        if (f.menu_focus == 0 and i == f.left_selected) c.rect(r, 1, y - 6, 14, 12, true, false);
        switch (i) {
            0 => {
                c.raster.line(r, x, y - 4, x - 5, y, true);
                c.raster.line(r, x - 5, y, x, y + 4, true);
                c.raster.line(r, x - 5, y, x + 3, y, true);
            },
            1 => {
                c.raster.line(r, x - 2, y - 4, x + 3, y, true);
                c.raster.line(r, x + 3, y, x - 2, y + 4, true);
                c.raster.line(r, x - 5, y, x + 2, y, true);
            },
            2 => {
                c.rect(r, x - 4, y - 2, 8, 7, true, false);
                c.raster.line(r, x - 5, y - 3, x + 4, y - 3, true);
                c.raster.line(r, x - 2, y - 4, x + 1, y - 4, true);
                c.raster.line(r, x - 2, y, x - 2, y + 2, true);
                c.raster.line(r, x + 1, y, x + 1, y + 2, true);
            },
            3 => {
                dotted(r, null, x - 4, y - 4, 8, 8);
                r.pixel(x - 4, y - 4, true);
                r.pixel(x + 3, y - 4, true);
                r.pixel(x - 4, y + 3, true);
                r.pixel(x + 3, y + 3, true);
            },
            else => c.text(r, .custom7, x, y - 4, "ok", true, false, true, false),
        }
    }
    c.rect(r, 112, 0, 16, 64, false, true);
    r.vline(111, 0, 64, true);
    for (0..5) |ii| {
        const i: i16 = @intCast(ii);
        const x: i16 = 120;
        const y = 8 + i * 12;
        const active = f.active_mode == i;
        const fg = !active;
        if (active) c.rect(r, 114, y - 5, 12, 10, true, true);
        if (f.menu_focus != 0 and i == f.menu_selected) c.rect(r, 113, y - 6, 14, 12, true, false);
        switch (i) {
            0 => r.pixel(x, y, fg),
            1 => c.raster.line(r, x - 4, y + 3, x + 4, y - 3, fg),
            2 => c.rect(r, x - 4, y - 4, 8, 8, fg, false),
            3 => a(r, x - 3, y - 3, true, fg),
            else => {
                const drop = [_]u16{ 0x010, 0x010, 0x038, 0x07c, 0x07c, 0x0fe, 0x0fe, 0x07c, 0x038 };
                for (0..9) |yy| for (0..9) |xx| {
                    const bit = @as(u16, 1) << @as(u4, @intCast(xx));
                    if (drop[yy] & bit == 0) continue;
                    const interior = xx > 0 and xx < 8 and yy > 0 and yy < 8 and drop[yy] & (bit >> 1) != 0 and drop[yy] & (bit << 1) != 0 and drop[yy - 1] & bit != 0 and drop[yy + 1] & bit != 0;
                    if (f.white or !interior) r.pixel(x - 5 + @as(i16, @intCast(xx)), y - 4 + @as(i16, @intCast(yy)), true);
                };
            },
        }
    }
    if (f.stroke_menu) {
        if (f.menu_selected == 2) popup(r, f, 0) else {
            c.rect(r, 96, 8, 14, 40, false, true);
            c.rect(r, 96, 8, 14, 40, true, false);
            for (0..3) |ii| {
                const i: i16 = @intCast(ii);
                const y = 15 + i * 11;
                const sel = f.stroke == i + 1;
                if (sel) c.rect(r, 98, y - 4, 10, 9, true, true);
                c.raster.fillCircle(r, 103, y, i + 1, !sel);
            }
        }
    }
}
pub fn render(r: *c.R, f: c.F) void {
    const b = c.bitmap(f);
    c.rect(r, 2, 2, 124, 60, true, false);
    for (0..58) |yy| for (0..122) |xx| {
        const x: i16 = @intCast(xx);
        const y: i16 = @intCast(yy);
        if (c.bitmapPixel(&b, x, y)) r.pixel(3 + x, 3 + y, true);
    };
    if (f.anchor) {
        if (f.mode == 1) {
            var x = f.ax;
            var y = f.ay;
            const dx = @as(i16, @intCast(@abs(f.cx - x)));
            const sx: @TypeOf(x) = if (x < f.cx) 1 else -1;
            const dy = -@as(i16, @intCast(@abs(f.cy - y)));
            const sy: @TypeOf(y) = if (y < f.cy) 1 else -1;
            var err = dx + dy;
            while (true) {
                inv(r, &b, x, y);
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
        } else if (f.mode == 2 or f.mode == 3) {
            const left = @min(f.ax, f.cx);
            const right = @max(f.ax, f.cx);
            const top = @min(f.ay, f.cy);
            const bottom = @max(f.ay, f.cy);
            if (f.stage == 2) dotted(r, &b, left, top, right - left + 1, bottom - top + 1) else {
                var x = left;
                while (x <= right) : (x += 1) {
                    inv(r, &b, x, top);
                    inv(r, &b, x, bottom);
                }
                var y = top;
                while (y <= bottom) : (y += 1) {
                    inv(r, &b, left, y);
                    inv(r, &b, right, y);
                }
            }
        } else inv(r, &b, f.ax, f.ay);
    }
    inv(r, &b, f.cx, f.cy);
    if (f.stage >= 1 and f.stage <= 4) {
        inv(r, &b, f.cx - 1, f.cy);
        inv(r, &b, f.cx + 1, f.cy);
        inv(r, &b, f.cx, f.cy - 1);
        inv(r, &b, f.cx, f.cy + 1);
    }
    if (f.menu) menu(r, f);
    if (f.stage == 5) popup(r, f, 1) else if (f.stage == 3) popup(r, f, 2) else if (f.stage != 0 and f.stage != 1 and f.stage != 2 and f.width > 0 and f.height > 0) {
        if (f.stage == 4) dotted(r, &b, f.cx, f.cy, f.width, f.height) else c.rect(r, 3 + f.cx, 3 + f.cy, f.width, f.height, true, false);
    }
    if (f.clear) {
        c.rect(r, 18, 12, 92, 40, false, true);
        c.rect(r, 18, 12, 92, 40, true, false);
        c.text(r, .font2, 64, 18, "CLEAR ALL?", true, false, true, false);
        c.text(r, .font2, 43, 37, "NO", true, false, f.yes, !f.yes);
        c.text(r, .font2, 84, 37, "YES", true, false, !f.yes, f.yes);
    }
    if (!f.clear and f.stage != 3 and f.stage != 5 and f.notice.len > 0) {
        c.raster.roundRect(r, 34, 21, 60, 22, 3, true, true);
        c.raster.roundRect(r, 34, 21, 60, 22, 3, false, false);
        c.text(r, .custom7, 64, 25, f.notice, true, false, false, true);
    }
}
