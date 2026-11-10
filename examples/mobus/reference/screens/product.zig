const std = @import("std");
const c = @import("common.zig");
pub fn render(r: *c.R, f: c.F) void {
    if (std.mem.eql(u8, f.kind, "synth")) @import("synth.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "qsp")) @import("qsp.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "talk")) @import("cq.zig").talk(r, f) else if (std.mem.eql(u8, f.kind, "realtime")) @import("cq.zig").realtime(r, f) else if (std.mem.eql(u8, f.kind, "scan")) @import("cq.zig").scan(r, f) else if (std.mem.eql(u8, f.kind, "canvas")) @import("ehagaki/canvas.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "browse")) @import("ehagaki/browse.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "eha_text")) @import("ehagaki/text.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "visibility") or std.mem.eql(u8, f.kind, "post_confirm")) @import("ehagaki/dialogs.zig").render(r, f) else if (std.mem.eql(u8, f.kind, "root")) {
        c.text(r, .font2, 64, 0, "Ehagaki", true, false, true, false);
        for ([_][]const u8{ "POST", "MY POST", "TIMELINE" }, 0..) |label, i| {
            const y: i16 = 16 + @as(i16, @intCast(i)) * 16;
            const sel = f.selected == @as(i16, @intCast(i));
            if (sel) c.raster.roundRect(r, 9, y - 1, 110, 15, 2, true, true);
            c.text(r, .custom7, 64, y, label, true, false, !sel, sel);
        }
    } else if (std.mem.eql(u8, f.kind, "profile")) @import("support.zig").profile(r, f) else if (std.mem.eql(u8, f.kind, "list")) @import("support.zig").list(r, f) else if (std.mem.eql(u8, f.kind, "language")) @import("support.zig").language(r, f) else if (std.mem.eql(u8, f.kind, "keyboard")) @import("support.zig").keyboard(r, f) else if (std.mem.eql(u8, f.kind, "hello")) @import("support.zig").hello(r, f) else if (std.mem.eql(u8, f.kind, "open_compose")) @import("support.zig").openComposer(r, f) else if (std.mem.eql(u8, f.kind, "scan_list")) @import("support.zig").scanList(r, f) else if (std.mem.eql(u8, f.kind, "draw")) @import("support.zig").draw(r, f) else c.status(r, f);
}
