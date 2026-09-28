const std = @import("std");
const g = @import("../geometry.zig");
const Mono1 = @import("../surface.zig").Mono1;

pub const Renderer = struct {
    pub const BitmapFormat = enum(u8) { row_msb, page_lsb };
    surface: *Mono1,
    clip: g.Rect,

    pub fn init(surface: *Mono1) Renderer {
        return .{ .surface = surface, .clip = .{ .x = 0, .y = @as(i16, surface.first_page) * 8, .w = surface.width, .h = surface.height } };
    }
    pub fn setClip(self: *Renderer, bounds: g.Rect) void {
        self.clip = g.Rect.intersect(.{ .x = 0, .y = @as(i16, self.surface.first_page) * 8, .w = self.surface.width, .h = self.surface.height }, bounds);
    }
    pub fn pixel(self: *Renderer, x: i16, y: i16, on: bool) void {
        if (self.clip.contains(x, y)) self.surface.pixel(x, y, on);
    }
    pub fn hline(self: *Renderer, x: i16, y: i16, width: i16, on: bool) void {
        var i: i32 = 0;
        while (i < width) : (i += 1) self.pixel(@intCast(@as(i32, x) + i), y, on);
    }
    pub fn vline(self: *Renderer, x: i16, y: i16, height: i16, on: bool) void {
        var i: i32 = 0;
        while (i < height) : (i += 1) self.pixel(x, @intCast(@as(i32, y) + i), on);
    }
    pub fn line(self: *Renderer, x0_: i16, y0_: i16, x1: i16, y1: i16, on: bool) void {
        var x: i32 = x0_;
        var y: i32 = y0_;
        const dx = @abs(@as(i32, x1) - x);
        const dy = @abs(@as(i32, y1) - y);
        const sx: i32 = if (x < x1) 1 else -1;
        const sy: i32 = if (y < y1) 1 else -1;
        var err: i32 = @as(i32, @intCast(dx)) - @as(i32, @intCast(dy));
        while (true) {
            if (x >= -32768 and x <= 32767 and y >= -32768 and y <= 32767) self.pixel(@intCast(x), @intCast(y), on);
            if (x == x1 and y == y1) break;
            const twice = err * 2;
            if (twice > -@as(i32, @intCast(dy))) {
                err -= @intCast(dy);
                x += sx;
            }
            if (twice < @as(i32, @intCast(dx))) {
                err += @intCast(dx);
                y += sy;
            }
        }
    }
    pub fn rect(self: *Renderer, r: g.Rect, on: bool) void {
        if (r.w <= 0 or r.h <= 0) return;
        self.hline(r.x, r.y, r.w, on);
        self.hline(r.x, @intCast(@as(i32, r.y) + r.h - 1), r.w, on);
        self.vline(r.x, r.y, r.h, on);
        self.vline(@intCast(@as(i32, r.x) + r.w - 1), r.y, r.h, on);
    }
    pub fn fillRect(self: *Renderer, r: g.Rect, on: bool) void {
        const clipped = g.Rect.intersect(self.clip, r);
        var y: i32 = clipped.y;
        while (y < @as(i32, clipped.y) + clipped.h) : (y += 1) self.hline(clipped.x, @intCast(y), clipped.w, on);
    }
    pub fn bitmap(self: *Renderer, x: i16, y: i16, width: u8, height: u8, bytes: []const u8) void {
        self.bitmapStrided(x, y, width, height, @intCast((@as(u16, width) + 7) / 8), bytes);
    }
    pub fn bitmapStrided(self: *Renderer, x: i16, y: i16, width: u8, height: u8, stride: u8, bytes: []const u8) void {
        self.bitmapFormat(x, y, width, height, stride, bytes, .row_msb);
    }
    pub fn bitmapFormat(self: *Renderer, x: i16, y: i16, width: u8, height: u8, stride: u8, bytes: []const u8, format: BitmapFormat) void {
        const rows: usize = if (format == .row_msb) height else (@as(usize, height) + 7) / 8;
        const minimum_stride: usize = if (format == .row_msb) (@as(usize, width) + 7) / 8 else width;
        if (stride < minimum_stride or bytes.len < @as(usize, stride) * rows) return;
        for (0..height) |row| for (0..width) |col| {
            const index: usize = if (format == .row_msb) row * @as(usize, stride) + col / 8 else (row / 8) * @as(usize, stride) + col;
            const bit: u3 = if (format == .row_msb) @intCast(7 - (col % 8)) else @intCast(row % 8);
            if (bytes[index] & (@as(u8, 1) << bit) != 0)
                self.pixel(@intCast(@as(i32, x) + @as(i32, @intCast(col))), @intCast(@as(i32, y) + @as(i32, @intCast(row))), true);
        };
    }
    pub fn circle(self: *Renderer, cx: i16, cy: i16, radius: i16, on: bool) void {
        if (radius < 0) return;
        var x: i32 = radius;
        var y: i32 = 0;
        var err: i32 = 1 - x;
        while (x >= y) : (y += 1) {
            const points = [_][2]i32{ .{ x, y }, .{ y, x }, .{ -y, x }, .{ -x, y }, .{ -x, -y }, .{ -y, -x }, .{ y, -x }, .{ x, -y } };
            for (points) |p| self.pixel(@intCast(@as(i32, cx) + p[0]), @intCast(@as(i32, cy) + p[1]), on);
            if (err < 0) err += 2 * y + 3 else {
                err += 2 * (y - x) + 5;
                x -= 1;
            }
        }
    }
};

test "primitives and clip" {
    var data = [_]u8{0} ** 8;
    var surface = try Mono1.init(&data, 8, 8);
    var r = Renderer.init(&surface);
    r.setClip(.{ .x = 2, .y = 2, .w = 3, .h = 3 });
    r.fillRect(.{ .x = 0, .y = 0, .w = 8, .h = 8 }, true);
    try std.testing.expect(!surface.get(1, 2));
    try std.testing.expect(surface.get(2, 2));
    try std.testing.expect(surface.get(4, 4));
    try std.testing.expect(!surface.get(5, 4));
}
