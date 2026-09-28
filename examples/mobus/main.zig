const std = @import("std");
const ui = @import("mimoc_ui");
const screens = @import("screens.zig");

pub const Screen = enum(u8) { home, contacts, chat, composer, ehagaki };
pub const Nav = ui.navigation.Navigation(Screen, 5);

fn mockCanvas() [16 * 58]u8 {
    var pixels = [_]u8{0} ** (16 * 58);
    for (0..58) |row| {
        const x = 12 + row;
        pixels[row * 16 + x / 8] |= @as(u8, 0x80) >> @as(u3, @intCast(x % 8));
    }
    return pixels;
}

pub const State = struct {
    nav: Nav = Nav.init(.home),
    selected_contact: u8 = 0,
    mode: u8 = 0,
    markers: [10]ui.widgets.Marker = .{
        .{}, .{ .unread = true }, .{}, .{ .pending = true }, .{ .empty = true }, .{ .unread = true }, .{}, .{}, .{ .empty = true }, .{},
    },
    chat_scroll: ui.scroll.ScrollState = .{},
    composer_extended: bool = false,
    canvas: [16 * 58]u8 = mockCanvas(),
    cursor_x: i16 = 64,
    cursor_y: i16 = 30,
    tool: u8 = 0,
    overlay: bool = false,
    transition: ui.transition.Transition = .{},
};

pub fn build(display: anytype, state: *const State) void {
    var b = display.beginView();
    b.begin(1, .stack, 0, 0, .start) catch unreachable;
    switch (state.nav.current()) {
        .home => screens.buildHome(&b),
        .contacts => screens.buildContacts(&b, state),
        .chat => screens.buildChat(&b, state),
        .composer => screens.buildComposer(&b, state),
        .ehagaki => screens.buildEhagaki(&b, state),
    }
    b.end();
    display.finishView(&b) catch unreachable;
}

fn push(display: anytype, state: *State, screen: Screen, now: u32) void {
    state.nav.remember(display.focused_id, if (state.nav.current() == .chat) state.chat_scroll.offset else 0);
    state.nav.push(screen) catch return;
    display.focused_id = if (screen == .contacts) 100 else null;
    state.transition.start(.slide_left, now, .{ .w = 128, .h = 64 });
    build(display, state);
}

pub fn handle(display: anytype, state: *State, action: ui.input.Action, now: u32) void {
    const screen = state.nav.current();
    if (action == .back) {
        if (state.nav.pop()) {
            display.focused_id = state.nav.entry().focused_id;
            if (state.nav.current() == .chat) state.chat_scroll.offset = state.nav.entry().scroll_offset;
            state.transition.start(.slide_right, now, .{ .w = 128, .h = 64 });
            build(display, state);
        }
        return;
    }
    switch (screen) {
        .home => {
            if (action == .activate) {
                const id = display.action(.activate) orelse return;
                if (id == 10) push(display, state, .contacts, now) else if (id == 11) push(display, state, .ehagaki, now);
            } else _ = display.action(action);
        },
        .contacts => {
            const focused = display.focused_id orelse 100;
            switch (action) {
                .up, .down => _ = display.action(action),
                .left => {
                    if (focused == 100) {
                        if (state.selected_contact > 0) state.selected_contact -= 1;
                    } else state.mode = 0;
                },
                .right => {
                    if (focused == 100) {
                        if (state.selected_contact < 9) state.selected_contact += 1;
                    } else state.mode = 1;
                },
                .activate => push(display, state, .chat, now),
                .back => unreachable,
            }
            if (state.nav.current() == .contacts) build(display, state);
        },
        .chat => {
            const heights = screens.messageHeights();
            const total = ui.scroll.variableTotalHeight(&heights);
            if (action == .down) state.chat_scroll.offset = @intCast(@min(total - 40, @as(i32, state.chat_scroll.offset) + 8));
            if (action == .up) state.chat_scroll.offset = @max(0, state.chat_scroll.offset - 8);
            if (action == .activate) {
                push(display, state, .composer, now);
                return;
            }
            build(display, state);
        },
        .composer => {
            if (action == .activate or action == .right or action == .left) state.composer_extended = !state.composer_extended;
            build(display, state);
        },
        .ehagaki => {
            switch (action) {
                .left => state.cursor_x = @max(5, state.cursor_x - 2),
                .right => state.cursor_x = @min(121, state.cursor_x + 2),
                .up => state.cursor_y = @max(5, state.cursor_y - 2),
                .down => state.cursor_y = @min(58, state.cursor_y + 2),
                .activate => {
                    state.tool = (state.tool + 1) % 4;
                    state.overlay = !state.overlay;
                },
                .back => unreachable,
            }
            build(display, state);
        },
    }
}

test "Mo-Bus navigation restores contact focus, selection and chat scroll" {
    const Preview = ui.runtime.Runtime(.{ .max_nodes = 64, .max_animations = 8 });
    var display = Preview{};
    var state = State{};
    display.update(0);
    build(&display, &state);
    handle(&display, &state, .activate, 0);
    try std.testing.expectEqual(Screen.contacts, state.nav.current());
    handle(&display, &state, .right, 0);
    handle(&display, &state, .down, 0);
    handle(&display, &state, .right, 0);
    try std.testing.expectEqual(@as(u8, 1), state.selected_contact);
    try std.testing.expectEqual(@as(u8, 1), state.mode);
    handle(&display, &state, .activate, 0);
    try std.testing.expectEqual(Screen.chat, state.nav.current());
    for (0..4) |_| handle(&display, &state, .down, 0);
    display.update(50);
    var chat_full: [1024]u8 = undefined;
    try ui.headless.render(&display, &chat_full, 128, 64);
    for (0..8) |index| {
        var page: [128]u8 = undefined;
        try ui.headless.renderPage(&display, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, chat_full[index * 128 ..][0..128], &page);
    }
    const previous_scroll = state.chat_scroll.offset;
    handle(&display, &state, .activate, 0);
    try std.testing.expectEqual(Screen.composer, state.nav.current());
    handle(&display, &state, .back, 0);
    try std.testing.expectEqual(previous_scroll, state.chat_scroll.offset);
    handle(&display, &state, .back, 0);
    try std.testing.expectEqual(Screen.contacts, state.nav.current());
    try std.testing.expectEqual(@as(?u16, 110), display.focused_id);
    try std.testing.expectEqual(@as(u8, 1), state.selected_contact);
    handle(&display, &state, .back, 0);
    handle(&display, &state, .down, 0);
    handle(&display, &state, .activate, 0);
    try std.testing.expectEqual(Screen.ehagaki, state.nav.current());
    handle(&display, &state, .right, 0);
    handle(&display, &state, .activate, 0);
    try std.testing.expect(state.overlay);
    var canvas_full: [1024]u8 = undefined;
    try ui.headless.render(&display, &canvas_full, 128, 64);
    for (0..8) |index| {
        var page: [128]u8 = undefined;
        try ui.headless.renderPage(&display, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, canvas_full[index * 128 ..][0..128], &page);
    }
    handle(&display, &state, .back, 0);
    try std.testing.expectEqual(Screen.home, state.nav.current());
}
