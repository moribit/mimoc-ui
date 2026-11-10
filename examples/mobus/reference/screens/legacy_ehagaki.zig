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
    text(r, .font2, 64, 0, "Ehagaki", true, false, true, false);
    for ([_][]const u8{ "POST", "MY POST", "TIMELINE" }, 0..) |label, i| {
        const y: i16 = 16 + @as(i16, @intCast(i)) * 16;
        const active = i == if (s.variant == 1) @as(usize, 2) else 0;
        if (active) raster.roundRect(r, 9, y - 1, 110, 15, 2, true, true);
        text(r, .custom7, 64, y, label, true, false, !active, active);
    }
}
