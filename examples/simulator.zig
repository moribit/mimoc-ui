const ui = @import("mimoc_ui");
const demo = @import("demo_view.zig");

const Display = ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 });
var display: Display = .{};
var framebuffer: [1024]u8 = [_]u8{0} ** 1024;
var status: []const u8 = "READY";

extern fn mimoc_window_run(pixels: [*]const u8, width: c_int, height: c_int, scale: c_int, title: [*:0]const u8) void;
extern fn mimoc_window_redraw() void;
extern fn mimoc_now_ms() u32;

fn paint() void {
    ui.headless.render(&display, &framebuffer, 128, 64) catch unreachable;
    mimoc_window_redraw();
}

fn rebuild() void {
    demo.build(&display, status);
    paint();
}

export fn mimoc_tick(now_ms: u32) void {
    const was_active = display.activeAnimationCount() > 0;
    display.update(now_ms);
    if (was_active or display.activeAnimationCount() > 0) paint();
}

export fn mimoc_key(key: c_int) void {
    display.update(mimoc_now_ms());
    const action: ?ui.input.Action = switch (key) {
        0 => .up,
        1 => .down,
        2 => .left,
        3 => .right,
        4 => .activate,
        5 => .back,
        else => null,
    };
    if (action) |a| {
        if (display.action(a)) |id| {
            status = switch (id) {
                10 => "CHAT OPEN",
                11 => "CQ OPEN",
                12 => "EHAGAKI OPEN",
                else => "READY",
            };
        }
        rebuild();
    }
}

export fn mimoc_click(x: c_int, y: c_int) void {
    display.update(mimoc_now_ms());
    for (display.nodes[0..display.len]) |node| {
        if (node.kind == .button and node.frame.contains(@intCast(x), @intCast(y))) {
            display.focused_id = node.id;
            _ = display.action(.activate);
            status = switch (node.id) {
                10 => "CHAT OPEN",
                11 => "CQ OPEN",
                12 => "EHAGAKI OPEN",
                else => "READY",
            };
            rebuild();
            return;
        }
    }
}

pub fn main() void {
    display.update(mimoc_now_ms());
    rebuild();
    mimoc_window_run(&framebuffer, 128, 64, 8, "Mimoc UI - Virtual SSD1306");
}
