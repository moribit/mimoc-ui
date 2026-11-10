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
pub fn render(r: *R, s: Scenario) void {
    text(r, .font2, 2, 0, if (s.variant == 1) "BPM:120 PLAY" else "BPM:120 EDIT", false, false, true, false);
    r.hline(0, 12, 128, true);
    for (0..16) |i| {
        const x: i16 = 4 + @as(i16, @intCast(i)) * 7;
        const active = i % 3 == 1;
        if (s.variant == 1 and i == 4) r.fillRect(.{ .x = x, .y = 15, .w = 5, .h = 3 }, true);
        if (active) r.fillRect(.{ .x = x, .y = 20, .w = 5, .h = 16 }, true) else r.rect(.{ .x = x, .y = 20, .w = 5, .h = 16 }, true);
        text(r, .font2, x + 2, 22, if (i % 3 != 0) "A" else "-", true, false, !active, active);
        if (i == 2) r.rect(.{ .x = x - 1, .y = 18, .w = 7, .h = 20 }, true);
    }
    text(r, .font2, 64, 40, "S:03 PIANO N:60", true, false, true, false);
    text(r, .font2, 64, 52, "TYPE:Inst ENT:Play", true, false, true, false);
}
