//! Production QSP history, distinct from Open Chat. Original body clip and prefix inversion.
const std = @import("std");
const c = @import("common.zig");
pub fn render(r: *c.R, f: c.F) void {
    r.setClip(.{ .x = 0, .y = 16, .w = 128, .h = 48 });
    var y: i16 = 16 + f.offset;
    var total: i16 = 0;
    var previous: ?[]const u8 = null;
    for (f.entries) |entry| {
        const incoming = !std.mem.eql(u8, entry.sender, "Me");
        const changed = if (previous) |p| !std.mem.eql(u8, p, entry.sender) else false;
        const prefix = previous == null or changed;
        const lines = c.wrap(entry.text, 107, .history);
        const text_y = y + @as(i16, if (changed) 5 else 0);
        const height: @TypeOf(y) = @as(i16, @intCast(@max(1, lines.len))) * 13;
        const block = height + @as(i16, if (changed) 5 else 0);
        total += block;
        if (y + block > 15 and y < 64) {
            if (!incoming) c.rect(r, 0, @max(text_y, 16), 12, @max(0, @min(text_y + height, 64) - @max(text_y, 16)), true, true);
            if (prefix and text_y + 13 > 16) {
                const top = @max(text_y + 3, 18);
                if (top < 64) {
                    const cy = top + 3;
                    r.hline(if (incoming) 1 else 2, cy, 6, incoming);
                    c.raster.line(r, if (incoming) 6 else 2, cy, if (incoming) 3 else 5, top, incoming);
                    c.raster.line(r, if (incoming) 6 else 2, cy, if (incoming) 3 else 5, top + 6, incoming);
                }
            }
            if (changed and y + 2 >= 16 and y + 2 < 64) {
                var x: i16 = 0;
                while (x <= 128) : (x += 4) r.hline(x, y + 2, 2, true);
            }
            for (lines.spans[0..lines.len], 0..) |line, i| {
                const yy = text_y + @as(i16, @intCast(i)) * 13;
                if (yy + 13 > 16 and yy < 64) c.mixed(r, line, 16, yy, .history, true, false);
            }
        }
        y += block;
        previous = entry.sender;
    }
    r.setClip(.{ .x = 0, .y = 0, .w = 128, .h = 64 });
    if (f.entries.len == 0) c.text(r, .font2, 10, 20, "Loading...", false, true, true, false) else if (total > 48) {
        const thumb = @max(6, @divTrunc(48 * 48, total));
        const range = @max(1, total - 48);
        const progress = std.math.clamp(-f.offset, 0, range);
        const yy = 16 + @divTrunc((48 - thumb) * progress, range);
        r.vline(124, 16, 48, true);
        c.rect(r, 125, 16, 2, 48, false, true);
        c.rect(r, 125, yy, 2, thumb, true, true);
    }
    c.rect(r, 0, 0, 128, 15, false, true);
    c.text(r, .font2, 64, 0, "Hazuki", true, false, true, false);
    r.hline(0, 14, 128, true);
    r.hline(0, 15, 128, false);
    c.notice(r, f.notice);
}
