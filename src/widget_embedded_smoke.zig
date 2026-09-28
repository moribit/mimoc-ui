const ui = @import("root.zig");
const pixels = [_]u8{ 0x80, 0x00, 0x01, 0x00 };
const markers = [_]ui.widgets.Marker{ .{}, .{ .pending = true }, .{ .unread = true } };

/// Compile-only RV32 path covering widgets, scroll, navigation and transition.
pub export fn mimoc_widget_page(page: [*]u8, page_index: u8, now_ms: u32, down: bool) void {
    const Runtime = ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 2 });
    const Screen = enum(u8) { home, contacts };
    var nav = ui.navigation.Navigation(Screen, 2).init(.home);
    if (down) nav.push(.contacts) catch unreachable;
    var scroll = ui.scroll.ScrollState{};
    var runtime = Runtime{};
    runtime.update(now_ms);
    var builder = runtime.beginView();
    builder.begin(1, .stack, 0, 0, .start) catch unreachable;
    ui.widgets.beginClip(&builder, 2, .{ .w = 128, .h = 64 }) catch unreachable;
    if (nav.current() == .home) {
        ui.widgets.checkbox(&builder, 10, "WIFI", true) catch unreachable;
        ui.widgets.wrappedText(&builder, 20, "HELLO WORLD", 30) catch unreachable;
        ui.widgets.bitmap(&builder, 21, .{ .width = 9, .height = 2, .stride = 2, .data = &pixels }) catch unreachable;
        ui.widgets.scrollbar(&builder, 30, 32, 100, 20, 3) catch unreachable;
    } else {
        ui.widgets.beginList(&builder, 3, 4, .{ .w = 128, .h = 32 }, scroll.offset, .{}) catch unreachable;
        ui.widgets.listItem(&builder, 10, "ALICE", 100, true) catch unreachable;
        ui.widgets.listItem(&builder, 11, "BOB", 100, false) catch unreachable;
        ui.widgets.endList(&builder);
        const visible = ui.scroll.variableVisibleRange(&[_]u16{ 8, 16, 12 }, scroll.offset, 24);
        ui.widgets.tuner(&builder, 30, .{ .markers = &markers, .selected = @intCast(visible.first), .animation = .linear(100) }) catch unreachable;
        ui.widgets.knob(&builder, 40, .{ .value = 1, .animation = .linear(100) }) catch unreachable;
    }
    builder.end();
    builder.end();
    runtime.finishView(&builder) catch unreachable;
    if (down) {
        _ = runtime.action(.down);
        _ = runtime.ensureFocusVisible(3, &scroll.offset);
    }
    var transition = ui.transition.Transition{ .capability = .single_view };
    transition.start(if (down) .slide_left else .none, now_ms, .{ .w = 128, .h = 64 });
    transition.update(now_ms +% 200);
    const shifted = ui.transition.Shifted(Runtime){ .runtime = &runtime, .offset = transition.incoming };
    ui.headless.renderPage(&shifted, page[0..128], 128, page_index) catch unreachable;
}
