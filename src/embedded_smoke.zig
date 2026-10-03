const ui = @import("root.zig");

// Build with: zig build-obj src/embedded_smoke.zig -target riscv32-freestanding -O small
// The caller passes one 128-byte SSD1306 page. No allocator or libc is required.
pub export fn mimoc_render_page(page: [*]u8, page_index: u8) void {
    var runtime = ui.runtime.Runtime(.{ .max_nodes = 8, .max_animations = 2 }){};
    runtime.update(0);
    var view = runtime.beginView();
    view.begin(1, .column, 2, 2, .start) catch unreachable;
    view.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    view.add(.{ .id = 3, .kind = .button, .text = "CHAT", .animation = ui.animation.Animation.easeOut(100) }) catch unreachable;
    view.end();
    runtime.finishView(&view) catch unreachable;
    var next = runtime.beginView();
    next.begin(1, .column, 2, 2, .start) catch unreachable;
    next.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    next.add(.{ .id = 3, .kind = .button, .text = "CHAT", .offset = .{ .x = 10 }, .animation = ui.animation.Animation.easeOut(100) }) catch unreachable;
    next.end();
    runtime.finishView(&next) catch unreachable;
    runtime.update(50);
    ui.headless.renderPage(&runtime, page[0..128], 128, page_index) catch unreachable;
}
