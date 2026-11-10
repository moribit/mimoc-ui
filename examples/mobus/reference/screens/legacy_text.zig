const std = @import("std");
const ui = @import("mimoc_ui");
const raster = ui.raster_compat;
const fonts = @import("../fonts.zig");
const fixtures = @import("../fixtures.zig");
const Scenario = @import("../catalog.zig").Scenario;
const R = ui.mono1.Renderer;
pub fn text(r: *R, kind: fonts.Kind, x: i16, y: i16, str: []const u8, center: bool, printing: bool, fg: bool, bg: bool) void {
    shadedText(r, kind, x, y, str, center, printing, fg, bg, 255);
}
pub fn shadedText(r: *R, kind: fonts.Kind, x: i16, y: i16, str: []const u8, center: bool, printing: bool, fg: bool, bg: bool, gray: u8) void {
    var f = fonts.Font{ .kind = kind, .printing = printing, .background_gray = gray };
    f.draw(r, if (center) x - @divTrunc(f.measure(str), 2) else x, y, str, fg, bg);
}
