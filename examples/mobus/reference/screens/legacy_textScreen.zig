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
    switch (s.variant) {
        0 => text(r, .font2, 64, 26, "Mo-Bus", true, false, true, false),
        1 => {
            text(r, .font2, 64, 18, "Mo-Bus", true, false, true, false);
            text(r, .font2, 64, 34, "Ready", true, false, true, false);
        },
        2, 3 => {
            r.bitmap(52, 6, 24, 29, &@import("../icons.zig").offline);
            text(r, .font2, 64, 43, if (s.variant == 2) "OFFLINE" else "Error", true, false, true, false);
        },
        else => {},
    }
}
