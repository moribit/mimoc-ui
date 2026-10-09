//! Integer raster policy compatible with LovyanGFX rounded primitives.
//! Adapted from LovyanGFX LGFXBase.cpp, FreeBSD license:
//! Copyright (c) 2020 lovyan03. Redistribution in source/binary, with or without
//! modification, is permitted retaining this notice and disclaimer. PROVIDED
//! "AS IS", WITHOUT WARRANTIES; AUTHORS ARE NOT LIABLE FOR DAMAGES.
const R = @import("mono1.zig").Renderer;
const std = @import("std");

pub fn line(p: *R, ax: i16, ay: i16, bx: i16, by: i16, on: bool) void {
    var x0: i32 = ax;
    var y0: i32 = ay;
    var x1: i32 = bx;
    var y1: i32 = by;
    const steep = @abs(y1 - y0) > @abs(x1 - x0);
    if (steep) {
        std.mem.swap(i32, &x0, &y0);
        std.mem.swap(i32, &x1, &y1);
    }
    if (x0 > x1) {
        std.mem.swap(i32, &x0, &x1);
        std.mem.swap(i32, &y0, &y1);
    }
    const dx = x1 - x0;
    const dy: i32 = @intCast(@abs(y1 - y0));
    var err = @divTrunc(dx, 2);
    const step: i32 = if (y0 < y1) 1 else -1;
    while (x0 <= x1) : (x0 += 1) {
        if (steep) p.pixel(@intCast(y0), @intCast(x0), on) else p.pixel(@intCast(x0), @intCast(y0), on);
        err -= dy;
        if (err < 0) {
            err += dx;
            y0 += step;
        }
    }
}
pub fn fillTriangle(p: *R, ax: i16, ay: i16, bx: i16, by: i16, cx: i16, cy: i16, on: bool) void {
    var x0: i32 = ax;
    var y0: i32 = ay;
    var x1: i32 = bx;
    var y1: i32 = by;
    var x2: i32 = cx;
    var y2: i32 = cy;
    if (y0 > y1) {
        std.mem.swap(i32, &y0, &y1);
        std.mem.swap(i32, &x0, &x1);
    }
    if (y1 > y2) {
        std.mem.swap(i32, &y2, &y1);
        std.mem.swap(i32, &x2, &x1);
    }
    if (y0 > y1) {
        std.mem.swap(i32, &y0, &y1);
        std.mem.swap(i32, &x0, &x1);
    }
    if (y0 == y2) {
        span(p, @min(x0, @min(x1, x2)), @max(x0, @max(x1, x2)), y0, on);
        return;
    }
    const cross1 = @as(i64, x1 - x0) * (y2 - y0);
    const cross2 = @as(i64, x2 - x0) * (y1 - y0);
    if (cross1 == cross2) {
        line(p, @intCast(x0), @intCast(y0), @intCast(x2), @intCast(y2), on);
        return;
    }
    var dy1 = y1 - y0;
    var dy2 = y2 - y0;
    const change = cross1 > cross2;
    var dx1: i32 = @intCast(@abs(x1 - x0));
    var dx2: i32 = @intCast(@abs(x2 - x0));
    var step1: i32 = if (x1 < x0) -1 else 1;
    var step2: i32 = if (x2 < x0) -1 else 1;
    var a = x0;
    var b = x0;
    if (change) {
        std.mem.swap(i32, &dx1, &dx2);
        std.mem.swap(i32, &dy1, &dy2);
        std.mem.swap(i32, &step1, &step2);
    }
    var err1 = @divTrunc(@max(dx1, dy1), 2) + (if (step1 < 0) @min(dx1, dy1) else dx1);
    var err2 = @divTrunc(@max(dx2, dy2), 2) + (if (step2 > 0) @min(dx2, dy2) else dx2);
    while (y0 < y1) : (y0 += 1) {
        err1 -= dx1;
        while (err1 < 0) {
            err1 += dy1;
            a += step1;
        }
        err2 -= dx2;
        while (err2 < 0) {
            err2 += dy2;
            b += step2;
        }
        span(p, a, b, y0, on);
    }
    if (change) {
        b = x1;
        step2 = if (x2 < x1) -1 else 1;
        dx2 = @intCast(@abs(x2 - x1));
        dy2 = y2 - y1;
        err2 = @divTrunc(@max(dx2, dy2), 2) + (if (step2 > 0) @min(dx2, dy2) else dx2);
    } else {
        a = x1;
        step1 = if (x2 < x1) -1 else 1;
        dx1 = @intCast(@abs(x2 - x1));
        dy1 = y2 - y1;
        err1 = @divTrunc(@max(dx1, dy1), 2) + (if (step1 < 0) @min(dx1, dy1) else dx1);
    }
    while (y0 <= y2) : (y0 += 1) {
        err1 -= dx1;
        while (err1 < 0) {
            err1 += dy1;
            a += step1;
            if (a == x2) break;
        }
        err2 -= dx2;
        while (err2 < 0) {
            err2 += dy2;
            b += step2;
            if (b == x2) break;
        }
        span(p, a, b, y0, on);
    }
}
fn span(p: *R, a: i32, b: i32, y: i32, on: bool) void {
    if (y < p.clip.y or y >= @as(i32, p.clip.y) + p.clip.h) return;
    const left = @max(a, p.clip.x);
    const right = @min(b, @as(i32, p.clip.x) + p.clip.w - 1);
    if (left <= right) p.hline(@intCast(left), @intCast(y), @intCast(right - left + 1), on);
}

pub fn circle(p: *R, x: i16, y: i16, radius: i16, on: bool) void {
    if (radius < 0) return;
    if (radius == 0) {
        p.pixel(x, y, on);
        return;
    }
    var r = radius;
    var f: i16 = 1 - r;
    var dy: i16 = -2 * r;
    var dx: i16 = 1;
    var i: i16 = 0;
    var j: i16 = -1;
    while (true) {
        while (f < 0) {
            i += 1;
            dx += 2;
            f += dx;
        }
        dy += 2;
        f += dy;
        p.hline(x - i, y + r, i - j, on);
        p.hline(x - i, y - r, i - j, on);
        p.hline(x + j + 1, y - r, i - j, on);
        p.hline(x + j + 1, y + r, i - j, on);
        p.vline(x + r, y + j + 1, i - j, on);
        p.vline(x + r, y - i, i - j, on);
        p.vline(x - r, y - i, i - j, on);
        p.vline(x - r, y + j + 1, i - j, on);
        j = i;
        r -= 1;
        if (i >= r) break;
    }
}
pub fn fillCircle(p: *R, x: i16, y: i16, radius: i16, on: bool) void {
    if (radius < 0) return;
    p.hline(x - radius, y, 2 * radius + 1, on);
    if (radius == 0) return;
    var r = radius;
    var f: i16 = 1 - r;
    var dy: i16 = -2 * r;
    var dx: i16 = 1;
    var i: i16 = 0;
    while (true) {
        var len: i16 = 0;
        while (f < 0) {
            dx += 2;
            f += dx;
            len += 1;
        }
        i += len;
        dy += 2;
        f += dy;
        if (len > 0) {
            p.fillRect(.{ .x = x - r, .y = y + i - len + 1, .w = 2 * r + 1, .h = len }, on);
            p.fillRect(.{ .x = x - r, .y = y - i, .w = 2 * r + 1, .h = len }, on);
        }
        p.hline(x - i, y + r, 2 * i + 1, on);
        p.hline(x - i, y - r, 2 * i + 1, on);
        r -= 1;
        if (i >= r) break;
    }
}
pub fn roundRect(p: *R, x: i16, y: i16, w: i16, h: i16, radius: i16, on: bool, filled: bool) void {
    if (w <= 0 or h <= 0 or radius < 0) return;
    if (radius == 0) {
        if (filled) p.fillRect(.{ .x = x, .y = y, .w = w, .h = h }, on) else p.rect(.{ .x = x, .y = y, .w = w, .h = h }, on);
        return;
    }
    var r: i16 = @min(radius, @divTrunc(@min(w, h), 2));
    const x0 = x + r;
    const x1 = x + w - 1 - r;
    const y0 = y + r;
    const y1 = y + h - 1 - r;
    var f: i16 = 1 - r;
    var dy: i16 = -2 * r;
    var dx: i16 = 1;
    var len: i16 = 0;
    const delta = w - 2 * r;
    if (filled) p.fillRect(.{ .x = x, .y = y0, .w = w, .h = h - 2 * r }, on) else {
        p.vline(x, y0 + 1, h - 2 * r - 2, on);
        p.vline(x + w - 1, y0 + 1, h - 2 * r - 2, on);
        p.hline(x0 + 1, y, w - 2 * r - 2, on);
        p.hline(x0 + 1, y + h - 1, w - 2 * r - 2, on);
    }
    var i: i16 = 0;
    while (i <= r) : (i += 1) {
        len += 1;
        if (f >= 0) {
            if (filled) {
                p.fillRect(.{ .x = x0 - r, .y = y0 - i, .w = 2 * r + delta, .h = len }, on);
                p.fillRect(.{ .x = x0 - r, .y = y1 + i - len + 1, .w = 2 * r + delta, .h = len }, on);
                if (i == r) break;
                len = 0;
                p.hline(x0 - i, y1 + r, 2 * i + delta, on);
                dy += 2;
                f += dy;
                p.hline(x0 - i, y0 - r, 2 * i + delta, on);
                r -= 1;
            } else {
                p.hline(x0 - i, y0 - r, len, on);
                p.hline(x0 - i, y1 + r, len, on);
                p.hline(x1 + i - len + 1, y1 + r, len, on);
                p.hline(x1 + i - len + 1, y0 - r, len, on);
                p.vline(x1 + r, y1 + i - len + 1, len, on);
                p.vline(x0 - r, y1 + i - len + 1, len, on);
                p.vline(x1 + r, y0 - i, len, on);
                p.vline(x0 - r, y0 - i, len, on);
                len = 0;
                r -= 1;
                dy += 2;
                f += dy;
            }
        }
        dx += 2;
        f += dx;
    }
}

test "compatible integer raster obeys clip, inclusive line endpoints and triangle spans" {
    var pixels: [128]u8 = @splat(0);
    var surface = try @import("../surface.zig").Mono1.init(&pixels, 32, 32);
    var p = R.init(&surface);
    p.setClip(.{ .x = 2, .y = 2, .w = 28, .h = 28 });
    fillCircle(&p, 2, 2, 3, true);
    try std.testing.expect(surface.get(2, 2));
    try std.testing.expect(!surface.get(1, 2));
    @memset(&pixels, 0);
    line(&p, 3, 3, 9, 6, true);
    try std.testing.expect(surface.get(3, 3));
    try std.testing.expect(surface.get(9, 6));
    try std.testing.expect(!surface.get(9, 5));
    @memset(&pixels, 0);
    fillTriangle(&p, 8, 4, 4, 8, 12, 8, true);
    for (4..9) |yy| {
        const y: i16 = @intCast(yy);
        for (2..30) |xx| {
            const x: i16 = @intCast(xx);
            try std.testing.expectEqual(x >= 8 - (y - 4) and x <= 8 + (y - 4), surface.get(x, y));
        }
    }
    @memset(&pixels, 0);
    roundRect(&p, 4, 4, 12, 12, 3, true, true);
    try std.testing.expect(surface.get(8, 4));
    try std.testing.expect(!surface.get(4, 4));
    try std.testing.expect(surface.get(4, 8));
    @memset(&pixels, 0);
    circle(&p, 8, 8, -1, true);
    fillCircle(&p, 8, 8, -1, true);
    try std.testing.expectEqual(@as(u8, 0), pixels[0]);
}
