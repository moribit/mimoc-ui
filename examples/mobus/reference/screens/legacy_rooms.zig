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
    text(r, .font2, 64, 0, "ROOMS", true, false, true, false);
    r.hline(0, 12, 128, true);
    for ([_][]const u8{ "LOBBY", "OKINAWA", "CQ" }, 0..) |label, i| {
        const y: i16 = 16 + @as(i16, @intCast(i)) * 12;
        const active = i == s.variant;
        if (active) r.fillRect(.{ .x = 0, .y = y - 2, .w = 128, .h = 12 }, true);
        text(r, .font2, 4, y, label, false, true, !active, active);
    }
    text(r, .font2, 0, 56, "Enter:Join Back:Exit", false, true, true, false);
}
