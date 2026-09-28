const ui = @import("root.zig");

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
    } else {
        ui.widgets.beginList(&builder, 3, 4, .{ .w = 128, .h = 32 }, scroll.offset, .{}) catch unreachable;
        ui.widgets.listItem(&builder, 10, "ALICE", 100, true) catch unreachable;
        ui.widgets.listItem(&builder, 11, "BOB", 100, false) catch unreachable;
        ui.widgets.endList(&builder);
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
