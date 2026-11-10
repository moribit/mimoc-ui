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
    const labels = [_][]const u8{ "TYPING", "Local", "Eha", "Synth", "Mopp", "Maji" };
    const labels2 = [_][]const u8{ "", "CQ", "gaki", "", "ing", "mun" };
    for (labels, labels2, 0..) |label, second, i| {
        const x: i16 = 2 + @as(i16, @intCast(i % 3)) * 42;
        const y: i16 = 5 + @as(i16, @intCast(i / 3)) * 29;
        const active = i == if (s.variant == 1) @as(usize, 3) else 0;
        r.fillRect(.{ .x = x, .y = y, .w = 39, .h = 25 }, active);
        r.rect(.{ .x = x, .y = y, .w = 39, .h = 25 }, true);
        if (second.len > 0) {
            text(r, .custom7, x + 19, y + 3, label, true, false, !active, active);
            text(r, .custom7, x + 19, y + 13, second, true, false, !active, active);
        } else text(r, .custom7, x + 19, y + 8, label, true, false, !active, active);
    }
}
