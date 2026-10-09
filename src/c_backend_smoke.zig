//! Verification-only ABI. One fixed-capacity instance, no platform/allocator imports.
const m = @import("root.zig");
const Id = enum(u16) { screen, border, title, line, contacts, hazuki, taro, demo, other, tuner, knob };
const config = .{ .max_nodes = 32, .max_animations = 4, .diagnostics = false };
const Display = m.runtime.Runtime(config);
const Ui = m.ui.Ui(Id, config);
const markers = [_]m.widgets.Marker{ .{ .unread = true }, .{}, .{ .pending = true }, .{}, .{} };
var display = Display{};
var selected: u8 = 0;
var mode: u8 = 0;
var scroll_offset: i16 = 0;
fn rebuild() void {
    var ui = Ui.begin(&display);
    var screen = ui.stack(.screen, .{});
    ui.rect(.border, .{ .w = 128, .h = 64 });
    ui.textWith(.title, "CONTACTS / MO-BUS", .{ .offset = .{ .x = 3, .y = 3 } });
    ui.primitive(.line, .divider, "", .{ .size = .{ .w = 122, .h = 1 }, .offset = .{ .x = 3, .y = 12 } });
    var contacts = ui.listAt(.contacts, .{ .w = 88, .h = 32 }, scroll_offset, .linear(250), .{ .x = 3, .y = 15 });
    ui.listItem(.hazuki, "HAZUKI", 80, true);
    ui.listItem(.taro, "TARO", 80, false);
    ui.listItem(.demo, "DEMO", 80, false);
    ui.listItem(.other, "CQ", 80, false);
    contacts.end();
    ui.tunerAt(.tuner, .{ .width = 118, .markers = &markers, .selected = selected, .animation = .linear(250) }, .{ .x = 4, .y = 49 });
    ui.knobAt(.knob, .{ .steps = 3, .value = mode, .animation = .linear(250) }, .{ .x = 98, .y = 19 });
    screen.end();
    ui.finishChecked() catch @trap();
}
pub export fn mimoc_ui_smoke_init() void {
    display = .{};
    selected = 0;
    mode = 0;
    scroll_offset = 0;
    rebuild();
}
/// Mask bits 0..5 = up/down/left/right/activate/back, applied in that order.
/// Time is an application-supplied monotonically increasing wrapping u32 clock.
pub export fn mimoc_ui_smoke_step(now_ms: u32, input_mask: u32) void {
    display.update(now_ms);
    const tuner = Ui.childId(Ui.rootId(.screen), .tuner);
    const knob = Ui.childId(Ui.rootId(.screen), .knob);
    inline for (.{ m.input.Action.up, .down, .left, .right, .activate, .back }, 0..) |action, bit| {
        if (input_mask & (@as(u32, 1) << bit) != 0) {
            if ((action == .left or action == .right) and display.focused_id == tuner) {
                selected = if (action == .right) (selected + 1) % 5 else (selected + 4) % 5;
            } else if ((action == .left or action == .right) and display.focused_id == knob) {
                mode = if (action == .right) (mode + 1) % 3 else (mode + 2) % 3;
            } else if (action == .activate) {
                selected = (selected + 1) % 5;
                mode = (mode + 1) % 3;
                scroll_offset = if (scroll_offset == 0) 8 else 0;
            } else if (action == .back) {
                selected = 0;
                mode = 0;
                scroll_offset = 0;
            } else _ = display.action(action);
        }
    }
    rebuild();
}
/// Returns 0 on success, 1 for an invalid/null caller-owned buffer; never writes past 1024 bytes.
pub export fn mimoc_ui_smoke_render(framebuffer: ?[*]u8, len: usize) u32 {
    const bytes = framebuffer orelse return 1;
    if (len < 1024) return 1;
    m.headless.render(&display, bytes[0..1024], 128, 64) catch return 1;
    return 0;
}
