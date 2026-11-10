//! Frozen existing baseline renderer; geometry deliberately unchanged.
const std = @import("std");
const ui = @import("mimoc_ui");
const raster = ui.raster_compat;
const fonts = @import("../fonts.zig");
const fixtures = @import("../fixtures.zig");
const Scenario = @import("../catalog.zig").Scenario;
const R = ui.mono1.Renderer;
const text = @import("legacy_text.zig").text;
const shadedText = @import("legacy_text.zig").shadedText;
pub fn render(r: *R, s: Scenario, f: fixtures.Fixture) void {
    if (s.variant == 5) {
        text(r, .font2, 38, 26, "Loading", false, false, true, false);
        return;
    }
    r.rect(.{ .x = 30, .y = 2, .w = 68, .h = 18 }, true);
    text(r, .font2, 64, 3, if (s.variant == 1) "Pending" else f.contact, true, false, true, false);
    if (s.variant == 2) raster.fillCircle(r, 119, 8, 3, true);
    text(r, .font2, 32, 22, "QSP", false, false, true, false);
    text(r, .font2, 76, 22, "CQ", false, false, true, false);
    raster.circle(r, 64, 37, 7, true);
    if (s.variant == 4) raster.circle(r, 64, 37, 9, true);
    r.line(64, 37, if (s.variant == 3) 69 else 59, 32, true);
    r.hline(10, 54, 109, true);
    r.vline(10, 50, 9, true);
    r.vline(118, 50, 9, true);
    const bayer = [_]u8{ 8, 136, 40, 168, 200, 72, 232, 104, 56, 184, 24, 152, 248, 120, 216, 88 };
    for (0..10) |i| {
        const x: i16 = 10 + @as(i16, @intCast((108 * (i + 1)) / 11));
        // RGB565 0xC618 -> RGB332 Sprite -> RGB565 -> OLED gamma/Bayer.
        // Rotation 2 determines the physical dither phase. RGB565 0xDEDF
        // expands to (222,219,255); the original integer gamma formula gives 198.
        for (50..59) |yy| {
            const y: i16 = @intCast(yy);
            r.pixel(x, y, 256 <= @as(u16, 198) + bayer[@as(usize, @intCast((127 - x) & 3)) | (@as(usize, @intCast((63 - y) & 3)) << 2)]);
        }
        if (i == 0 and s.variant != 4) { // Original fillTriangle apex(19,60), base at y64.
            raster.fillTriangle(r, x, 60, x - 4, 64, x + 4, 64, true);
        }
        if (i == 0 and s.variant == 1) r.rect(.{ .x = x - 2, .y = 52, .w = 5, .h = 5 }, true);
        if (i == 0 and s.variant == 2) raster.fillCircle(r, x + 4, 48, 1, true);
    }
}
