//! Frozen reference geometry. Do not apply design-system conventions here.
const std = @import("std");
const ui = @import("mimoc_ui");
const raster = ui.raster_compat;
const fonts = @import("fonts.zig");
pub const catalog = @import("catalog.zig");
pub const fixtures = @import("fixtures.zig");
pub const Scenario = catalog.Scenario;
const R = ui.mono1.Renderer;

fn text(r: *R, kind: fonts.Kind, x: i16, y: i16, str: []const u8, center: bool, printing: bool, fg: bool, bg: bool) void {
    shadedText(r, kind, x, y, str, center, printing, fg, bg, 255);
}
fn shadedText(r: *R, kind: fonts.Kind, x: i16, y: i16, str: []const u8, center: bool, printing: bool, fg: bool, bg: bool, gray: u8) void {
    var f = fonts.Font{ .kind = kind, .printing = printing, .background_gray = gray };
    f.draw(r, if (center) x - @divTrunc(f.measure(str), 2) else x, y, str, fg, bg);
}
fn menu(r: *R, s: Scenario, f: fixtures.Fixture) void {
    text(r, .custom7, 48, 9, "Mode", false, false, true, false);
    r.rect(.{ .x = 5, .y = 5, .w = 118, .h = 54 }, true);
    r.hline(5, 20, 118, true);
    r.rect(.{ .x = 41, .y = 20, .w = 40, .h = 23 }, true);
    r.hline(5, 42, 118, true);
    if (s.variant == 3) {
        r.line(10, 47, 22, 55, true);
        r.line(22, 47, 10, 55, true);
    } else {
        for (0..f.radio_level) |i| {
            const n: i16 = @intCast(i);
            r.fillRect(.{ .x = 10 + 3 * n, .y = 52 - 2 * n, .w = 2, .h = 4 + 2 * n }, true);
        }
    }
    var buf: [8]u8 = undefined;
    const percent = std.fmt.bufPrint(&buf, "{d}%", .{f.battery_percent}) catch unreachable;
    const font = fonts.Font{ .kind = .custom7 };
    text(r, .custom7, 46 - font.measure(percent), 49, percent, false, false, true, false);
    text(r, .custom7, 73, 49, f.time, false, false, true, false);
    const positions = [_]i16{ 15, 53, 93 };
    const labels = [_][]const u8{ "TUN", "SET", "TRA" };
    text(r, .custom7, positions[if (s.variant == 1) @as(usize, 1) else 0] - 6, 29, "[   ]", false, false, true, false);
    for (positions, labels) |x, label| text(r, .custom7, x, 29, label, false, false, true, false);
    if (s.variant == 2) raster.fillCircle(r, 37, 25, 4, false);
}
fn contacts(r: *R, s: Scenario, f: fixtures.Fixture) void {
    if (s.variant == 5) {
        text(r, .font2, 38, 26, "Loading", false, false, true, false);
        return;
    }
    r.rect(.{ .x = 30, .y = 2, .w = 68, .h = 18 }, true);
    text(r, .font2, 64, 3, if (s.variant == 1) "Pending" else f.contact, true, false, true, false);
    if (s.variant == 2) raster.fillCircle(r, 119, 8, 3, true);
    text(r, .font2, 32, 22, "QSP", false, false, true, false);
    text(r, .font2, 76, 22, "CQ", false, false, true, false);
    raster.circle(r, 64, 37, 7, true);
    if (s.variant == 4) raster.circle(r, 64, 37, 9, true);
    r.line(64, 37, if (s.variant == 3) 69 else 59, 32, true);
    r.hline(10, 54, 109, true);
    r.vline(10, 50, 9, true);
    r.vline(118, 50, 9, true);
    const bayer = [_]u8{ 8, 136, 40, 168, 200, 72, 232, 104, 56, 184, 24, 152, 248, 120, 216, 88 };
    for (0..10) |i| {
        const x: i16 = 10 + @as(i16, @intCast((108 * (i + 1)) / 11));
        // RGB565 0xC618 -> RGB332 Sprite -> RGB565 -> OLED gamma/Bayer.
        // Rotation 2 determines the physical dither phase. RGB565 0xDEDF
        // expands to (222,219,255); the original integer gamma formula gives 198.
        for (50..59) |yy| {
            const y: i16 = @intCast(yy);
            r.pixel(x, y, 256 <= @as(u16, 198) + bayer[@as(usize, @intCast((127 - x) & 3)) | (@as(usize, @intCast((63 - y) & 3)) << 2)]);
        }
        if (i == 0 and s.variant != 4) { // Original fillTriangle apex(19,60), base at y64.
            raster.fillTriangle(r, x, 60, x - 4, 64, x + 4, 64, true);
        }
        if (i == 0 and s.variant == 1) r.rect(.{ .x = x - 2, .y = 52, .w = 5, .h = 5 }, true);
        if (i == 0 and s.variant == 2) raster.fillCircle(r, x + 4, 48, 1, true);
    }
}
const Row = struct { text: [320]u8 = @splat(0), len: usize = 0, mine: bool = false };
fn chat(r: *R, s: Scenario, f: fixtures.Fixture) void {
    const kind: fonts.Kind = if (s.variant == 3) .misaki8 else .font2;
    var font = fonts.Font{ .kind = kind };
    text(r, kind, 64, 0, f.room, true, false, true, false);
    r.hline(0, 12, 128, true);
    const line_height: i16 = if (s.variant == 3) 12 else 18;
    const max_rows: usize = if (s.variant == 3) 3 else 2;
    const msgs: []const fixtures.Message = if (s.variant == 3) &fixtures.japanese else if (s.variant == 1) &fixtures.long_chat else &fixtures.chat;
    var rows: [3]Row = @splat(.{});
    var count: usize = 0;
    var mi = msgs.len;
    while (mi > 0 and count < max_rows) {
        mi -= 1;
        var joined: [320]u8 = undefined;
        const msg = msgs[mi];
        const str = std.fmt.bufPrint(&joined, "{s}: {s}", .{ msg.sender, msg.text }) catch unreachable;
        // Original renderer uses only the first `remain` wrapped lines. Retain
        // at most three; later lines cannot affect this 128x64 fixed fixture.
        var wrapped: [3]Row = @splat(.{});
        var wc: usize = 0;
        var start: usize = 0;
        var pos: usize = 0;
        while (pos < str.len) {
            const next = pos + ui.font.codepointBytes(str, pos);
            if (pos > start and font.measure(str[start..next]) > 128) {
                if (wc < wrapped.len) {
                    @memcpy(wrapped[wc].text[0 .. pos - start], str[start..pos]);
                    wrapped[wc].len = pos - start;
                }
                wc += 1;
                start = pos;
            }
            pos = next;
        }
        if (wc < wrapped.len) {
            @memcpy(wrapped[wc].text[0 .. pos - start], str[start..pos]);
            wrapped[wc].len = pos - start;
        }
        wc += 1;
        var w = @min(max_rows - count, wc);
        while (w > 0) {
            w -= 1;
            var i = count;
            while (i > 0) : (i -= 1) rows[i] = rows[i - 1];
            rows[0] = wrapped[w];
            rows[0].mine = msg.mine or (s.variant == 2 and mi == 1);
            count += 1;
        }
    }
    for (rows[0..count], 0..) |row, i| {
        const y: i16 = 16 + @as(i16, @intCast(i)) * line_height;
        if (row.mine) r.fillRect(.{ .x = 0, .y = y - 2, .w = 128, .h = line_height }, true);
        shadedText(r, kind, 0, y, row.text[0..row.len], false, true, !row.mine, row.mine, 179);
    }
    text(r, kind, 0, 56, if (s.variant == 3) "ENTER:ソウシン　BACK:モドル" else "Enter:Send  Back:Leave", false, true, true, false);
}
fn settings(r: *R, s: Scenario) void {
    const labels = [_][]const u8{ "Profile", "Wi-Fi", "Sound", "Vibration", "Language", "Firmware" };
    const selected: usize = if (s.variant == 0) 0 else if (s.variant == 1) 2 else 5;
    const first: usize = if (selected >= 4) selected - 3 else 0;
    for (first..@min(first + 4, labels.len)) |i| {
        const y: i16 = @intCast((i - first) * 16);
        const active = i == selected;
        if (active) r.fillRect(.{ .x = 0, .y = y, .w = 128, .h = 16 }, true);
        text(r, .custom7, 2, y + 6, labels[i], false, false, !active, active);
        switch (i) {
            1 => raster.fillCircle(r, 116, y + 8, 3, !active),
            2 => {
                raster.fillCircle(r, 116, y + 8, 4, active);
                raster.circle(r, 116, y + 8, 3, !active);
            },
            3 => {
                for ([_]i16{ 111, 116, 121 }) |x| raster.fillCircle(r, x, y + 8, 1, !active);
            },
            4 => {
                const font = fonts.Font{ .kind = .custom7 };
                text(r, .custom7, 126 - font.measure("EN"), y + 6, "EN", false, false, !active, active);
            },
            else => {},
        }
    }
}
fn dialog(r: *R, s: Scenario) void {
    const factory = s.variant >= 2;
    const button_y: i16 = if (factory) 44 else 34;
    text(r, .font2, 64, if (factory) 0 else 10, if (factory) "Factory Reset?" else "Confirm?", true, false, true, false);
    if (factory) text(r, .font2, 64, 14, "Erase settings?", true, false, true, false);
    for ([_]i16{ 12, 76 }, [_][]const u8{ "No", "Yes" }, 0..) |x, label, i| {
        const active = i == s.variant % 2;
        raster.roundRect(r, x, button_y, 40, 18, 3, active, true);
        raster.roundRect(r, x, button_y, 40, 18, 3, true, false);
        text(r, .font2, x + 20, button_y + 2, label, true, false, !active, active);
    }
}
fn profile(r: *R, s: Scenario) void {
    const labels = [_][]const u8{ "Name:", "ID:", "Version:" };
    const values = [_][]const u8{ "Hazuki", "ABCD2345", "1.0" };
    for (labels, values, 0..) |label, value, i| {
        const y: i16 = @as(i16, @intCast(i)) * 28 - if (s.variant == 1) @as(i16, 28) else 0;
        if (y + 28 >= 0 and y < 64) {
            text(r, .font2, 0, y, label, false, true, true, false);
            text(r, .font2, 0, y + 14, value, false, true, true, false);
        }
    }
}
fn tra(r: *R, s: Scenario) void {
    const labels = [_][]const u8{ "TYPING", "Local", "Eha", "Synth", "Mopp", "Maji" };
    const labels2 = [_][]const u8{ "", "CQ", "gaki", "", "ing", "mun" };
    for (labels, labels2, 0..) |label, second, i| {
        const x: i16 = 2 + @as(i16, @intCast(i % 3)) * 42;
        const y: i16 = 5 + @as(i16, @intCast(i / 3)) * 29;
        const active = i == if (s.variant == 1) @as(usize, 3) else 0;
        r.fillRect(.{ .x = x, .y = y, .w = 39, .h = 25 }, active);
        r.rect(.{ .x = x, .y = y, .w = 39, .h = 25 }, true);
        if (second.len > 0) {
            text(r, .custom7, x + 19, y + 3, label, true, false, !active, active);
            text(r, .custom7, x + 19, y + 13, second, true, false, !active, active);
        } else text(r, .custom7, x + 19, y + 8, label, true, false, !active, active);
    }
}
fn ehagaki(r: *R, s: Scenario) void {
    text(r, .font2, 64, 0, "Ehagaki", true, false, true, false);
    for ([_][]const u8{ "POST", "MY POST", "TIMELINE" }, 0..) |label, i| {
        const y: i16 = 16 + @as(i16, @intCast(i)) * 16;
        const active = i == if (s.variant == 1) @as(usize, 2) else 0;
        if (active) raster.roundRect(r, 9, y - 1, 110, 15, 2, true, true);
        text(r, .custom7, 64, y, label, true, false, !active, active);
    }
}
fn rooms(r: *R, s: Scenario) void {
    text(r, .font2, 64, 0, "ROOMS", true, false, true, false);
    r.hline(0, 12, 128, true);
    for ([_][]const u8{ "LOBBY", "OKINAWA", "CQ" }, 0..) |label, i| {
        const y: i16 = 16 + @as(i16, @intCast(i)) * 12;
        const active = i == s.variant;
        if (active) r.fillRect(.{ .x = 0, .y = y - 2, .w = 128, .h = 12 }, true);
        text(r, .font2, 4, y, label, false, true, !active, active);
    }
    text(r, .font2, 0, 56, "Enter:Join Back:Exit", false, true, true, false);
}
fn composer(r: *R, s: Scenario) void {
    text(r, .font2, 2, 0, if (s.variant == 1) "BPM:120 PLAY" else "BPM:120 EDIT", false, false, true, false);
    r.hline(0, 12, 128, true);
    for (0..16) |i| {
        const x: i16 = 4 + @as(i16, @intCast(i)) * 7;
        const active = i % 3 == 1;
        if (s.variant == 1 and i == 4) r.fillRect(.{ .x = x, .y = 15, .w = 5, .h = 3 }, true);
        if (active) r.fillRect(.{ .x = x, .y = 20, .w = 5, .h = 16 }, true) else r.rect(.{ .x = x, .y = 20, .w = 5, .h = 16 }, true);
        text(r, .font2, x + 2, 22, if (i % 3 != 0) "A" else "-", true, false, !active, active);
        if (i == 2) r.rect(.{ .x = x - 1, .y = 18, .w = 7, .h = 20 }, true);
    }
    text(r, .font2, 64, 40, "S:03 PIANO N:60", true, false, true, false);
    text(r, .font2, 64, 52, "TYPE:Inst ENT:Play", true, false, true, false);
}
fn textScreen(r: *R, s: Scenario) void {
    switch (s.variant) {
        0 => text(r, .font2, 64, 26, "Mo-Bus", true, false, true, false),
        1 => {
            text(r, .font2, 64, 18, "Mo-Bus", true, false, true, false);
            text(r, .font2, 64, 34, "Ready", true, false, true, false);
        },
        2, 3 => {
            r.bitmap(52, 6, 24, 29, &@import("icons.zig").offline);
            text(r, .font2, 64, 43, if (s.variant == 2) "OFFLINE" else "Error", true, false, true, false);
        },
        else => {},
    }
}
fn wifi(r: *R, s: Scenario) void {
    if (s.variant < 3) {
        text(r, .font2, 64, 18, "Wi-Fi", true, false, true, false);
        text(r, .font2, 64, 34, switch (s.variant) {
            0 => "Scanning...",
            1 => "Connecting...",
            else => "Failed / retry",
        }, true, false, true, false);
        return;
    }
    if (s.variant < 6) {
        const rows = [_][]const u8{ "Wi-Fi", "Mobus-Home", "Demo", "Cafe", "Other" };
        const selected: usize = switch (s.variant) {
            3 => 0,
            4 => 2,
            else => 4,
        };
        const first: usize = if (selected >= 4) selected - 3 else 0;
        for (first..@min(first + 4, rows.len)) |i| {
            const y: i16 = @intCast((i - first) * 16);
            const active = i == selected;
            if (active) r.fillRect(.{ .x = 0, .y = y, .w = 128, .h = 16 }, true);
            text(r, .font2, 10, y, rows[i], false, true, !active, active);
        }
        return;
    }
    text(r, .font2, 0, 0, "Password", false, true, true, false);
    r.hline(0, 14, 128, true);
    r.hline(0, 45, 128, true);
    text(r, .font2, 0, 15, "******", false, true, true, false);
    const row = "abcdefghijklm";
    for (row, 0..) |_, i| {
        text(r, .font2, @as(i16, @intCast(i)) * 8, 46, row[i .. i + 1], false, true, !(s.variant == 6 and i == 1), s.variant == 6 and i == 1);
    }
    const active = s.variant == 7;
    r.fillRect(.{ .x = 118, .y = 45, .w = 10, .h = 16 }, active);
    raster.fillTriangle(r, 114, 52, 118, 45, 118, 60, active);
    raster.line(r, 118, 45, 127, 45, !active);
    raster.line(r, 127, 45, 127, 60, !active);
    raster.line(r, 127, 60, 118, 60, !active);
    raster.line(r, 118, 45, 114, 52, !active);
    raster.line(r, 114, 52, 118, 60, !active);
    raster.line(r, 120, 50, 124, 54, !active);
    raster.line(r, 124, 50, 120, 54, !active);
}
pub fn render(s: Scenario, f: fixtures.Fixture, pixels: *[1024]u8) void {
    pixels.* = @splat(0);
    var surface = ui.surface.Mono1.init(pixels, 128, 64) catch unreachable;
    var r = R.init(&surface);
    switch (s.screen) {
        .menu => menu(&r, s, f),
        .contacts => contacts(&r, s, f),
        .chat => chat(&r, s, f),
        .settings => settings(&r, s),
        .dialog => dialog(&r, s),
        .profile => profile(&r, s),
        .tra => tra(&r, s),
        .ehagaki => ehagaki(&r, s),
        .rooms => rooms(&r, s),
        .composer => composer(&r, s),
        .wifi => wifi(&r, s),
        .text => textScreen(&r, s),
    }
}
pub fn mismatch(a: []const u8, b: []const u8) usize {
    var n: usize = 0;
    for (a, b) |x, y| n += @popCount(x ^ y);
    return n;
}

test "reference renders 100 times without time or external-state drift" {
    for (catalog.scenarios) |s| {
        var first: [1024]u8 = undefined;
        render(s, fixtures.defaults, &first);
        for (0..100) |_| {
            var next: [1024]u8 = undefined;
            render(s, fixtures.defaults, &next);
            try std.testing.expectEqualSlices(u8, &first, &next);
        }
    }
}
test "reference matches independently captured C++ OLED buffers" {
    for (catalog.scenarios) |s| {
        if (s.verification != .verified) continue;
        var actual: [1024]u8 = undefined;
        render(s, fixtures.defaults, &actual);
        if (!std.mem.eql(u8, s.expected, &actual)) {
            std.debug.print("{s}: {d} mismatched pixels\n", .{ s.name, mismatch(s.expected, &actual) });
            return error.ReferenceMismatch;
        }
    }
}
