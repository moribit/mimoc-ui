const std = @import("std");
const ui = @import("root.zig");

fn render128(runtime: anytype) ![1024]u8 {
    var bytes: [1024]u8 = undefined;
    try ui.headless.render(runtime, &bytes, 128, 64);
    for (0..8) |page_index| {
        var page: [128]u8 = undefined;
        try ui.headless.renderPage(runtime, &page, 128, @intCast(page_index));
        try std.testing.expectEqualSlices(u8, bytes[page_index * 128 ..][0..128], &page);
    }
    return bytes;
}
fn pixel(bytes: *const [1024]u8, x: usize, y: usize) bool {
    return bytes[(y / 8) * 128 + x] & (@as(u8, 1) << @as(u3, @intCast(y % 8))) != 0;
}

test "checkbox four states and activation id" {
    for ([_]bool{ false, true }) |checked| {
        var b = ui.view.Builder(4).init();
        try b.begin(1, .stack, 0, 0, .start);
        try ui.widgets.checkbox(&b, 10, "WIFI", checked);
        b.end();
        var runtime = ui.runtime.Runtime(4){};
        try runtime.setView(&b);
        try std.testing.expectEqual(@as(?u16, 10), runtime.action(.activate));
        runtime.focused_id = null;
        const plain = try render128(&runtime);
        try std.testing.expectEqual(checked, pixel(&plain, 2, 3));
        try std.testing.expect(!pixel(&plain, 0, 0));
        runtime.focused_id = 10;
        const focused = try render128(&runtime);
        try std.testing.expect(pixel(&focused, 0, 0));
        try std.testing.expectEqual(checked, pixel(&focused, 4, 3));
    }
}

test "toggle knob uses presentation track" {
    const Runtime = ui.runtime.Runtime(.{ .max_nodes = 4, .max_animations = 1 });
    var runtime = Runtime{};
    runtime.update(0);
    var off = ui.view.Builder(4).init();
    try ui.widgets.toggle(&off, 20, "WIFI", false, 60, .{ .animation = ui.animation.Animation.linear(100) });
    try runtime.setView(&off);
    try std.testing.expectEqual(@as(i16, 38), runtime.presentationRect(22).?.x);
    var on = ui.view.Builder(4).init();
    try ui.widgets.toggle(&on, 20, "WIFI", true, 60, .{ .animation = ui.animation.Animation.linear(100) });
    try runtime.setView(&on);
    runtime.update(50);
    try std.testing.expectEqual(@as(i16, 45), runtime.presentationRect(22).?.x);
    _ = try render128(&runtime);
    runtime.update(100);
    try std.testing.expectEqual(@as(i16, 52), runtime.presentationRect(22).?.x);
}

test "progress exact endpoints and midpoint" {
    for ([_]u16{ 0, 50, 100 }, [_]i16{ 0, 9, 18 }) |value, fill| {
        var b = ui.view.Builder(4).init();
        try ui.widgets.progress(&b, 30, value, 100, 20, .{ .animation = .{} });
        var runtime = ui.runtime.Runtime(4){};
        try runtime.setView(&b);
        try std.testing.expectEqual(fill, runtime.presentationRect(32).?.w);
        const bytes = try render128(&runtime);
        try std.testing.expectEqual(fill > 0, pixel(&bytes, 1, 3));
        try std.testing.expect(pixel(&bytes, 0, 0));
    }
}

test "progress width animates with frozen page snapshot" {
    const Runtime = ui.runtime.Runtime(.{ .max_nodes = 4, .max_animations = 1 });
    var runtime = Runtime{};
    runtime.update(0);
    var first = ui.view.Builder(4).init();
    try ui.widgets.progress(&first, 30, 30, 100, 22, .{ .animation = ui.animation.Animation.linear(100) });
    try runtime.setView(&first);
    var second = ui.view.Builder(4).init();
    try ui.widgets.progress(&second, 30, 80, 100, 22, .{ .animation = ui.animation.Animation.linear(100) });
    try runtime.setView(&second);
    runtime.update(50);
    try std.testing.expectEqual(@as(i16, 11), runtime.presentationRect(32).?.w);
    _ = try render128(&runtime);
    runtime.update(100);
    try std.testing.expectEqual(@as(i16, 16), runtime.presentationRect(32).?.w);
}

test "custom icons clip at viewport edge and support three sizes" {
    inline for (.{ 8, 12, 16 }) |size| {
        const count = ((size + 7) / 8) * size;
        const bitmap = [_]u8{0xff} ** count;
        var b = ui.view.Builder(2).init();
        try b.begin(1, .stack, 0, 0, .start);
        try ui.widgets.icon(&b, 2, .{ .width = size, .height = size, .data = &bitmap });
        b.nodes[1].offset = .{ .x = 124, .y = 60 };
        b.end();
        var runtime = ui.runtime.Runtime(2){};
        try runtime.setView(&b);
        const bytes = try render128(&runtime);
        try std.testing.expect(pixel(&bytes, 127, 63));
        try std.testing.expect(!pixel(&bytes, 123, 63));
    }
}

test "panel title and no-title are composed from primitives" {
    for ([_]?[]const u8{ "TITLE", null }, [_]u16{ 6, 4 }) |heading, expected_nodes| {
        var b = ui.view.Builder(8).init();
        try ui.widgets.beginPanel(&b, 100, heading, .{ .w = 48, .h = 28 }, .{});
        try ui.widgets.text(&b, 110, "BODY");
        ui.widgets.endPanel(&b);
        var runtime = ui.runtime.Runtime(8){};
        try runtime.setView(&b);
        try std.testing.expectEqual(expected_nodes, runtime.nodeCount());
        const bytes = try render128(&runtime);
        try std.testing.expect(pixel(&bytes, 0, 0));
        try std.testing.expectEqual(heading != null, pixel(&bytes, 2, 11));
    }
}

test "nested clip and animated scroll preserve page rendering" {
    const Runtime = ui.runtime.Runtime(.{ .max_nodes = 8, .max_animations = 1 });
    var runtime = Runtime{};
    runtime.update(0);
    var b = ui.view.Builder(8).init();
    try b.begin(1, .stack, 0, 0, .start);
    try ui.widgets.beginClip(&b, 2, .{ .w = 16, .h = 12 });
    try ui.widgets.beginList(&b, 3, 4, .{ .w = 16, .h = 10 }, 0, ui.animation.Animation.linear(100));
    try ui.widgets.listItem(&b, 10, "ONE", 16, false);
    try ui.widgets.listItem(&b, 11, "TWO", 16, false);
    try ui.widgets.listItem(&b, 12, "THREE", 16, false);
    ui.widgets.endList(&b);
    b.end();
    b.end();
    try runtime.setView(&b);
    const top = try render128(&runtime);
    try std.testing.expect(pixel(&top, 0, 0));
    try std.testing.expect(!pixel(&top, 0, 12));
    var moved = b;
    moved.nodes[3].offset.y = -10;
    try runtime.setView(&moved);
    runtime.update(50);
    try std.testing.expectEqual(@as(i16, -5), runtime.presentationRect(4).?.y);
    _ = try render128(&runtime);
    runtime.update(100);
    try std.testing.expectEqual(@as(i16, 0), runtime.presentationRect(11).?.y);
    const scrolled = try render128(&runtime);
    try std.testing.expect(!pixel(&scrolled, 0, 10));
}

test "list focus auto scroll and visible range" {
    var b = ui.view.Builder(8).init();
    try b.begin(1, .stack, 0, 0, .start);
    try ui.widgets.beginList(&b, 2, 3, .{ .w = 32, .h = 20 }, 0, .{});
    try ui.widgets.listItem(&b, 10, "ALICE", 32, true);
    try ui.widgets.listItem(&b, 11, "BOB", 32, false);
    try ui.widgets.listItem(&b, 12, "CAROL", 32, false);
    ui.widgets.endList(&b);
    b.end();
    var runtime = ui.runtime.Runtime(8){};
    try runtime.setView(&b);
    var offset: i16 = 0;
    try std.testing.expectEqual(@as(?u16, 10), runtime.focused_id);
    try std.testing.expect(!runtime.ensureFocusVisible(2, &offset));
    _ = runtime.action(.down);
    try std.testing.expectEqual(@as(?u16, 11), runtime.focused_id);
    try std.testing.expect(!runtime.ensureFocusVisible(2, &offset));
    _ = runtime.action(.down);
    try std.testing.expect(runtime.ensureFocusVisible(2, &offset));
    try std.testing.expectEqual(@as(i16, 10), offset);
    b.nodes[2].offset.y = -offset;
    try runtime.setView(&b);
    const bytes = try render128(&runtime);
    try std.testing.expect(pixel(&bytes, 0, 10));
    try std.testing.expect(!pixel(&bytes, 0, 20));
    try std.testing.expectEqual(ui.scroll.Range{ .first = 1, .end = 4 }, ui.scroll.visibleRange(100, 10, 10, 20));
}

test "full two-view slide transition matches page rendering" {
    const Runtime = ui.runtime.Runtime(3);
    var old_builder = ui.view.Builder(3).init();
    try old_builder.begin(1, .stack, 0, 0, .start);
    try old_builder.add(.{ .id = 2, .kind = .rect, .min_size = .{ .w = 12, .h = 12 } });
    old_builder.end();
    var new_builder = ui.view.Builder(3).init();
    try new_builder.begin(1, .stack, 0, 0, .start);
    try new_builder.add(.{ .id = 3, .kind = .filled_rect, .min_size = .{ .w = 12, .h = 12 } });
    new_builder.end();
    var old = Runtime{};
    var new = Runtime{};
    try old.setView(&old_builder);
    try new.setView(&new_builder);
    var transition = ui.transition.Transition{ .capability = .full, .animation = ui.animation.Animation.linear(100) };
    transition.start(.slide_left, 0, .{ .w = 128, .h = 64 });
    transition.update(50);
    const pair = ui.transition.Pair(Runtime, Runtime){ .old = &old, .new = &new, .transition = &transition };
    var full: [1024]u8 = undefined;
    try ui.headless.render(&pair, &full, 128, 64);
    for (0..8) |page| {
        var bytes: [128]u8 = undefined;
        try ui.headless.renderPage(&pair, &bytes, 128, @intCast(page));
        try std.testing.expectEqualSlices(u8, full[page * 128 ..][0..128], &bytes);
    }
    try std.testing.expect(pixel(&full, 64, 0));
    transition.update(200);
    var settled: [1024]u8 = undefined;
    var expected: [1024]u8 = undefined;
    try ui.headless.render(&pair, &settled, 128, 64);
    try ui.headless.render(&new, &expected, 128, 64);
    try std.testing.expectEqualSlices(u8, &expected, &settled);
}
