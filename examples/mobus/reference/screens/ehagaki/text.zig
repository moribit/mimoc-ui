const std = @import("std");
const c = @import("../common.zig");
pub fn render(r: *c.R, f: c.F) void {
    const japanese = std.mem.eql(u8, f.locale, "ja") and !f.ascii_header;
    const k: c.fonts.Kind = if (japanese) .misaki8 else .custom7;
    var label_buf: [128]u8 = undefined;
    @memcpy(label_buf[0..f.title.len], f.title);
    if (!japanese) for (label_buf[0..f.title.len]) |*ch| {
        ch.* = std.ascii.toUpper(ch.*);
    };
    const label = label_buf[0..f.title.len];
    var b: [1024]u8 = undefined;
    const count = std.fmt.bufPrint(&b, "{d}-{d}", .{ f.count, f.limit }) catch unreachable;
    const lw = (c.fonts.Font{ .kind = k }).measure(label);
    const cw = (c.fonts.Font{ .kind = .custom7 }).measure(count);
    const x = 64 - @divTrunc(lw + 4 + cw, 2);
    const yy: @TypeOf(x) = if (japanese) 5 else 2;
    c.text(r, k, x, yy, label, false, false, true, false);
    c.text(r, .custom7, x + lw + 4, yy, count, false, false, true, false);
    r.hline(0, if (japanese) 17 else 14, 128, true);
    c.tail(r, c.input(f, &b, f.cursor), 0, if (japanese) 19 else 16, 126, 3, 14, true, false);
    c.language(r, f, true, false);
}
