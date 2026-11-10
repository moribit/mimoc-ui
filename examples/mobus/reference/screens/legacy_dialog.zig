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
    const factory = s.variant >= 2;
    const button_y: i16 = if (factory) 44 else 34;
    text(r, .font2, 64, if (factory) 0 else 10, if (factory) "Factory Reset?" else "Confirm?", true, false, true, false);
    if (factory) text(r, .font2, 64, 14, "Erase settings?", true, false, true, false);
    for ([_]i16{ 12, 76 }, [_][]const u8{ "No", "Yes" }, 0..) |x, label, i| {
        const active = i == s.variant % 2;
        raster.roundRect(r, x, button_y, 40, 18, 3, active, true);
        raster.roundRect(r, x, button_y, 40, 18, 3, true, false);
        text(r, .font2, x + 20, button_y + 2, label, true, false, !active, active);
    }
}
