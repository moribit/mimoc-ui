const ui = @import("mimoc_ui");
const demo = @import("demo_view.zig");
const showcase = @import("showcase");

const Display = ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 });
var display: Display = .{};
var framebuffer: [1024]u8 = @splat(0);
var status: []const u8 = "READY";
var mode: showcase.Mode = .classic;
var state = showcase.State{};

extern fn mimoc_window_run(pixels: [*]const u8, width: c_int, height: c_int, scale: c_int, title: [*:0]const u8) void;
extern fn mimoc_window_redraw() void;
extern fn mimoc_now_ms() u32;

fn paint() void {
    if (mode == .navigation) {
        const shifted = ui.transition.Shifted(Display){ .runtime = &display, .offset = state.transition.incoming };
        ui.headless.render(&shifted, &framebuffer, 128, 64) catch unreachable;
    } else ui.headless.render(&display, &framebuffer, 128, 64) catch unreachable;
    mimoc_window_redraw();
}

fn rebuild() void {
    if (mode == .classic) demo.build(&display, status) else showcase.build(&display, &state, mode);
    paint();
}

export fn mimoc_tick(now_ms: u32) void {
    const was_active = display.activeAnimationCount() > 0 or state.transition.active;
    display.update(now_ms);
    state.transition.update(now_ms);
    if (was_active or display.activeAnimationCount() > 0 or state.transition.active) paint();
}

export fn mimoc_key(key: c_int) void {
    if (key == 14) {
        mode = switch (mode) {
            .classic => .widgets,
            .widgets => .navigation,
            .navigation => .classic,
            .mobus => .classic,
        };
        state = .{};
        display = .{};
        display.update(mimoc_now_ms());
        rebuild();
        return;
    }
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
        if (mode == .classic) {
            if (a == .activate) {
                status = switch (demo.activated(&display) orelse .root) {
                    .chat => "CHAT OPEN",
                    .cq => "CQ OPEN",
                    .ehagaki => "EHAGAKI OPEN",
                    else => "READY",
                };
            } else _ = display.action(a);
        } else {
            showcase.handle(&display, &state, mode, a, mimoc_now_ms());
        }
        rebuild();
    }
}

export fn mimoc_click(x: c_int, y: c_int) void {
    display.update(mimoc_now_ms());
    for (display.nodes[0..display.len]) |node| {
        if ((node.kind == .button or node.kind == .checkbox or node.kind == .toggle or node.kind == .list_item or node.kind == .tuner or node.kind == .knob) and display.presentationRect(node.id).?.contains(@intCast(x), @intCast(y))) {
            display.focused_id = node.id;
            if (mode == .classic) {
                _ = display.action(.activate);
                status = switch (node.id) {
                    10 => "CHAT OPEN",
                    11 => "CQ OPEN",
                    12 => "EHAGAKI OPEN",
                    else => "READY",
                };
            } else showcase.handle(&display, &state, mode, .activate, mimoc_now_ms());
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
