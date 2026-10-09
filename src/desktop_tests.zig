const std = @import("std");
const m = @import("root.zig");
const expect = std.testing.expect;
const eq = std.testing.expectEqual;
const Display = m.runtime.Runtime(m.profiles.desktop);
const Ui = m.ui.Ui(u16, m.profiles.desktop);
fn advance(_: ?*anyopaque, cp: u21) u8 {
    return if (cp < 128) 6 else 14;
}
fn raster(_: ?*anyopaque, _: u21, mask: *[128]u8) void {
    @memset(mask, 0);
    mask[0] = 128;
}
const provider = m.font.Provider{ .advance_fn = advance, .raster_fn = raster, .line_height = 16 };
test "UTF-8 application-owned editing preserves every boundary" {
    for ([_][]const u8{ "abc", "沖縄", "hello沖縄", "CQやりませんか？" }) |text| {
        var buffer: [128]u8 = undefined;
        var len: usize = 0;
        var cursor: usize = 0;
        try m.text_edit.apply(&buffer, &len, &cursor, .{ .insert = text });
        try eq(text.len, cursor);
        try m.text_edit.apply(&buffer, &len, &cursor, .home);
        try eq(@as(usize, 0), cursor);
        var count: usize = 0;
        while (cursor < len) {
            try m.text_edit.apply(&buffer, &len, &cursor, .right);
            try eq(cursor, m.text_edit.boundary(buffer[0..len], cursor));
            count += 1;
        }
        for (0..count) |_| {
            try m.text_edit.apply(&buffer, &len, &cursor, .left);
            try eq(cursor, m.text_edit.boundary(buffer[0..len], cursor));
        }
        try eq(@as(usize, 0), cursor);
        try m.text_edit.apply(&buffer, &len, &cursor, .delete);
        try std.testing.expectEqualStrings(text[m.font.codepointBytes(text, 0)..], buffer[0..len]);
        try m.text_edit.apply(&buffer, &len, &cursor, .end);
        const before = m.text_edit.previous(buffer[0..len], len);
        try m.text_edit.apply(&buffer, &len, &cursor, .backspace);
        try eq(before, len);
        try eq(len, cursor);
        try m.text_edit.apply(&buffer, &len, &cursor, .{ .insert = "沖縄" });
        try expect(std.unicode.utf8ValidateSlice(buffer[0..len]));
    }
}
test "text edits are atomic on invalid input and exhausted capacity" {
    var buffer: [4]u8 = undefined;
    var len: usize = 0;
    var cursor: usize = 0;
    try m.text_edit.apply(&buffer, &len, &cursor, .{ .insert = "abc" });
    try std.testing.expectError(error.CapacityExceeded, m.text_edit.apply(&buffer, &len, &cursor, .{ .insert = "沖" }));
    try std.testing.expectError(error.InvalidUtf8, m.text_edit.apply(&buffer, &len, &cursor, .{ .insert = "\xff" }));
    try eq(@as(usize, 3), len);
    try std.testing.expectEqualStrings("abc", buffer[0..len]);
}
test "InputEvent capture focus submit cancel disabled pointer and scroll" {
    var d = Display{};
    var field = m.text_edit.Field{ .text = "沖縄", .cursor = 6 };
    var ui = Ui.begin(&d);
    var root = ui.column(1, .{});
    const fid = root.id(2);
    const bid = root.id(3);
    const pid = root.id(4);
    const sid = root.id(5);
    ui.textField(2, &field, .{});
    ui.button(3, "SEND");
    ui.pressable(4, "CQ", .{});
    var scroll = ui.scrollView(5, .{ .size = .{ .w = 100, .h = 20 } });
    ui.text(6, "hello");
    scroll.end();
    root.end();
    ui.finish();
    try eq(@as(?u16, fid), d.action(.activate));
    try eq(m.input.Interaction.focus, d.dispatch(.{ .action = .activate }).interaction);
    try eq(@as(?u16, fid), d.capturedFocus());
    const text = d.dispatch(.{ .text = "こんにちは" });
    try eq(@as(?u16, fid), text.target);
    try std.testing.expectEqualStrings("こんにちは", text.event.text);
    _ = d.dispatch(.{ .key_down = .left });
    try eq(@as(?u16, fid), d.focused_id);
    try eq(@as(?u16, fid), d.dispatch(.{ .key_up = .space }).target);
    try eq(m.input.Interaction.blur, d.dispatch(.{ .key_down = .enter }).interaction);
    try eq(@as(?u16, null), d.capturedFocus());
    _ = d.dispatch(.{ .key_down = .down });
    try eq(@as(?u16, bid), d.focused_id);
    try expect(d.captureFocus(fid));
    _ = d.dispatch(.{ .key_down = .escape });
    try eq(@as(?u16, null), d.capturedFocus());
    const rect = d.presentationRect(pid).?;
    const point = m.geometry.Point{ .x = rect.x, .y = rect.y };
    try eq(m.input.Interaction.pressed, d.dispatch(.{ .pointer_down = point }).interaction);
    const released = d.dispatch(.{ .pointer_up = point });
    try eq(m.input.Interaction.released, released.interaction);
    try expect(released.activated);
    _ = d.dispatch(.{ .pointer_down = point });
    try expect(!d.dispatch(.{ .pointer_up = .{ .x = 300, .y = 300 } }).activated);
    _ = d.dispatch(.{ .pointer_down = point });
    d.cancelInput();
    try expect(!d.dispatch(.{ .pointer_up = point }).activated);
    d.focused_id = pid;
    try eq(m.input.Interaction.input, d.dispatch(.{ .key_up = .unknown }).interaction);
    try eq(m.input.Interaction.pressed, d.dispatch(.{ .key_down = .space }).interaction);
    const key_release = d.dispatch(.{ .key_up = .space });
    try eq(m.input.Interaction.released, key_release.interaction);
    try expect(key_release.activated);
    d.focused_id = bid;
    const br = d.presentationRect(bid).?;
    const bp = m.geometry.Point{ .x = br.x, .y = br.y };
    _ = d.dispatch(.{ .pointer_down = bp });
    try expect(d.dispatch(.{ .pointer_up = bp }).activated);
    const sr = d.presentationRect(sid).?;
    const wheel = d.dispatch(.{ .scroll = .{ .point = .{ .x = sr.x, .y = sr.y }, .y = 8 } });
    try eq(@as(?u16, sid), wheel.target);
    try eq(@as(i16, 8), wheel.event.scroll.y);
    field.disabled = true;
    ui = Ui.begin(&d);
    root = ui.column(1, .{});
    ui.textField(2, &field, .{});
    ui.buttonWith(3, "SEND", .{ .disabled = true });
    root.end();
    ui.finish();
    try eq(@as(?u16, null), d.focused_id);
    try expect(!d.captureFocus(fid));
}
test "password mask independent of underlying UTF-8 text and cursor" {
    var d = Display{};
    var f = m.text_edit.Field{ .text = "沖縄", .password = true, .cursor = 6 };
    var ui = Ui.begin(&d);
    var root = ui.column(1, .{});
    ui.textField(2, &f, .{});
    root.end();
    ui.finish();
    try expect(d.captureFocus(Ui.childId(Ui.rootId(1), 2)));
    var a: [1024]u8 = undefined;
    var b: [1024]u8 = undefined;
    try m.headless.render(&d, &a, 128, 64);
    f.text = "ab";
    f.cursor = 2;
    try m.headless.render(&d, &b, 128, 64);
    try std.testing.expectEqualSlices(u8, &a, &b);
}
test "provider measurement wrapping mixed UTF-8 and logical viewports" {
    try eq(@as(i16, 18), m.font.measure(.tiny5x7, "abc"));
    try eq(@as(i16, 28), provider.measureText("沖縄"));
    try eq(@as(i16, 40), provider.measureText("Hi沖縄"));
    for ([_][]const u8{ "Hello world", "こんにちは", "沖縄県東村", "CQやりませんか？", "Hello 沖縄 CQ" }) |text| {
        var it = m.wrap.ProviderIterator{ .text = text, .font = .tiny5x7, .max_width = 30, .provider = provider };
        var count: usize = 0;
        while (it.next()) |line| {
            try expect(std.unicode.utf8ValidateSlice(line.bytes));
            try eq(line.width, provider.measureText(line.bytes));
            try expect(line.width <= 30);
            count += 1;
        }
        try expect(count > 0);
    }
    var pixels: [640 * 45]u8 = undefined;
    for ([_]m.geometry.Size{ .{ .w = 128, .h = 64 }, .{ .w = 320, .h = 180 }, .{ .w = 480, .h = 270 }, .{ .w = 640, .h = 360 } }) |size| {
        var d = Display{};
        d.viewport = .{ .w = size.w, .h = size.h };
        d.setFontProvider(provider);
        var ui = Ui.begin(&d);
        var root = ui.column(1, .{});
        ui.wrappedText(2, "Hello 沖縄 CQ", size.w);
        root.end();
        ui.finish();
        try m.headless.render(&d, &pixels, size.w, size.h);
        try eq(@as(i16, 16), d.nodes[1].frame.h);
    }
}
