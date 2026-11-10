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
    const labels = [_][]const u8{ "Profile", "Wi-Fi", "Sound", "Vibration", "Language", "Firmware" };
    const selected: usize = if (s.variant == 0) 0 else if (s.variant == 1) 2 else 5;
    const first: usize = if (selected >= 4) selected - 3 else 0;
    for (first..@min(first + 4, labels.len)) |i| {
        const y: i16 = @intCast((i - first) * 16);
        const active = i == selected;
        if (active) r.fillRect(.{ .x = 0, .y = y, .w = 128, .h = 16 }, true);
        text(r, .custom7, 2, y + 6, labels[i], false, false, !active, active);
        switch (i) {
            1 => raster.fillCircle(r, 116, y + 8, 3, !active),
            2 => {
                raster.fillCircle(r, 116, y + 8, 4, active);
                raster.circle(r, 116, y + 8, 3, !active);
            },
            3 => {
                for ([_]i16{ 111, 116, 121 }) |x| raster.fillCircle(r, x, y + 8, 1, !active);
            },
            4 => {
                const font = fonts.Font{ .kind = .custom7 };
                text(r, .custom7, 126 - font.measure("EN"), y + 6, "EN", false, false, !active, active);
            },
            else => {},
        }
    }
}
