const std = @import("std");
const v = @import("view.zig");
const rt = @import("runtime.zig");
const headless = @import("renderers/headless.zig");
const animation = @import("animation.zig");
const navigation = @import("navigation.zig");
const scroll = @import("scroll.zig");
const transition = @import("transition.zig");

const AnimatedUi = rt.Runtime(.{ .max_nodes = 16, .max_animations = 4 });
fn animatedScene(ui: *AnimatedUi, x: i16) !void {
    var b = ui.beginView();
    try b.begin(1, .stack, 0, 0, .start);
    try b.add(.{ .id = 2, .kind = .filled_rect, .min_size = .{ .w = 4, .h = 4 }, .offset = .{ .x = x }, .animation = animation.Animation.linear(100) });
    b.end();
    try ui.finishView(&b);
}

test "headless snapshot and page rendering match" {
    var builder = v.Builder(8).init();
    try builder.begin(1, .column, 0, 0, .start);
    try builder.add(.{ .id = 2, .kind = .rect, .min_size = .{ .w = 3, .h = 3 } });
    builder.end();
    var ui = rt.Runtime(8){};
    ui.viewport = .{ .w = 8, .h = 8 };
    try ui.setView(&builder);
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
    try ui.setView(&builder);
    var full: [1024]u8 = undefined;
    try headless.render(&ui, &full, 128, 64);
    for (0..8) |page_index| {
        var page: [128]u8 = undefined;
        try headless.renderPage(&ui, &page, 128, @intCast(page_index));
        try std.testing.expectEqualSlices(u8, full[page_index * 128 ..][0..128], &page);
    }
}

test "fixed memory footprints" {
    try std.testing.expectEqual(@as(usize, 36), @sizeOf(animation.Track));
    const Screen = enum(u8) { home, contacts, chat };
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(navigation.Navigation(Screen, 8).Entry));
    try std.testing.expectEqual(@as(usize, 66), @sizeOf(navigation.Navigation(Screen, 8)));
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(scroll.ScrollState));
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(transition.Transition));
    if (@sizeOf(usize) == 8) {
        try std.testing.expectEqual(@as(usize, 48), @sizeOf(v.Node));
        try std.testing.expectEqual(@as(usize, 936), @sizeOf(AnimatedUi));
        try std.testing.expectEqual(@as(usize, 48), @sizeOf(v.InPlaceBuilder(16)));
    }
}

test "in-place builder uses runtime storage" {
    var ui = rt.Runtime(4){};
    var b = ui.beginView();
    try b.begin(1, .column, 0, 1, .start);
    try b.add(.{ .id = 2, .kind = .button, .text = "OK" });
    b.end();
    try ui.finishView(&b);
    try std.testing.expectEqual(@as(u16, 2), ui.nodeCount());
    try std.testing.expectEqual(@as(?u16, 2), ui.focused_id);
}

test "linear animation uses elapsed time and freezes rendering" {
    var ui = AnimatedUi{};
    ui.update(0);
    try animatedScene(&ui, 0);
    try std.testing.expectEqual(@as(u16, 0), ui.activeAnimationCount());
    try animatedScene(&ui, 80);
    try std.testing.expectEqual(@as(i16, 0), ui.presentationRect(2).?.x);
    ui.update(50);
    try std.testing.expectEqual(@as(i16, 40), ui.presentationRect(2).?.x);
    const before = ui.presentationRect(2).?;
    var full: [1024]u8 = undefined;
    try headless.render(&ui, &full, 128, 64);
    for (0..8) |index| {
        var page: [128]u8 = undefined;
        try headless.renderPage(&ui, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, full[index * 128 ..][0..128], &page);
    }
    try std.testing.expectEqual(before, ui.presentationRect(2).?);
    ui.update(100);
    try std.testing.expectEqual(@as(i16, 80), ui.presentationRect(2).?.x);
    try std.testing.expectEqual(@as(u16, 0), ui.activeAnimationCount());
}

test "ease curves are monotonic and end exactly" {
    const specs = [_]animation.Animation{
        animation.Animation.easeIn(100),
        animation.Animation.easeOut(100),
        animation.Animation.easeInOut(100),
    };
    for (specs) |spec| {
        var previous: u32 = 0;
        for (0..101) |ms| {
            const value = animation.eased(animation.progress(@intCast(ms), 0, spec), spec);
            try std.testing.expect(value >= previous);
            previous = value;
        }
        try std.testing.expectEqual(@as(u32, 65535), previous);
    }
    const spring = animation.Animation.spring(100, 128);
    try std.testing.expectEqual(@as(u32, 0), animation.eased(0, spring));
    try std.testing.expectEqual(@as(u32, 65535), animation.eased(65535, spring));
    try std.testing.expect(animation.eased(32768, spring) > 65535);
}

test "low FPS delayed frame and clock wrap reach target" {
    var ui = AnimatedUi{};
    ui.update(0);
    try animatedScene(&ui, 0);
    try animatedScene(&ui, 80);
    ui.update(200);
    try std.testing.expectEqual(@as(i16, 80), ui.presentationRect(2).?.x);
    ui.update(0xfffffff0);
    try animatedScene(&ui, 0);
    ui.update(0x00000022);
    try std.testing.expectEqual(@as(i16, 40), ui.presentationRect(2).?.x);
    ui.update(0x00000054);
    try std.testing.expectEqual(@as(i16, 0), ui.presentationRect(2).?.x);
}

test "retarget starts from current presentation and interpolates size" {
    var ui = AnimatedUi{};
    ui.update(0);
    try animatedScene(&ui, 0);
    try animatedScene(&ui, 80);
    ui.update(50);
    try animatedScene(&ui, 20);
    try std.testing.expectEqual(@as(i16, 40), ui.presentationRect(2).?.x);
    ui.update(100);
    try std.testing.expectEqual(@as(i16, 30), ui.presentationRect(2).?.x);
    ui.update(150);
    try std.testing.expectEqual(@as(i16, 20), ui.presentationRect(2).?.x);

    var first = v.Builder(16).init();
    try first.begin(1, .stack, 0, 0, .start);
    try first.add(.{ .id = 2, .kind = .rect, .min_size = .{ .w = 4, .h = 4 }, .animation = animation.Animation.linear(100) });
    first.end();
    try ui.setView(&first);
    var second = v.Builder(16).init();
    try second.begin(1, .stack, 0, 0, .start);
    try second.add(.{ .id = 2, .kind = .rect, .min_size = .{ .w = 14, .h = 10 }, .animation = animation.Animation.linear(100) });
    second.end();
    try ui.setView(&second);
    ui.update(200);
    try std.testing.expectEqual(@as(i16, 9), ui.presentationRect(2).?.w);
    try std.testing.expectEqual(@as(i16, 7), ui.presentationRect(2).?.h);
}

test "duplicate IDs are rejected" {
    var ui = rt.Runtime(4){};
    var b = ui.beginView();
    try b.begin(1, .column, 0, 0, .start);
    try b.add(.{ .id = 2, .kind = .text, .text = "A" });
    try b.add(.{ .id = 2, .kind = .text, .text = "B" });
    b.end();
    try std.testing.expectError(error.DuplicateId, ui.finishView(&b));
}
