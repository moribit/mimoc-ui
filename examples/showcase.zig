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

pub const Mode = enum(u8) { classic, widgets, navigation, mobus };

pub fn build(display: anytype, state: *const State, mode: Mode) void {
    const Display = @TypeOf(display.*);
    const View = ui.ui.Ui(u16, Display.configuration);
    var view = View.begin(display);
    {
        var root = view.stack(1, .{});
        defer root.end();
        switch (mode) {
            .classic, .mobus => {},
            .widgets => {
                var panel = view.panel(2, "COMPONENTS", .{ .w = 126, .h = 62 }, .{});
                defer panel.end();
                view.checkbox(20, "WI-FI", state.wifi);
                view.toggle(30, "BT", state.bluetooth);
                view.progress(40, state.progress, 100);
            },
            .navigation => switch (state.nav.current()) {
                .home => {
                    var column = view.column(2, .{ .padding = 2, .spacing = 1 });
                    defer column.end();
                    view.text(3, "HOME");
                    view.button(10, "CONTACTS");
                    view.button(11, "CQ");
                    view.button(12, "EHAGAKI");
                    view.button(13, "SETTINGS");
                },
                .contacts => {
                    view.textWith(3, "CONTACTS", .{ .offset = .{ .x = 2, .y = 1 } });
                    var list = view.listAt(4, .{ .w = 124, .h = 52 }, state.scroll.offset, ui.animation.Animation.easeOut(120), .{ .x = 2, .y = 11 });
                    defer list.end();
                    inline for ([_][]const u8{ "ALICE", "BOB", "CAROL", "DAVE", "ERIN", "FRANK", "GRACE", "HEIDI" }, 0..) |name, i| {
                        view.listItem(100 + i, name, 120, true);
                    }
                },
                .chat, .cq, .ehagaki, .settings => {
                    var column = view.column(2, .{ .padding = 2, .spacing = 3 });
                    defer column.end();
                    view.text(3, switch (state.nav.current()) {
                        .chat => "CHAT",
                        .cq => "CQ",
                        .ehagaki => "EHAGAKI",
                        .settings => "SETTINGS",
                        else => unreachable,
                    });
                    view.text(4, "PRESS BACK");
                },
            },
        }
    }
    view.finish();
}

pub fn handle(display: anytype, state: *State, mode: Mode, action: ui.input.Action, now: u32) void {
    const Display = @TypeOf(display.*);
    const View = ui.ui.Ui(u16, Display.configuration);
    const root = View.rootId(1);
    if (mode == .classic or mode == .mobus) return;
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
            if (display.ensureFocusVisible(View.childId(root, 4), &state.scroll.offset)) build(display, state, mode);
        }
        return;
    }
    const id = display.action(action) orelse return;
    if (mode == .widgets) {
        const panel = View.childId(root, 2);
        if (id == View.childId(panel, 20)) state.wifi = !state.wifi;
        if (id == View.childId(panel, 30)) state.bluetooth = !state.bluetooth;
        build(display, state, mode);
        return;
    }
    const screen = state.nav.current();
    const column = View.childId(root, 2);
    var next: ?Screen = null;
    if (screen == .home) {
        if (id == View.childId(column, 10)) next = .contacts;
        if (id == View.childId(column, 11)) next = .cq;
        if (id == View.childId(column, 12)) next = .ehagaki;
        if (id == View.childId(column, 13)) next = .settings;
    } else if (screen == .contacts) {
        const list = View.childId(root, 4);
        for (0..8) |i| if (id == View.childId(list, @intCast(100 + i))) {
            next = .chat;
            break;
        };
    }
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
    const View = ui.ui.Ui(u16, Preview.configuration);
    const root = View.rootId(1);
    preview.update(0);
    build(&preview, &state, .navigation);
    try std.testing.expectEqual(@as(?u16, View.childId(View.childId(root, 2), 10)), preview.focused_id);
    handle(&preview, &state, .navigation, .activate, 0);
    try std.testing.expectEqual(Screen.contacts, state.nav.current());
    for (0..6) |_| handle(&preview, &state, .navigation, .down, 0);
    try std.testing.expectEqual(@as(?u16, View.childId(View.childId(root, 4), 106)), preview.focused_id);
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
    try std.testing.expectEqual(@as(?u16, View.childId(View.childId(root, 4), 106)), preview.focused_id);
    try std.testing.expectEqual(old_scroll, state.scroll.offset);
}
