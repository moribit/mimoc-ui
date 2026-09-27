const std = @import("std");
const v = @import("view.zig");
const rt = @import("runtime.zig");
const headless = @import("renderers/headless.zig");

test "headless snapshot and page rendering match" {
    var builder = v.Builder(8).init();
    try builder.begin(1, .column, 0, 0, .start);
    try builder.add(.{ .id = 2, .kind = .rect, .min_size = .{ .w = 3, .h = 3 } });
    builder.end();
    var ui = rt.Runtime(8){};
    ui.viewport = .{ .w = 8, .h = 8 };
    ui.setView(&builder);
    var full: [8]u8 = undefined;
    try headless.render(&ui, &full, 8, 8);
    try std.testing.expectEqualSlices(u8, &.{ 0x07, 0x05, 0x07, 0, 0, 0, 0, 0 }, &full);
    var page: [8]u8 = undefined;
    try headless.renderPage(&ui, &page, 8, 0);
    try std.testing.expectEqualSlices(u8, &full, &page);
}

test "full framebuffer equals eight independently rendered pages" {
    var builder = v.Builder(8).init();
    try builder.begin(1, .column, 2, 1, .start);
    try builder.add(.{ .id = 2, .kind = .text, .text = "PAGE" });
    try builder.add(.{ .id = 3, .kind = .button, .text = "OK" });
    builder.end();
    var ui = rt.Runtime(8){};
    ui.setView(&builder);
    var full: [1024]u8 = undefined;
    try headless.render(&ui, &full, 128, 64);
    for (0..8) |page_index| {
        var page: [128]u8 = undefined;
        try headless.renderPage(&ui, &page, 128, @intCast(page_index));
        try std.testing.expectEqualSlices(u8, full[page_index * 128 ..][0..128], &page);
    }
}

test "fixed memory footprints" {
    try std.testing.expect(@sizeOf(rt.Runtime(16)) <= 1024);
    try std.testing.expect(@sizeOf(v.InPlaceBuilder(16)) <= 64);
}

test "in-place builder uses runtime storage" {
    var ui = rt.Runtime(4){};
    var b = ui.beginView();
    try b.begin(1, .column, 0, 1, .start);
    try b.add(.{ .id = 2, .kind = .button, .text = "OK" });
    b.end();
    ui.finishView(&b);
    try std.testing.expectEqual(@as(u16, 2), ui.nodeCount());
    try std.testing.expectEqual(@as(?u16, 2), ui.focused_id);
}
