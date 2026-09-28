const mimoc = @import("root.zig");

const Id = enum(u16) { home, title, line, chat, cq, ehagaki };
const Display = mimoc.runtime.Runtime(mimoc.profiles.tiny);
const Ui = mimoc.ui.Ui(Id, mimoc.profiles.tiny);

/// Compile for riscv32-freestanding; the platform owns the clock and page IO.
pub export fn mimoc_ui_page(page: [*]u8, page_index: u8, now_ms: u32, action: u8) void {
    var display = Display{};
    display.update(now_ms);
    var view = Ui.begin(&display);
    {
        var screen = view.column(.home, .{ .padding = 2, .spacing = 1 });
        defer screen.end();
        view.text(.title, "MO-BUS");
        view.divider(.line, 120);
        view.button(.chat, "CHAT");
        view.button(.cq, "CQ");
        view.button(.ehagaki, "EHAGAKI");
    }
    view.finish();
    if (action == 1) _ = display.action(.down);
    mimoc.headless.renderPage(&display, page[0..128], 128, page_index) catch unreachable;
}
