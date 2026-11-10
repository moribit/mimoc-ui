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
    text(r, .custom7, 48, 9, "Mode", false, false, true, false);
    r.rect(.{ .x = 5, .y = 5, .w = 118, .h = 54 }, true);
    r.hline(5, 20, 118, true);
    r.rect(.{ .x = 41, .y = 20, .w = 40, .h = 23 }, true);
    r.hline(5, 42, 118, true);
    if (s.variant == 3) {
        r.line(10, 47, 22, 55, true);
        r.line(22, 47, 10, 55, true);
    } else {
        for (0..f.radio_level) |i| {
            const n: i16 = @intCast(i);
            r.fillRect(.{ .x = 10 + 3 * n, .y = 52 - 2 * n, .w = 2, .h = 4 + 2 * n }, true);
        }
    }
    var buf: [8]u8 = undefined;
    const percent = std.fmt.bufPrint(&buf, "{d}%", .{f.battery_percent}) catch unreachable;
    const font = fonts.Font{ .kind = .custom7 };
    text(r, .custom7, 46 - font.measure(percent), 49, percent, false, false, true, false);
    text(r, .custom7, 73, 49, f.time, false, false, true, false);
    const positions = [_]i16{ 15, 53, 93 };
    const labels = [_][]const u8{ "TUN", "SET", "TRA" };
    text(r, .custom7, positions[if (s.variant == 1) @as(usize, 1) else 0] - 6, 29, "[   ]", false, false, true, false);
    for (positions, labels) |x, label| text(r, .custom7, x, 29, label, false, false, true, false);
    if (s.variant == 2) raster.fillCircle(r, 37, 25, 4, false);
}
