const font = @import("mimoc_ui").font;
extern fn mimoc_font_advance(scalar: u32) u8;
extern fn mimoc_font_mask(scalar: u32, mask: *[128]u8) void;
fn advance(_: ?*anyopaque, scalar: u21) u8 {
    return mimoc_font_advance(scalar);
}
fn raster(_: ?*anyopaque, scalar: u21, mask: *[128]u8) void {
    mimoc_font_mask(scalar, mask);
}
pub const provider = font.Provider{ .advance_fn = advance, .raster_fn = raster, .line_height = 16 };
