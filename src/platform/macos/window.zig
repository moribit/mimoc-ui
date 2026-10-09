//! Single-window Desktop bridge. Core never imports this module.
const m = @import("mimoc_ui");
const std = @import("std");
pub const Event = union(enum) { input: m.input.InputEvent, resize: m.geometry.Size, focus_lost, tick: u32 };
pub const Callback = *const fn (Event) void;
var callback: Callback = undefined;
extern fn mimoc_desktop_run([*]const u8, c_int, c_int, c_int, [*:0]const u8, *const fn (c_int, c_int, c_int, c_int, c_int, ?[*]const u8, usize) callconv(.c) void, *const fn (c_int, c_int) callconv(.c) void) void;
extern fn mimoc_window_present([*]const u8, c_int, c_int) void;
extern fn mimoc_window_viewport(*c_int, *c_int) void;
pub fn present(buffer: []const u8, size: m.geometry.Size) void {
    mimoc_window_present(buffer.ptr, size.w, size.h);
}
pub fn viewport() m.geometry.Size {
    var w: c_int = 0;
    var h: c_int = 0;
    mimoc_window_viewport(&w, &h);
    return .{ .w = coord(w), .h = coord(h) };
}
pub fn run(buffer: []const u8, size: m.geometry.Size, scale: u8, title: [*:0]const u8, handler: Callback) void {
    callback = handler;
    mimoc_desktop_run(buffer.ptr, size.w, size.h, @max(1, scale), title, nativeEvent, nativeResize);
}
fn coord(value: c_int) i16 {
    return @intCast(std.math.clamp(value, -32768, 32767));
}
fn nativeResize(w: c_int, h: c_int) callconv(.c) void {
    callback(.{ .resize = .{ .w = coord(w), .h = coord(h) } });
}
fn nativeEvent(kind: c_int, key: c_int, x: c_int, y: c_int, extra: c_int, text: ?[*]const u8, len: usize) callconv(.c) void {
    const point = m.geometry.Point{ .x = coord(x), .y = coord(y) };
    const k: m.input.Key = if (key >= 0 and key <= 12) @fromBackingInt(@intCast(@as(u8, @intCast(key)))) else .unknown;
    const event: m.input.InputEvent = switch (kind) {
        // CQ Space and submit do not repeat; navigation and deletion may repeat.
        0 => {
            if (extra != 0 and (k == .space or k == .enter)) return;
            return callback(.{ .input = .{ .key_down = k } });
        },
        1 => .{ .key_up = k },
        2 => .{ .text = if (text) |ptr| ptr[0..len] else "" },
        3 => .{ .pointer_down = point },
        4 => .{ .pointer_up = point },
        5 => .{ .pointer_move = point },
        6 => .{ .scroll = .{ .point = point, .x = coord(key), .y = coord(extra) } },
        7 => return callback(.focus_lost),
        else => return,
    };
    callback(.{ .input = event });
}

// Legacy symbols are required by the shared bridge, but Desktop uses typed callbacks.
export fn mimoc_key(_: c_int) void {}
export fn mimoc_click(_: c_int, _: c_int) void {}
export fn mimoc_tick(now: u32) void {
    callback(.{ .tick = now });
}
