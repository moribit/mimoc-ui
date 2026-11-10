const c = @import("../common.zig");
pub fn render(r: *c.R, f: c.F) void {
    c.text(r, .font2, 64, 0, "Ehagaki", true, false, true, false);
    if (@import("std").mem.eql(u8, f.kind, "post_confirm")) {
        c.text(r, .font2, 64, 20, "Post?", true, false, true, false);
        c.raster.roundRect(r, 44, 44, 40, 18, 3, true, true);
        c.raster.roundRect(r, 44, 44, 40, 18, 3, true, false);
        c.text(r, .font2, 64, 46, "OK", true, false, false, true);
    } else {
        c.text(r, .font2, 64, 18, "Public?", true, false, true, false);
        for ([_]i16{ 12, 76 }, [_][]const u8{ "No", "Yes" }, 0..) |x, label, i| {
            const sel = @as(i16, @intCast(i)) == f.selected;
            c.raster.roundRect(r, x, 44, 40, 18, 3, sel, true);
            c.raster.roundRect(r, x, 44, 40, 18, 3, true, false);
            c.text(r, .font2, x + 20, 46, label, true, false, !sel, sel);
        }
    }
}
