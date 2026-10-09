const std = @import("std");
const ref = @import("main.zig");
pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const name = args.next() orelse "menu/default";
    const out = std.Io.File.stdout();
    if (std.mem.eql(u8, name, "--inventory")) {
        for (ref.catalog.scenarios) |s| {
            try out.writeStreamingAll(init.io, s.name);
            try out.writeStreamingAll(init.io, " ");
            try out.writeStreamingAll(init.io, @tagName(s.verification));
            try out.writeStreamingAll(init.io, "\n");
        }
        for (ref.catalog.inventory.unverified) |entry| for (entry.states) |state| {
            try out.writeStreamingAll(init.io, entry.name);
            try out.writeStreamingAll(init.io, "/");
            try out.writeStreamingAll(init.io, state);
            try out.writeStreamingAll(init.io, " unverified\n");
        };
        return;
    }
    if (std.mem.eql(u8, name, "--list")) {
        for (ref.catalog.scenarios) |s| {
            try out.writeStreamingAll(init.io, s.name);
            try out.writeStreamingAll(init.io, "\n");
        }
        return;
    }
    const scenario = ref.catalog.find(name) orelse return error.UnknownScenario;
    var data: [1024]u8 = undefined;
    ref.render(scenario, ref.fixtures.defaults, &data);
    const format = args.next() orelse "--pbm";
    if (std.mem.eql(u8, format, "--raw")) {
        try out.writeStreamingAll(init.io, &data);
        return;
    }
    if (!std.mem.eql(u8, format, "--pbm")) return error.UnknownFormat;
    var pbm: [1024]u8 = @splat(0);
    for (0..64) |y| for (0..128) |x| {
        if (data[(y / 8) * 128 + x] & (@as(u8, 1) << @as(u3, @intCast(y % 8))) != 0) pbm[y * 16 + x / 8] |= @as(u8, 128) >> @as(u3, @intCast(x % 8));
    };
    try out.writeStreamingAll(init.io, "P4\n128 64\n");
    try out.writeStreamingAll(init.io, &pbm);
}
