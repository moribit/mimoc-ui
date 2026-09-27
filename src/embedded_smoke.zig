const ui = @import("root.zig");

// Build with: zig build-obj src/embedded_smoke.zig -target riscv32-freestanding -O ReleaseSmall
// The caller passes one 128-byte SSD1306 page. No allocator or libc is required.
pub export fn mimoc_render_page(page: [*]u8, page_index: u8) void {
    var runtime = ui.runtime.Runtime(8){};
    var view = runtime.beginView();
    view.begin(1, .column, 2, 2, .start) catch unreachable;
    view.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    view.add(.{ .id = 3, .kind = .button, .text = "CHAT" }) catch unreachable;
    view.end();
    runtime.finishView(&view);
    ui.headless.renderPage(&runtime, page[0..128], 128, page_index) catch unreachable;
}
