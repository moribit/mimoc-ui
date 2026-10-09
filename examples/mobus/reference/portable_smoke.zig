//! Same reference renderer, fixed state, caller-owned framebuffer; no OS/heap.
const ref = @import("mobus_reference");
const Program = struct { screen: ref.catalog.Screen, variant: u8 };
const programs = blk: {
    var list: [ref.catalog.scenarios.len]Program = undefined;
    for (ref.catalog.scenarios, 0..) |s, i| list[i] = .{ .screen = s.screen, .variant = s.variant };
    break :blk list;
};
export fn mimoc_reference_render(index: u32, pixels: [*]u8, len: usize) c_int {
    if (index >= programs.len or len != 1024) return -1;
    const p = programs[index];
    ref.render(.{ .name = "", .screen = p.screen, .variant = p.variant, .expected = "" }, ref.fixtures.defaults, pixels[0..1024]);
    return 0;
}
