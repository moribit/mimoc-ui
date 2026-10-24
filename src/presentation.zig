//! Pixel-exact, allocation-free presentation helpers for any Mono1 surface.
const std = @import("std");
const Mono1 = @import("surface.zig").Mono1;
pub const Rotation = enum { deg0, deg90, deg180, deg270 };
pub fn rotate(src: *const Mono1, dst: *Mono1, rotation: Rotation) void {
    dst.clear(false);
    var y: i16 = 0;
    while (y < src.height) : (y += 1) {
        var x: i16 = 0;
        while (x < src.width) : (x += 1) {
            const p: [2]i16 = switch (rotation) {
                .deg0 => .{ x, y },
                .deg90 => .{ src.height - 1 - y, x },
                .deg180 => .{ src.width - 1 - x, src.height - 1 - y },
                .deg270 => .{ y, src.width - 1 - x },
            };
            dst.pixel(p[0], p[1], src.get(x, y));
        }
    }
}
/// Returns zero when even 1x does not fit; callers must clip or enforce minimum size.
pub fn integerScale(view_w: u32, view_h: u32, logical_w: u32, logical_h: u32) u32 {
    if (logical_w == 0 or logical_h == 0) return 0;
    return @min(view_w / logical_w, view_h / logical_h);
}
test "portrait and legacy Mono1 rotation round trip" {
    var a: [1024]u8 = @splat(0);
    var b: [1024]u8 = @splat(0);
    var c: [1024]u8 = @splat(0);
    var src = try Mono1.init(&a, 128, 64);
    var dst = try Mono1.init(&b, 64, 128);
    var out = try Mono1.init(&c, 128, 64);
    src.pixel(0, 0, true);
    src.pixel(127, 63, true);
    src.pixel(72, 35, true);
    rotate(&src, &dst, .deg90);
    try std.testing.expect(dst.get(28, 72));
    rotate(&dst, &out, .deg270);
    try std.testing.expectEqualSlices(u8, &a, &c);
    try std.testing.expectEqual(@as(u32, 8), integerScale(1920, 1080, 64, 128));
    try std.testing.expectEqual(@as(u32, 0), integerScale(32, 64, 64, 128));
}
