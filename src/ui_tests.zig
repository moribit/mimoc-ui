const std = @import("std");
const api = @import("root.zig");

const Id = enum(u16) { home, title, line, chat, cq, wifi, progress, panel, label, knob };
const Config = .{ .max_nodes = 16, .max_animations = 4, .diagnostics = true };
const Runtime = api.runtime.Runtime(Config);
const Ui = api.ui.Ui(Id, Config);

test "typed high-level screen, scoped IDs and page rendering" {
    var display = Runtime{};
    var ui = Ui.begin(&display);
    {
        var home = ui.column(.home, .{ .padding = 2, .spacing = 1 });
        defer home.end();
        ui.text(.title, "MO-BUS");
        ui.divider(.line, 100);
        ui.button(.chat, "CHAT");
        ui.button(.cq, "CQ");
    }
    try ui.finishChecked();
    try std.testing.expectEqual(@as(?u16, Ui.childId(Ui.rootId(.home), .chat)), display.focused_id);
    var full: [1024]u8 = undefined;
    try api.headless.render(&display, &full, 128, 64);
    for (0..8) |index| {
        var page: [128]u8 = undefined;
        try api.headless.renderPage(&display, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, full[index * 128 ..][0..128], &page);
    }
}

test "nested and sibling scopes have stable distinct identities" {
    var display = Runtime{};
    var ui = Ui.begin(&display);
    var root = ui.column(.home, .{});
    const home_key = root.key;
    var left = ui.scope(.panel);
    const left_key = ui.id(.title);
    ui.text(.title, "LEFT");
    left.end();
    var right = ui.scope(.chat);
    const right_key = ui.id(.title);
    ui.text(.title, "RIGHT");
    right.end();
    root.end();
    try ui.finishChecked();
    try std.testing.expect(left_key != right_key);
    try std.testing.expectEqual(Ui.childId(Ui.childId(home_key, .panel), .title), left_key);
    try std.testing.expectEqual(@as(u16, 3), display.nodeCount());
    var next = Ui.begin(&display);
    var again = next.column(.home, .{});
    var left_again = next.scope(.panel);
    next.text(.title, "CHANGED");
    left_again.end();
    again.end();
    try next.finishChecked();
    try std.testing.expect(display.presentationRect(left_key) != null);
}

test "scope guards detect double end and unclosed containers" {
    var display = Runtime{};
    var ui = Ui.begin(&display);
    var empty = ui.column(.home, .{});
    empty.end();
    empty.end();
    try std.testing.expectError(error.DoubleEnd, ui.finishChecked());
    try std.testing.expectEqual(api.ui.Failure.double_end, ui.diagnostic().?.failure);
    var another = Ui.begin(&display);
    _ = another.column(.home, .{});
    try std.testing.expectError(error.UnclosedScope, another.finishChecked());
}

test "capacity reports used, maximum, widget and screen" {
    const SmallConfig = .{ .max_nodes = 2, .max_animations = 0, .diagnostics = true };
    const SmallRuntime = api.runtime.Runtime(SmallConfig);
    const SmallUi = api.ui.Ui(u16, SmallConfig);
    var display = SmallRuntime{};
    var exact = SmallUi.begin(&display);
    exact.screen("Tiny");
    var root = exact.column(1, .{});
    exact.text(2, "OK");
    root.end();
    try exact.finishChecked();
    try std.testing.expectEqual(@as(u16, 2), display.nodeUsage().used);
    var overflow = SmallUi.begin(&display);
    overflow.screen("Tiny");
    var content = overflow.column(1, .{});
    overflow.text(2, "OK");
    overflow.button(3, "EXTRA");
    content.end();
    try std.testing.expectError(error.NodeCapacityExceeded, overflow.finishChecked());
    const info = overflow.diagnostic().?;
    try std.testing.expectEqualStrings("Button", info.widget);
    try std.testing.expectEqualStrings("Tiny", info.screen);
    try std.testing.expectEqual(@as(u16, 2), info.used);
    try std.testing.expectEqual(@as(u16, 2), info.capacity);
}

test "raw ID collision is detected before finalization" {
    const Tiny = api.runtime.Runtime(3);
    const Raw = api.ui.Ui(u16, 3);
    const target = Raw.rootId(42);
    const parent = Raw.rootId(1);
    const local = std.math.rotr(u16, target ^ std.math.rotl(u16, parent, 5) ^ 0xa5c3, 1);
    try std.testing.expectEqual(target, Raw.childId(parent, local));
    var display = Tiny{};
    var ui = Raw.begin(&display);
    ui.text(42, "A");
    var scope = ui.scope(1);
    ui.text(local, "B");
    scope.end();
    try std.testing.expectError(error.IdentityCollision, ui.finishChecked());
}

test "static to animated, retarget, and animated to static reuse presentation" {
    var display = Runtime{};
    display.update(0);
    {
        var ui = Ui.begin(&display);
        var root = ui.stack(.home, .{});
        ui.filledRect(.chat, .{ .w = 4, .h = 4 }, .{ .x = 0 }, .{});
        root.end();
        try ui.finishChecked();
    }
    {
        var ui = Ui.begin(&display);
        var root = ui.stack(.home, .{});
        ui.filledRect(.chat, .{ .w = 4, .h = 4 }, .{ .x = 100 }, api.animation.Animation.linear(100));
        root.end();
        try ui.finishChecked();
    }
    const key = Ui.childId(Ui.rootId(.home), .chat);
    try std.testing.expectEqual(@as(i16, 0), display.presentationRect(key).?.x);
    display.update(50);
    try std.testing.expectEqual(@as(i16, 50), display.presentationRect(key).?.x);
    var full: [1024]u8 = undefined;
    try api.headless.render(&display, &full, 128, 64);
    for (0..8) |page_index| {
        var page: [128]u8 = undefined;
        try api.headless.renderPage(&display, &page, 128, @intCast(page_index));
        try std.testing.expectEqualSlices(u8, full[page_index * 128 ..][0..128], &page);
    }
    {
        var ui = Ui.begin(&display);
        var root = ui.stack(.home, .{});
        ui.filledRect(.chat, .{ .w = 4, .h = 4 }, .{ .x = 150 }, api.animation.Animation.linear(100));
        root.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(i16, 50), display.presentationRect(key).?.x);
    display.update(100);
    try std.testing.expectEqual(@as(i16, 100), display.presentationRect(key).?.x);
    {
        var ui = Ui.begin(&display);
        var root = ui.stack(.home, .{});
        ui.filledRect(.chat, .{ .w = 4, .h = 4 }, .{ .x = 160 }, .{});
        root.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(i16, 160), display.presentationRect(key).?.x);
    try std.testing.expectEqual(@as(u16, 0), display.animationUsage().used);
}

test "animation capacity overflow is surfaced" {
    const Cfg = .{ .max_nodes = 4, .max_animations = 1, .diagnostics = true };
    const SmallRuntime = api.runtime.Runtime(Cfg);
    const SmallUi = api.ui.Ui(Id, Cfg);
    var display = SmallRuntime{};
    display.update(0);
    {
        var ui = SmallUi.begin(&display);
        var root = ui.stack(.home, .{});
        ui.filledRect(.chat, .{ .w = 2, .h = 2 }, .{}, .{});
        ui.filledRect(.cq, .{ .w = 2, .h = 2 }, .{}, .{});
        root.end();
        try ui.finishChecked();
    }
    var ui = SmallUi.begin(&display);
    var root = ui.stack(.home, .{});
    ui.filledRect(.chat, .{ .w = 2, .h = 2 }, .{ .x = 10 }, api.animation.Animation.linear(100));
    ui.filledRect(.cq, .{ .w = 2, .h = 2 }, .{ .x = 20 }, api.animation.Animation.linear(100));
    root.end();
    try std.testing.expectError(error.AnimationCapacityExceeded, ui.finishChecked());
    try std.testing.expectEqual(api.ui.Failure.animation_capacity, ui.diagnostic().?.failure);
}

test "focus survives rebuild and falls back when the focused widget disappears" {
    var display = Runtime{};
    {
        var ui = Ui.begin(&display);
        var root = ui.column(.home, .{});
        ui.button(.chat, "CHAT");
        ui.button(.cq, "CQ");
        root.end();
        try ui.finishChecked();
    }
    const chat = Ui.childId(Ui.rootId(.home), .chat);
    const cq = Ui.childId(Ui.rootId(.home), .cq);
    try std.testing.expectEqual(@as(?u16, chat), display.focused_id);
    _ = display.action(.down);
    try std.testing.expectEqual(@as(?u16, cq), display.focused_id);
    {
        var ui = Ui.begin(&display);
        var root = ui.column(.home, .{});
        ui.button(.chat, "CHAT UPDATED");
        ui.button(.cq, "CQ UPDATED");
        ui.button(.wifi, "WIFI NEW");
        root.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(?u16, cq), display.focused_id);
    {
        var ui = Ui.begin(&display);
        var root = ui.column(.home, .{});
        ui.button(.chat, "CHAT");
        ui.button(.wifi, "WIFI");
        root.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(?u16, chat), display.focused_id);
}

test "composite logical identity is stable across internal structure changes" {
    const Cfg = .{ .max_nodes = 8, .max_animations = 1, .diagnostics = true };
    const Display = api.runtime.Runtime(Cfg);
    const View = api.ui.Ui(Id, Cfg);
    var display = Display{};
    {
        var ui = View.begin(&display);
        var root = ui.column(.home, .{});
        ui.toggle(.wifi, "WIFI", false);
        root.end();
        try ui.finishChecked();
    }
    const key = View.childId(View.rootId(.home), .wifi);
    display.focused_id = key;
    {
        var ui = View.begin(&display);
        var root = ui.column(.home, .{});
        ui.primitive(.line, .divider, "", .{ .size = .{ .w = 80, .h = 1 } });
        ui.toggle(.wifi, "WIFI", true);
        root.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(?u16, key), display.focused_id);
    try std.testing.expect(display.presentationRect(key) != null);
}

test "component adds an internal border without shifting public focus ID" {
    var display = Runtime{};
    const key = Ui.childId(Ui.rootId(.home), .chat);
    {
        var ui = Ui.begin(&display);
        var component = ui.scope(.home);
        ui.button(.chat, "OPEN");
        component.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(?u16, key), display.focused_id);
    {
        var ui = Ui.begin(&display);
        var component = ui.scope(.home);
        ui.rect(.line, .{ .w = 20, .h = 12 });
        ui.button(.chat, "OPEN");
        component.end();
        try ui.finishChecked();
    }
    try std.testing.expectEqual(@as(?u16, key), display.focused_id);
}

test "maximum raw ID and nested scope guard errors" {
    const Display = api.runtime.Runtime(2);
    const View = api.ui.Ui(u16, 2);
    var display = Display{};
    var ui = View.begin(&display);
    var outer = ui.scope(65535);
    var inner = ui.column(1, .{});
    ui.text(2, "MAX");
    inner.end();
    outer.end();
    try ui.finishChecked();
    try std.testing.expectEqual(@as(u16, 2), display.nodeCount());
    var bad = View.begin(&display);
    var a = bad.scope(65535);
    var b = bad.scope(1);
    a.end();
    b.end();
    try std.testing.expectError(error.InvalidHierarchy, bad.finishChecked());
}

test "high-level list rejects invalid scroll range" {
    var display = Runtime{};
    var ui = Ui.begin(&display);
    var list = ui.list(.panel, .{ .w = 64, .h = 32 }, -1, .{});
    list.end();
    try std.testing.expectError(error.InvalidScrollRange, ui.finishChecked());
    try std.testing.expectEqual(api.ui.Failure.invalid_scroll_range, ui.diagnostic().?.failure);
}
