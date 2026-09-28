const std = @import("std");
const scene = @import("main.zig");

/// Writes a headless P4 PBM of the complete Studio surface to stdout.
pub fn main(init: std.process.Init) !void {
    var studio = scene.Studio{};
    studio.preview.update(0);
    studio.rebuildPreview();
    var bytes: [scene.pbm_header.len + @as(usize, scene.studio_width) * (@as(usize, scene.studio_height) / 8)]u8 = undefined;
    try studio.pbmSnapshot(&bytes);
    try std.Io.File.stdout().writeStreamingAll(init.io, &bytes);
}
