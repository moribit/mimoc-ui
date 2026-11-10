//! Frozen reference geometry. Do not apply design-system conventions here.
const std = @import("std");
const ui = @import("mimoc_ui");
pub const catalog = @import("catalog.zig");
pub const fixtures = @import("fixtures.zig");
pub const Scenario = catalog.Scenario;
const R = ui.mono1.Renderer;

pub fn render(s: Scenario, f: fixtures.Fixture, pixels: *[1024]u8) void {
    pixels.* = @splat(0);
    var surface = ui.surface.Mono1.init(pixels, 128, 64) catch unreachable;
    var r = R.init(&surface);
    switch (s.screen) {
        .menu => @import("screens/legacy_menu.zig").render(&r, s, f),
        .contacts => @import("screens/legacy_contacts.zig").render(&r, s, f),
        .chat => @import("screens/legacy_chat.zig").render(&r, s, f),
        .settings => @import("screens/legacy_settings.zig").render(&r, s),
        .dialog => @import("screens/legacy_dialog.zig").render(&r, s),
        .profile => @import("screens/legacy_profile.zig").render(&r, s),
        .tra => @import("screens/legacy_tra.zig").render(&r, s),
        .ehagaki => @import("screens/legacy_ehagaki.zig").render(&r, s),
        .rooms => @import("screens/legacy_rooms.zig").render(&r, s),
        .composer => @import("screens/legacy_composer.zig").render(&r, s),
        .wifi => @import("screens/legacy_wifi.zig").render(&r, s),
        .text => @import("screens/legacy_textScreen.zig").render(&r, s),
        .qsp, .qsp_compose, .cq, .synth, .ehagaki_browse, .ehagaki_edit, .ehagaki_canvas, .factory, .firmware, .profile_product, .draw, .realtime, .open_compose => @import("screens/product.zig").render(&r, @import("product_fixtures.zig").all[s.variant]),
    }
}
pub fn mismatch(a: []const u8, b: []const u8) usize {
    var n: usize = 0;
    for (a, b) |x, y| n += @popCount(x ^ y);
    return n;
}

test "reference renders 100 times without time or external-state drift" {
    for (catalog.scenarios) |s| {
        var first: [1024]u8 = undefined;
        render(s, fixtures.defaults, &first);
        for (0..100) |_| {
            var next: [1024]u8 = undefined;
            render(s, fixtures.defaults, &next);
            try std.testing.expectEqualSlices(u8, &first, &next);
        }
    }
}
test "reference matches independently captured C++ OLED buffers" {
    var failed = false;
    for (catalog.scenarios) |s| {
        if (s.verification != .verified) continue;
        var actual: [1024]u8 = undefined;
        render(s, fixtures.defaults, &actual);
        if (!std.mem.eql(u8, s.expected, &actual)) {
            std.debug.print("{s}: {d} mismatched pixels\n", .{ s.name, mismatch(s.expected, &actual) });
            failed = true;
        }
    }
    if (failed) return error.ReferenceMismatch;
}

test "all required product surfaces have captured or explicitly source-faithful coverage" {
    try std.testing.expect(catalog.gate());
    for (catalog.scenarios) |s| {
        if (s.verification == .verified) try std.testing.expectEqual(@as(usize, 1024), s.expected.len);
        try std.testing.expect(s.verification != .unverified);
    }
}
