//! Frozen existing baseline renderer; geometry deliberately unchanged.
const std = @import("std");
const ui = @import("mimoc_ui");
const raster = ui.raster_compat;
const fonts = @import("../fonts.zig");
const fixtures = @import("../fixtures.zig");
const Scenario = @import("../catalog.zig").Scenario;
const R = ui.mono1.Renderer;
const text = @import("legacy_text.zig").text;
const shadedText = @import("legacy_text.zig").shadedText;
const Row = struct { text: [320]u8 = @splat(0), len: usize = 0, mine: bool = false };
pub fn render(r: *R, s: Scenario, f: fixtures.Fixture) void {
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
