const ui = @import("mimoc_ui");

pub const Screen = enum(u8) { home, contacts, chat, cq, ehagaki, settings };
pub const State = struct {
    nav: ui.navigation.Navigation(Screen, 8) = ui.navigation.Navigation(Screen, 8).init(.home),
    scroll: ui.scroll.ScrollState = .{},
    wifi: bool = true,
    bluetooth: bool = false,
    progress: u16 = 50,
    transition: ui.transition.Transition = .{},
};

pub const Mode = enum(u8) { classic, widgets, navigation };

pub fn build(display: anytype, state: *const State, mode: Mode) void {
    var b = display.beginView();
    b.begin(1, .stack, 0, 0, .start) catch unreachable;
    switch (mode) {
        .classic => {},
        .widgets => {
            ui.widgets.beginPanel(&b, 2, "COMPONENTS", .{ .w = 126, .h = 62 }, .{}) catch unreachable;
            ui.widgets.checkbox(&b, 20, "WI-FI", state.wifi) catch unreachable;
            ui.widgets.toggle(&b, 30, "BT", state.bluetooth, 86, .{}) catch unreachable;
            ui.widgets.progress(&b, 40, state.progress, 100, 86, .{}) catch unreachable;
            ui.widgets.endPanel(&b);
        },
        .navigation => switch (state.nav.current()) {
            .home => {
                b.begin(2, .column, 2, 1, .start) catch unreachable;
                ui.widgets.text(&b, 3, "HOME") catch unreachable;
                ui.widgets.button(&b, 10, "CONTACTS") catch unreachable;
                ui.widgets.button(&b, 11, "CQ") catch unreachable;
                ui.widgets.button(&b, 12, "EHAGAKI") catch unreachable;
                ui.widgets.button(&b, 13, "SETTINGS") catch unreachable;
                b.end();
            },
            .contacts => {
                ui.widgets.text(&b, 3, "CONTACTS") catch unreachable;
                b.nodes[b.len - 1].offset = .{ .x = 2, .y = 1 };
                ui.widgets.beginList(&b, 4, 5, .{ .w = 124, .h = 52 }, state.scroll.offset, ui.animation.Animation.easeOut(120)) catch unreachable;
                b.nodes[2].offset = .{ .x = 2, .y = 11 };
                inline for ([_][]const u8{ "ALICE", "BOB", "CAROL", "DAVE", "ERIN", "FRANK", "GRACE", "HEIDI" }, 0..) |name, i| {
                    ui.widgets.listItem(&b, 100 + i, name, 120, true) catch unreachable;
                }
                ui.widgets.endList(&b);
            },
            .chat, .cq, .ehagaki, .settings => {
                b.begin(2, .column, 2, 3, .start) catch unreachable;
                ui.widgets.text(&b, 3, switch (state.nav.current()) {
                    .chat => "CHAT",
                    .cq => "CQ",
                    .ehagaki => "EHAGAKI",
                    .settings => "SETTINGS",
                    else => unreachable,
                }) catch unreachable;
                ui.widgets.text(&b, 4, "PRESS BACK") catch unreachable;
                b.end();
            },
        },
    }
    b.end();
    display.finishView(&b) catch unreachable;
}

pub fn handle(display: anytype, state: *State, mode: Mode, action: ui.input.Action, now: u32) void {
    if (mode == .classic) return;
    if (action == .back and mode == .navigation) {
        state.nav.remember(display.focused_id, state.scroll.offset);
        if (state.nav.pop()) {
            state.scroll.offset = state.nav.entry().scroll_offset;
            display.focused_id = state.nav.entry().focused_id;
            state.transition.start(.slide_right, now, .{ .w = 128, .h = 64 });
            build(display, state, mode);
        }
        return;
    }
    if (action == .up or action == .down or action == .left or action == .right) {
        _ = display.action(action);
        if (mode == .navigation and state.nav.current() == .contacts) {
            if (display.ensureFocusVisible(4, &state.scroll.offset)) build(display, state, mode);
        }
        return;
    }
    const id = display.action(action) orelse return;
    if (mode == .widgets) {
        switch (id) {
            20 => state.wifi = !state.wifi,
            30 => state.bluetooth = !state.bluetooth,
            else => {},
        }
        build(display, state, mode);
        return;
    }
    const screen = state.nav.current();
    const next: ?Screen = switch (screen) {
        .home => switch (id) {
            10 => .contacts,
            11 => .cq,
            12 => .ehagaki,
            13 => .settings,
            else => null,
        },
        .contacts => if (id >= 100 and id < 108) .chat else null,
        else => null,
    };
    if (next) |target| {
        state.nav.remember(display.focused_id, state.scroll.offset);
        state.nav.push(target) catch return;
        state.scroll.offset = 0;
        display.focused_id = null;
        state.transition.start(.slide_left, now, .{ .w = 128, .h = 64 });
        build(display, state, mode);
    }
}

test "Home Contacts Chat Back restores focus and scroll" {
    const std = @import("std");
    const Preview = ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 });
    var preview = Preview{};
    var state = State{};
    preview.update(0);
    build(&preview, &state, .navigation);
    try std.testing.expectEqual(@as(?u16, 10), preview.focused_id);
    handle(&preview, &state, .navigation, .activate, 0);
    try std.testing.expectEqual(Screen.contacts, state.nav.current());
    for (0..6) |_| handle(&preview, &state, .navigation, .down, 0);
    try std.testing.expectEqual(@as(?u16, 106), preview.focused_id);
    try std.testing.expect(state.scroll.offset > 0);
    const old_scroll = state.scroll.offset;
    handle(&preview, &state, .navigation, .activate, 0);
    try std.testing.expectEqual(Screen.chat, state.nav.current());
    state.transition.update(90);
    const shifted = ui.transition.Shifted(Preview){ .runtime = &preview, .offset = state.transition.incoming };
    var full: [1024]u8 = undefined;
    try ui.headless.render(&shifted, &full, 128, 64);
    for (0..8) |page| {
        var bytes: [128]u8 = undefined;
        try ui.headless.renderPage(&shifted, &bytes, 128, @intCast(page));
        try std.testing.expectEqualSlices(u8, full[page * 128 ..][0..128], &bytes);
    }
    handle(&preview, &state, .navigation, .back, 100);
    try std.testing.expectEqual(Screen.contacts, state.nav.current());
    try std.testing.expectEqual(@as(?u16, 106), preview.focused_id);
    try std.testing.expectEqual(old_scroll, state.scroll.offset);
}
