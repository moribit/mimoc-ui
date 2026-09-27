const ui = @import("mimoc_ui");

const Display = ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 });
var display: Display = .{};
var framebuffer: [1024]u8 = [_]u8{0} ** 1024;
var status: []const u8 = "READY";

extern fn mimoc_window_run(pixels: [*]const u8) void;
extern fn mimoc_window_redraw() void;
extern fn mimoc_now_ms() u32;

fn paint() void {
    ui.headless.render(&display, &framebuffer, 128, 64) catch unreachable;
    mimoc_window_redraw();
}

fn rebuild() void {
    var b = display.beginView();
    b.begin(0, .stack, 0, 0, .start) catch unreachable;
    b.begin(1, .column, 2, 1, .start) catch unreachable;
    b.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    b.add(.{ .id = 3, .kind = .divider, .min_size = .{ .w = 124, .h = 1 } }) catch unreachable;
    b.add(.{ .id = 10, .kind = .button, .text = "CHAT", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 11, .kind = .button, .text = "CQ", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 12, .kind = .button, .text = "EHAGAKI", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 20, .kind = .text, .text = status }) catch unreachable;
    b.end();
    const indicator_y: i16 = switch (display.focused_id orelse 10) {
        11 => 25,
        12 => 38,
        else => 12,
    };
    b.add(.{ .id = 30, .kind = .filled_rect, .min_size = .{ .w = 2, .h = 10 }, .offset = .{ .x = 0, .y = indicator_y }, .animation = ui.animation.Animation.easeOut(180) }) catch unreachable;
    b.end();
    display.finishView(&b) catch unreachable;
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
    mimoc_window_run(&framebuffer);
}
