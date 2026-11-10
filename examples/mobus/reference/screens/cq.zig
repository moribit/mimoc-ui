//! CQ and QSP input final render paths. Screen/service lifecycles stay in production.
const std = @import("std");
const c = @import("common.zig");
pub fn talk(r: *c.R, f: c.F) void {
    var b: [1024]u8 = undefined;
    const str = c.input(f, &b, f.cursor and !f.persistent);
    if (f.invert) c.rect(r, 0, 0, 128, 64, true, true);
    c.rect(r, 3, 3, 122, 58, !f.invert, false);
    c.tail(r, str, 7, 7, 114, if (f.status.len == 0) 3 else 2, 14, !f.invert, f.invert);
    if (f.status.len > 0) {
        c.rect(r, 7, 49, 114, 10, f.invert, true);
        r.hline(7, 48, 114, !f.invert);
        c.text(r, .font2, 64, 50, f.status, true, false, !f.invert, f.invert);
    }
    c.language(r, f, !f.invert, f.invert);
    if (f.x_offset != 0) {
        var original: [1024]u8 = undefined;
        @memcpy(&original, r.surface.bytes[0..1024]);
        for (0..8) |page| for (0..128) |column| {
            const source = @as(i16, @intCast(column)) - f.x_offset;
            r.surface.bytes[page * 128 + column] = if (source >= 0 and source < 128) original[page * 128 + @as(usize, @intCast(source))] else if (f.invert) 255 else 0;
        };
    }
}
pub fn realtime(r: *c.R, f: c.F) void {
    var b: [1024]u8 = undefined;
    c.mixed(r, c.input(f, &b, f.cursor), 0, 0, .talk, true, false);
    r.hline(0, 32, 128, true);
    if (f.status.len > 0) c.text(r, .font2, 0, 35, f.status, false, true, true, false) else c.mixed(r, f.remote, 0, 35, .talk, true, false);
    c.language(r, f, true, false);
}
pub fn scan(r: *c.R, f: c.F) void {
    if (f.mode == 0) {
        c.text(r, .font2, 64, 18, "Connecting", true, false, true, false);
        c.text(r, .font2, 64, 34, f.title, true, false, true, false);
        return;
    }
    c.text(r, .font2, 64, 0, "Connect?", true, false, true, false);
    c.text(r, .font2, 64, 18, f.title, true, false, true, false);
    for ([_]i16{ 12, 76 }, [_][]const u8{ "No", "Yes" }, 0..) |x, label, i| {
        const sel = @as(i16, @intCast(i)) == f.selected;
        c.raster.roundRect(r, x, 44, 40, 18, 3, sel, true);
        c.raster.roundRect(r, x, 44, 40, 18, 3, true, false);
        c.text(r, .font2, x + 20, 46, label, true, false, !sel, sel);
    }
}
