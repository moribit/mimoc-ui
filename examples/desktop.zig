const m = @import("mimoc_ui");
const pf = @import("desktop_font");
const window = @import("desktop_window");
const std = @import("std");
const Display = m.runtime.Runtime(m.profiles.desktop);
const Ui = m.ui.Ui(u16, m.profiles.desktop);
var display = Display{};
var pixels: [1024 * 96]u8 = undefined;
var buffer: [256]u8 = undefined;
var length: usize = 0;
var cursor: usize = 0;
var field = m.text_edit.Field{ .placeholder = "Message..." };
var sent: [256]u8 = undefined;
var sent_len: usize = 0;
var offset: i16 = 0;
var key_down = false;
var selected_contact: usize = 0;
var field_id: u16 = 0;
var send_id: u16 = 0;
var cq_id: u16 = 0;
var scroll_id: u16 = 0;
fn rebuild() void {
    field.text = buffer[0..length];
    field.cursor = cursor;
    const w = display.viewport.w;
    const h = display.viewport.h;
    var ui = Ui.begin(&display);
    var root = ui.stack(1, .{});
    ui.textWith(2, "MO-BUS DESKTOP", .{ .offset = .{ .x = 8, .y = 8 } });
    ui.textWith(3, "* ONLINE", .{ .offset = .{ .x = @max(8, w - 80), .y = 8 } });
    ui.divider(4, w);
    var contacts = ui.column(5, .{ .offset = .{ .x = 8, .y = 36 }, .spacing = 8 });
    ui.text(6, "CONTACTS");
    ui.button(7, "Hazuki");
    ui.button(8, "Taro");
    ui.button(9, "Demo");
    contacts.end();
    var chat = ui.scrollView(10, .{ .size = .{ .w = @max(16, w - 150), .h = @max(16, h - 104) }, .offset = .{ .x = 140, .y = 36 } });
    var messages = ui.column(11, .{ .offset = .{ .y = -offset }, .spacing = 12 });
    ui.text(12, ([_][]const u8{ "HAZUKI", "TARO", "DEMO" })[selected_contact]);
    ui.text(13, "Hello");
    ui.text(14, "こんにちは");
    ui.wrappedText(15, "沖縄県東村 CQやりませんか？ Hello 沖縄 CQ", @max(16, w - 160));
    ui.wrappedText(16, sent[0..sent_len], @max(16, w - 160));
    ui.text(17, "Scroll / trackpad demo");
    ui.text(18, "Hello world");
    ui.text(19, "こんにちは");
    messages.end();
    chat.end();
    scroll_id = Ui.childId(Ui.rootId(1), 10);
    field_id = Ui.childId(Ui.rootId(1), 20);
    send_id = Ui.childId(Ui.rootId(1), 21);
    cq_id = Ui.childId(Ui.rootId(1), 22);
    ui.textField(20, &field, .{ .size = .{ .w = @max(24, w - 215), .h = 22 }, .offset = .{ .x = 140, .y = h - 58 } });
    ui.buttonWith(21, "SEND", .{ .disabled = length == 0, .offset = .{ .x = @max(140, w - 65), .y = h - 55 } });
    ui.pressable(22, "CQ KEY", .{ .offset = .{ .x = 8, .y = h - 28 } });
    ui.textWith(23, if (key_down) "KEY DOWN" else "KEY UP", .{ .offset = .{ .x = 90, .y = h - 26 } });
    root.end();
    ui.finish();
    m.headless.render(&display, &pixels, w, h) catch unreachable;
    window.present(&pixels, .{ .w = w, .h = h });
}
fn send() void {
    @memcpy(sent[0..length], buffer[0..length]);
    sent_len = length;
    length = 0;
    cursor = 0;
}
fn receive(event: m.input.InputEvent) void {
    const was_editing = display.capturedFocus() != null;
    const result = display.dispatch(event);
    if (result.target == field_id and (was_editing or result.interaction == .focus)) {
        if (result.interaction != .focus) if (m.text_edit.intent(event)) |edit| {
            if (edit == .submit) send() else m.text_edit.apply(&buffer, &length, &cursor, edit) catch {};
        };
    }
    if (result.activated) for (7..10) |id| {
        const contact_id = Ui.childId(Ui.childId(Ui.rootId(1), 5), @intCast(id));
        if (result.target == contact_id) selected_contact = id - 7;
    };
    if (result.target == send_id and result.interaction == .activate) send();
    if (result.target == cq_id) switch (event) {
        .pointer_down => key_down = true,
        .pointer_up => key_down = false,
        else => {},
    };
    switch (event) {
        .key_down => |key| {
            if (key == .space and !was_editing) key_down = true;
        },
        .key_up => |key| {
            if (key == .space) key_down = false;
        },
        .scroll => |delta| {
            if (result.target == scroll_id) offset = @intCast(@max(0, @min(160, @as(i32, offset) + delta.y)));
        },
        else => {},
    }
    rebuild();
}
fn platformEvent(event: window.Event) void {
    switch (event) {
        .input => |input| receive(input),
        .tick => |now| display.update(now),
        .resize => |size| resize(size.w, size.h),
        .focus_lost => {
            key_down = false;
            display.cancelInput();
            rebuild();
        },
    }
}
fn resize(w: c_int, h: c_int) callconv(.c) void {
    display.viewport = .{ .w = @intCast(std.math.clamp(w, 128, 1024)), .h = @intCast(std.math.clamp(h, 64, 768)) };
    rebuild();
}
extern fn getenv([*:0]const u8) ?[*:0]const u8;
extern fn fopen([*:0]const u8, [*:0]const u8) ?*anyopaque;
extern fn fwrite([*]const u8, usize, usize, *anyopaque) usize;
extern fn fclose(*anyopaque) c_int;
pub fn main() void {
    display.viewport = .{ .w = 480, .h = 270 };
    display.setFontProvider(pf.provider);
    rebuild();
    if (getenv("MIMOC_DESKTOP_SNAPSHOT")) |path| {
        const file = fopen(path, "wb") orelse return;
        const header = "P4\n480 270\n";
        _ = fwrite(header.ptr, 1, header.len, file);
        const surface = m.surface.Mono1.init(&pixels, 480, 270) catch unreachable;
        var row: [60]u8 = undefined;
        for (0..270) |y| {
            @memset(&row, 0);
            for (0..480) |x| if (surface.get(@intCast(x), @intCast(y))) {
                row[x / 8] |= @as(u8, 128) >> @as(u3, @intCast(x % 8));
            };
            _ = fwrite(&row, 1, row.len, file);
        }
        _ = fclose(file);
        return;
    }
    window.run(&pixels, .{ .w = 480, .h = 270 }, 2, "Mo-Bus Desktop Foundation", platformEvent);
}

test "native Unicode provider yields distinct one-bit Japanese glyphs" {
    var a: [128]u8 = undefined;
    var b: [128]u8 = undefined;
    pf.provider.raster_fn(null, '沖', &a);
    pf.provider.raster_fn(null, '縄', &b);
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
    var nonzero = false;
    for (a) |byte| {
        if (byte != 0) nonzero = true;
    }
    try std.testing.expect(nonzero);
    try std.testing.expect(pf.provider.measureText("沖縄") > 0);
}
test "Desktop mock handles native input resize scroll and CQ lifecycle" {
    display = .{};
    length = 0;
    cursor = 0;
    key_down = false;
    resize(480, 270);
    display.setFontProvider(pf.provider);
    rebuild();
    try std.testing.expect(display.captureFocus(field_id));
    receive(.{ .text = "こんにちは" });
    try std.testing.expectEqualStrings("こんにちは", buffer[0..length]);
    receive(.{ .key_down = .enter });
    try std.testing.expectEqualStrings("こんにちは", sent[0..sent_len]);
    receive(.{ .key_down = .space });
    try std.testing.expect(key_down);
    receive(.{ .key_up = .space });
    try std.testing.expect(!key_down);
    const r = display.presentationRect(cq_id).?;
    receive(.{ .pointer_down = .{ .x = r.x, .y = r.y } });
    try std.testing.expect(key_down);
    receive(.{ .pointer_up = .{ .x = r.x, .y = r.y } });
    try std.testing.expect(!key_down);
    resize(320, 180);
    try std.testing.expectEqual(@as(i16, 320), display.viewport.w);
    resize(128, 64);
    resize(480, 270);
}
