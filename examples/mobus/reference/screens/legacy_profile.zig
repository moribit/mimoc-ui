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
    const labels = [_][]const u8{ "Name:", "ID:", "Version:" };
    const values = [_][]const u8{ "Hazuki", "ABCD2345", "1.0" };
    for (labels, values, 0..) |label, value, i| {
        const y: i16 = @as(i16, @intCast(i)) * 28 - if (s.variant == 1) @as(i16, 28) else 0;
        if (y + 28 >= 0 and y < 64) {
            text(r, .font2, 0, y, label, false, true, true, false);
            text(r, .font2, 0, y + 14, value, false, true, true, false);
        }
    }
}
