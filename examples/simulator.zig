const ui = @import("mimoc_ui");

const Display = ui.runtime.Runtime(16);
var display: Display = .{};
var framebuffer: [1024]u8 = [_]u8{0} ** 1024;
var status: []const u8 = "READY";

extern fn mimoc_window_run(pixels: [*]const u8) void;
extern fn mimoc_window_redraw() void;

fn rebuild() void {
    var b = display.beginView();
    b.begin(1, .column, 2, 1, .start) catch unreachable;
    b.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    b.add(.{ .id = 3, .kind = .divider, .min_size = .{ .w = 124, .h = 1 } }) catch unreachable;
    b.add(.{ .id = 10, .kind = .button, .text = "CHAT", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 11, .kind = .button, .text = "CQ", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 12, .kind = .button, .text = "EHAGAKI", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 20, .kind = .text, .text = status }) catch unreachable;
    b.end();
    display.finishView(&b);
    ui.headless.render(&display, &framebuffer, 128, 64) catch unreachable;
    mimoc_window_redraw();
}

export fn mimoc_key(key: c_int) void {
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
    rebuild();
    mimoc_window_run(&framebuffer);
}
