//! Converted raster/metrics live with the example, never in embedded Core.
const ui = @import("mimoc_ui");
const std = @import("std");
const assets = @import("glyphs.zig");
pub const Kind = enum(u8) { custom7, font2, misaki8 };
pub const Font = struct {
    kind: Kind,
    printing: bool = false,
    background_gray: u8 = 255,
    pub fn glyph(self: Font, cp: u21) ?*const assets.Glyph {
        for (&assets.glyphs) |*g| if (g.font == @backingInt(self.kind) and g.print == self.printing and g.cp == cp) return g;
        return if (cp != 0xfffd) self.glyph(0xfffd) else null;
    }
    pub fn provider(self: *Font) ui.font.Provider {
        return .{ .context = self, .advance_fn = advance, .raster_fn = raster, .line_height = switch (self.kind) {
            .custom7 => 7,
            .font2 => 16,
            .misaki8 => 7,
        } };
    }
    fn advance(ctx: ?*anyopaque, cp: u21) u8 {
        const self: *Font = @ptrCast(@alignCast(ctx.?));
        return if (self.glyph(cp)) |g| g.advance else 0;
    }
    fn raster(ctx: ?*anyopaque, cp: u21, mask: *[128]u8) void {
        const self: *Font = @ptrCast(@alignCast(ctx.?));
        mask.* = @splat(0);
        if (self.glyph(cp)) |g| {
            const src = assets.masks[g.ink];
            @memcpy(mask[0..src.len], src);
        }
    }
    pub fn measure(self: Font, text: []const u8) i16 {
        var width: i16 = 0;
        var pos: usize = 0;
        while (pos < text.len) {
            const cp = ui.font.decode(text, pos);
            pos += cp.length;
            if (self.glyph(cp.scalar)) |g| width += g.measure;
        }
        return width;
    }
    pub fn draw(self: *Font, r: *ui.mono1.Renderer, x: i16, y: i16, text: []const u8, fg: bool, bg: bool) void {
        // LovyanGFX writes the background only within the glyph's coverage mask.
        var pos: usize = 0;
        var pen = x;
        while (pos < text.len) {
            const cp = ui.font.decode(text, pos);
            pos += cp.length;
            if (self.glyph(cp.scalar)) |g| {
                const coverage = assets.masks[g.coverage];
                for (0..32) |row| for (0..32) |col| {
                    const bit = @as(u8, 128) >> @as(u3, @intCast(col % 8));
                    const index = row * 4 + col / 8;
                    if (index < coverage.len and coverage[index] & bit != 0) {
                        const px = pen + @as(i16, @intCast(col));
                        const yy = y + @as(i16, @intCast(row));
                        const bayer = [_]u8{ 8, 136, 40, 168, 200, 72, 232, 104, 56, 184, 24, 152, 248, 120, 216, 88 };
                        const on = bg and (256 <= @as(u16, self.background_gray) + bayer[@as(usize, @intCast((127 - px) & 3)) | (@as(usize, @intCast((63 - yy) & 3)) << 2)]);
                        r.pixel(px, yy, on);
                    }
                };
                ui.font.drawWith(@as(?ui.font.Provider, self.provider()), r, .tiny5x7, pen, y, text[pos - cp.length .. pos], fg);
                pen += g.advance;
            }
        }
    }
};

test "converted provider preserves actual ASCII/Unicode metrics and fallback" {
    var small = Font{ .kind = .custom7 };
    var english = Font{ .kind = .font2 };
    var japanese = Font{ .kind = .misaki8 };
    try std.testing.expectEqual(@as(u8, 6), small.provider().advance('H'));
    try std.testing.expectEqual(@as(u8, 8), english.provider().advance('H'));
    try std.testing.expectEqual(@as(u8, 8), japanese.provider().advance('ソ'));
    try std.testing.expectEqual(@as(u8, 7), japanese.provider().line_height);
    try std.testing.expectEqual(japanese.glyph(0xfffd).?.ink, japanese.glyph('龍').?.ink);
    for ([_]Font{ small, english, japanese }) |font_value| {
        var font = font_value;
        for ([_][]const u8{ "Hello world", "こんにちは", "沖縄県東村", "CQやりませんか？", "Hello 沖縄 CQ" }) |sample| {
            const provider = font.provider();
            try std.testing.expectEqual(font.measure(sample), provider.measureText(sample));
            var it = ui.wrap.ProviderIterator{ .text = sample, .font = .tiny5x7, .max_width = 24, .provider = provider };
            while (it.next()) |line| {
                try std.testing.expect(std.unicode.utf8ValidateSlice(line.bytes));
                try std.testing.expectEqual(provider.measureText(line.bytes), line.width);
            }
        }
    }
}
