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
    if (s.variant < 3) {
        text(r, .font2, 64, 18, "Wi-Fi", true, false, true, false);
        text(r, .font2, 64, 34, switch (s.variant) {
            0 => "Scanning...",
            1 => "Connecting...",
            else => "Failed / retry",
        }, true, false, true, false);
        return;
    }
    if (s.variant < 6) {
        const rows = [_][]const u8{ "Wi-Fi", "Mobus-Home", "Demo", "Cafe", "Other" };
        const selected: usize = switch (s.variant) {
            3 => 0,
            4 => 2,
            else => 4,
        };
        const first: usize = if (selected >= 4) selected - 3 else 0;
        for (first..@min(first + 4, rows.len)) |i| {
            const y: i16 = @intCast((i - first) * 16);
            const active = i == selected;
            if (active) r.fillRect(.{ .x = 0, .y = y, .w = 128, .h = 16 }, true);
            text(r, .font2, 10, y, rows[i], false, true, !active, active);
        }
        return;
    }
    text(r, .font2, 0, 0, "Password", false, true, true, false);
    r.hline(0, 14, 128, true);
    r.hline(0, 45, 128, true);
    text(r, .font2, 0, 15, "******", false, true, true, false);
    const row = "abcdefghijklm";
    for (row, 0..) |_, i| {
        text(r, .font2, @as(i16, @intCast(i)) * 8, 46, row[i .. i + 1], false, true, !(s.variant == 6 and i == 1), s.variant == 6 and i == 1);
    }
    const active = s.variant == 7;
    r.fillRect(.{ .x = 118, .y = 45, .w = 10, .h = 16 }, active);
    raster.fillTriangle(r, 114, 52, 118, 45, 118, 60, active);
    raster.line(r, 118, 45, 127, 45, !active);
    raster.line(r, 127, 45, 127, 60, !active);
    raster.line(r, 127, 60, 118, 60, !active);
    raster.line(r, 118, 45, 114, 52, !active);
    raster.line(r, 114, 52, 118, 60, !active);
    raster.line(r, 120, 50, 124, 54, !active);
    raster.line(r, 124, 50, 120, 54, !active);
}
