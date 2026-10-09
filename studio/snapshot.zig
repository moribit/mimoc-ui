const std = @import("std");
const scene = @import("main.zig");

/// Writes a headless P4 PBM of the complete Studio surface to stdout.
pub fn main(init: std.process.Init) !void {
    var studio = scene.Studio{};
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    if (args.next()) |mode| {
        if (std.mem.eql(u8, mode, "lab")) {
            studio.lab = true;
            studio.preview_scale = 4;
            if (args.next()) |name| {
                for (@import("mobus_reference").catalog.scenarios, 0..) |scenario, i| {
                    if (std.mem.eql(u8, name, scenario.name)) studio.lab_scenario = i;
                }
            }
            if (args.next()) |comparison| studio.lab_compare = std.meta.stringToEnum(scene.Compare, comparison) orelse return error.UnknownCompareMode;
        }
        if (std.mem.eql(u8, mode, "mobus")) studio.demo_mode = .mobus;
        if (std.mem.eql(u8, mode, "contacts")) {
            studio.demo_mode = .mobus;
            try studio.mobus_state.nav.push(.contacts);
        }
        if (std.mem.eql(u8, mode, "chat")) {
            studio.demo_mode = .mobus;
            try studio.mobus_state.nav.push(.contacts);
            try studio.mobus_state.nav.push(.chat);
        }
        if (std.mem.eql(u8, mode, "composer")) {
            studio.demo_mode = .mobus;
            try studio.mobus_state.nav.push(.contacts);
            try studio.mobus_state.nav.push(.chat);
            try studio.mobus_state.nav.push(.composer);
        }
        if (std.mem.eql(u8, mode, "ehagaki")) {
            studio.demo_mode = .mobus;
            try studio.mobus_state.nav.push(.ehagaki);
        }
    }
    studio.preview.update(0);
    studio.rebuildPreview();
    var bytes: [scene.pbm_header.len + @as(usize, scene.studio_width) * (@as(usize, scene.studio_height) / 8)]u8 = undefined;
    try studio.pbmSnapshot(&bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, &bytes);
}
