const std = @import("std");

pub const Point = struct { x: i16 = 0, y: i16 = 0 };
pub const Size = struct { w: i16 = 0, h: i16 = 0 };
pub const Rect = struct {
    x: i16 = 0,
    y: i16 = 0,
    w: i16 = 0,
    h: i16 = 0,

    pub fn contains(self: Rect, x: i16, y: i16) bool {
        return x >= self.x and y >= self.y and x < @as(i32, self.x) + self.w and y < @as(i32, self.y) + self.h;
    }
    pub fn intersect(a: Rect, b: Rect) Rect {
        const left = @max(@as(i32, a.x), b.x);
        const top = @max(@as(i32, a.y), b.y);
        const right = @min(@as(i32, a.x) + a.w, @as(i32, b.x) + b.w);
        const bottom = @min(@as(i32, a.y) + a.h, @as(i32, b.y) + b.h);
        return .{ .x = @intCast(left), .y = @intCast(top), .w = @intCast(@max(0, right - left)), .h = @intCast(@max(0, bottom - top)) };
    }
};

test "rect intersection" {
    const r = Rect.intersect(.{ .x = 0, .y = 0, .w = 10, .h = 10 }, .{ .x = 5, .y = 6, .w = 10, .h = 10 });
    try std.testing.expectEqual(Rect{ .x = 5, .y = 6, .w = 5, .h = 4 }, r);
}
