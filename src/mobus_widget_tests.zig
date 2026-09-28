const std = @import("std");
const ui = @import("root.zig");

test "variable list mixed heights, partial and oversized items, clamp and empty" {
    const heights = [_]u16{ 5, 12, 4, 30 };
    const first = ui.scroll.variableVisibleRange(&heights, 0, 10);
    try std.testing.expectEqual(@as(usize, 0), first.first);
    try std.testing.expectEqual(@as(usize, 2), first.end);
    try std.testing.expectEqual(@as(i32, 51), first.total_height);
    const middle = ui.scroll.variableVisibleRange(&heights, 9, 10);
    try std.testing.expectEqual(@as(usize, 1), middle.first);
    try std.testing.expectEqual(@as(i32, 5), middle.first_y);
    try std.testing.expectEqual(@as(usize, 3), middle.end);
    const last = ui.scroll.variableVisibleRange(&heights, 1000, 10);
    try std.testing.expectEqual(@as(i32, 41), last.offset);
    try std.testing.expectEqual(@as(usize, 3), last.first);
    try std.testing.expectEqual(@as(usize, 4), last.end);
    const large = ui.scroll.variableVisibleRange(&[_]u16{50}, 25, 10);
    try std.testing.expectEqual(@as(usize, 0), large.first);
    try std.testing.expectEqual(@as(usize, 1), large.end);
    const empty = ui.scroll.variableVisibleRange(&.{}, 12, 10);
    try std.testing.expectEqual(@as(usize, 0), empty.end);
    try std.testing.expectEqual(@as(i32, 0), empty.offset);
}

test "wrap exact pixel fit, overflow, newline, UTF-8 and empty" {
    var exact = ui.wrap.Iterator{ .text = "HELLO WORLD", .font = .tiny5x7, .max_width = 66 };
    try std.testing.expectEqualStrings("HELLO WORLD", exact.next().?.bytes);
    try std.testing.expect(exact.next() == null);
    var one_less = ui.wrap.Iterator{ .text = "HELLO WORLD", .font = .tiny5x7, .max_width = 65 };
    try std.testing.expectEqualStrings("HELLO", one_less.next().?.bytes);
    try std.testing.expectEqualStrings("WORLD", one_less.next().?.bytes);
    var narrow = ui.wrap.Iterator{ .text = "HELLO WORLD", .font = .tiny5x7, .max_width = 30 };
    try std.testing.expectEqualStrings("HELLO", narrow.next().?.bytes);
    try std.testing.expectEqualStrings("WORLD", narrow.next().?.bytes);
    try std.testing.expectEqual(@as(u16, 2), ui.wrap.lineCount(.tiny5x7, "A\nB", 24));
    try std.testing.expectEqual(@as(i16, 16), ui.wrap.height(.tiny5x7, "A\nB", 24, 8));
    var utf = ui.wrap.Iterator{ .text = "AéB", .font = .tiny5x7, .max_width = 12 };
    try std.testing.expectEqualStrings("Aé", utf.next().?.bytes);
    try std.testing.expectEqualStrings("B", utf.next().?.bytes);
    var japanese = ui.wrap.Iterator{ .text = "日本語", .font = .tiny5x7, .max_width = 12 };
    try std.testing.expectEqualStrings("日本", japanese.next().?.bytes);
    try std.testing.expectEqualStrings("語", japanese.next().?.bytes);
    try std.testing.expectEqual(@as(i16, 12), ui.font.measure(.tiny5x7, "日本"));
    try std.testing.expectEqual(@as(u16, 0), ui.wrap.lineCount(.tiny5x7, "", 24));
}

test "scrollbar top middle bottom hidden and huge content" {
    const top = ui.scroll.scrollbar(40, 100, 0, 5);
    try std.testing.expect(top.visible);
    try std.testing.expectEqual(@as(i16, 16), top.height);
    try std.testing.expectEqual(@as(i16, 0), top.y);
    try std.testing.expectEqual(@as(i16, 12), ui.scroll.scrollbar(40, 100, 30, 5).y);
    try std.testing.expectEqual(@as(i16, 24), ui.scroll.scrollbar(40, 100, 60, 5).y);
    try std.testing.expect(!ui.scroll.scrollbar(40, 40, 0, 5).visible);
    try std.testing.expect(!ui.scroll.scrollbar(40, 20, 0, 5).visible);
    const huge = ui.scroll.scrollbar(64, 2147483647, 2147483647, 3);
    try std.testing.expectEqual(@as(i16, 3), huge.height);
    try std.testing.expectEqual(@as(i16, 61), huge.y);
}

test "bitmap stride, non-byte width, clipping and page boundary" {
    var full = [_]u8{0} ** 1024;
    var surface = try ui.surface.Mono1.init(&full, 128, 64);
    var r = ui.mono1.Renderer.init(&surface);
    const image = [_]u8{ 0x80, 0x08, 0x00, 0x01, 0x00, 0x00 };
    r.setClip(.{ .x = 10, .y = 7, .w = 13, .h = 2 });
    r.bitmapStrided(10, 7, 13, 2, 3, &image);
    try std.testing.expect(surface.get(10, 7));
    try std.testing.expect(surface.get(22, 7));
    try std.testing.expect(!surface.get(17, 7));
    try std.testing.expect(surface.get(17, 8));
    try std.testing.expect(!surface.get(18, 8));
    var page = [_]u8{0} ** 128;
    var page_surface = try ui.surface.Mono1.page(&page, 128, 1);
    var page_renderer = ui.mono1.Renderer.init(&page_surface);
    page_renderer.setClip(.{ .x = 10, .y = 7, .w = 13, .h = 2 });
    page_renderer.bitmapStrided(10, 7, 13, 2, 3, &image);
    try std.testing.expectEqualSlices(u8, full[128..256], &page);
    const page_image = [_]u8{ 0x01, 0x80, 0, 0, 0, 0, 0, 0, 0 };
    r.setClip(.{ .x = 0, .y = 0, .w = 128, .h = 64 });
    r.bitmapFormat(30, 10, 2, 8, 2, &page_image, .page_lsb);
    try std.testing.expect(surface.get(30, 10));
    try std.testing.expect(surface.get(31, 17));
}

test "tuner, knob, bitmap, wrapped text and scrollbar remain page-equivalent while animating" {
    const Preview = ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 });
    var display = Preview{};
    const markers = [_]ui.widgets.Marker{ .{}, .{ .pending = true }, .{ .unread = true } };
    const bitmap = [_]u8{ 0x80, 0x01, 0, 0 };
    display.update(0);
    for (0..2) |phase| {
        var b = display.beginView();
        try b.begin(1, .stack, 0, 0, .start);
        try ui.widgets.beginClip(&b, 2, .{ .w = 128, .h = 64 });
        try ui.widgets.tuner(&b, 10, .{ .markers = &markers, .selected = if (phase == 0) 0 else 2, .width = 100, .animation = ui.animation.Animation.linear(100) });
        b.nodes[2].offset = .{ .x = 10, .y = 2 };
        try ui.widgets.knob(&b, 20, .{ .value = if (phase == 0) 0 else 1, .animation = ui.animation.Animation.linear(100) });
        b.nodes[5].offset = .{ .x = 52, .y = 18 };
        try ui.widgets.wrappedText(&b, 30, "HELLO WORLD", 30);
        b.nodes[b.len - 1].offset = .{ .x = 3, .y = 40 };
        try ui.widgets.bitmap(&b, 31, .{ .width = 9, .height = 2, .stride = 2, .data = &bitmap });
        b.nodes[b.len - 1].offset = .{ .x = 110, .y = 7 };
        try ui.widgets.scrollbar(&b, 40, 30, 90, if (phase == 0) 0 else 60, 3);
        b.nodes[b.len - 3].offset = .{ .x = 123, .y = 20 };
        b.end();
        b.end();
        try display.finishView(&b);
    }
    const tuner_start = display.presentationRect(12).?;
    const knob_start = display.presentationRect(22).?;
    display.update(50);
    const tuner_mid = display.presentationRect(12).?;
    const knob_mid = display.presentationRect(22).?;
    try std.testing.expect(tuner_mid.x > tuner_start.x);
    try std.testing.expect(knob_mid.x > knob_start.x);
    var full: [1024]u8 = undefined;
    try ui.headless.render(&display, &full, 128, 64);
    for (0..8) |index| {
        var page: [128]u8 = undefined;
        try ui.headless.renderPage(&display, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, full[index * 128 ..][0..128], &page);
    }
    display.update(200);
    try std.testing.expectEqual(display.tracks[display.track_len - 1].to, display.tracks[display.track_len - 1].current);
    try std.testing.expect(display.presentationRect(12).?.x > tuner_mid.x);
}

test "tuner ticks and knob points cover first middle last at low FPS" {
    try std.testing.expect(ui.widgets.tunerTick(108, 10, 0) < ui.widgets.tunerTick(108, 10, 4));
    try std.testing.expect(ui.widgets.tunerTick(108, 10, 4) < ui.widgets.tunerTick(108, 10, 9));
    const first = ui.widgets.knobPoint(2, 0);
    const last = ui.widgets.knobPoint(2, 1);
    try std.testing.expect(first.x < last.x);
    const middle = ui.widgets.knobPoint(3, 1);
    try std.testing.expect(first.x < middle.x and middle.x < last.x);
    try std.testing.expect(ui.widgets.knobPoint(5, 4).x > middle.x);
    const Preview = ui.runtime.Runtime(.{ .max_nodes = 10, .max_animations = 2 });
    for ([_]u32{ 16, 33, 66, 100 }) |step| {
        var display = Preview{};
        display.update(0);
        for (0..2) |phase| {
            var b = display.beginView();
            try b.begin(1, .stack, 0, 0, .start);
            try ui.widgets.knob(&b, 20, .{ .value = if (phase == 0) 0 else 1, .animation = ui.animation.Animation.easeOut(140) });
            b.end();
            try display.finishView(&b);
        }
        var time: u32 = step;
        while (time < 140) : (time += step) display.update(time);
        display.update(time);
        try std.testing.expectEqual(@as(i16, 17), display.presentationRect(22).?.x);
    }
}

test "tuner markers and focused knob are visible in Mono1" {
    const Preview = ui.runtime.Runtime(10);
    var display = Preview{};
    const markers = [_]ui.widgets.Marker{ .{}, .{ .pending = true }, .{ .unread = true } };
    var b = display.beginView();
    try b.begin(1, .stack, 0, 0, .start);
    const rail_index = b.len;
    try ui.widgets.tuner(&b, 10, .{ .markers = &markers, .selected = 1, .width = 100 });
    b.nodes[rail_index].offset = .{ .x = 10, .y = 10 };
    const knob_index = b.len;
    try ui.widgets.knob(&b, 20, .{ .value = 1, .steps = 2 });
    b.nodes[knob_index].offset = .{ .x = 50, .y = 30 };
    b.end();
    try display.finishView(&b);
    var bytes: [1024]u8 = undefined;
    try ui.headless.render(&display, &bytes, 128, 64);
    var surface = try ui.surface.Mono1.init(&bytes, 128, 64);
    try std.testing.expect(surface.get(57, 8)); // Pending square at slot 1.
    try std.testing.expect(surface.get(87, 7)); // Unread dot at slot 2.
    try std.testing.expect(surface.get(10, 22)); // Tuner focus line.
    display.focused_id = 20;
    try ui.headless.render(&display, &bytes, 128, 64);
    try std.testing.expect(surface.get(70, 41)); // Outer knob focus ring.
}
