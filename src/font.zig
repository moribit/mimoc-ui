const Renderer = @import("renderers/mono1.zig").Renderer;

/// Provider callbacks borrow context; rasterization writes a bounded row-major 1-bit mask.
/// Core imports no platform implementation. Provider must outlive the Runtime.
pub const Provider = struct {
    context: ?*anyopaque = null,
    advance_fn: *const fn (?*anyopaque, u21) u8,
    raster_fn: *const fn (?*anyopaque, u21, *[128]u8) void,
    line_height: u8 = 16,
    pub fn advance(self: Provider, scalar: u21) u8 {
        return self.advance_fn(self.context, scalar);
    }
    pub fn measureText(self: Provider, text: []const u8) i16 {
        var i: usize = 0;
        var width: u32 = 0;
        while (i < text.len) {
            const d = decode(text, i);
            i += d.length;
            width += self.advance(d.scalar);
        }
        return @intCast(@min(width, 32767));
    }
};
pub fn measureWith(provider: anytype, kind: Font, text: []const u8) i16 {
    return if (provider) |p| p.measureText(text) else measure(kind, text);
}
pub fn drawWith(provider: anytype, r: *Renderer, kind: Font, x: i16, y: i16, text: []const u8, on: bool) void {
    const p = provider orelse {
        draw(r, kind, x, y, text, on);
        return;
    };
    var i: usize = 0;
    var cx: i32 = x;
    while (i < text.len) {
        const d = decode(text, i);
        i += d.length;
        var mask: [128]u8 = @splat(0);
        p.raster_fn(p.context, d.scalar, &mask);
        for (0..32) |row| for (0..32) |col| {
            if (mask[row * 4 + col / 8] & (@as(u8, 0x80) >> @as(u3, @intCast(col % 8))) != 0) {
                const px = cx + @as(i32, @intCast(col));
                const py = @as(i32, y) + @as(i32, @intCast(row));
                if (px >= -32768 and px <= 32767 and py >= -32768 and py <= 32767) r.pixel(@intCast(px), @intCast(py), on);
            }
        };
        cx += p.advance(d.scalar);
    }
}

pub const Metrics = struct { width: u8, height: u8, advance: u8 };
pub const Font = enum { tiny5x7, cell8x8 };

pub fn metrics(font: Font, _: u21) Metrics {
    return switch (font) {
        .tiny5x7 => .{ .width = 5, .height = 7, .advance = 6 },
        .cell8x8 => .{ .width = 8, .height = 8, .advance = 8 },
    };
}
pub fn measure(font: Font, text: []const u8) i16 {
    var width: usize = 0;
    var index: usize = 0;
    while (index < text.len) {
        const decoded = decode(text, index);
        index += decoded.length;
        width += metrics(font, decoded.scalar).advance;
    }
    return @intCast(@min(width, 32767));
}
pub fn draw(r: *Renderer, font: Font, x: i16, y: i16, text: []const u8, on: bool) void {
    var index: usize = 0;
    var cursor_x: i32 = x;
    while (index < text.len) {
        const decoded = decode(text, index);
        const c: u8 = if (decoded.scalar <= 0x7f) @intCast(decoded.scalar) else '?';
        index += decoded.length;
        const columns = glyph(c);
        for (columns, 0..) |bits, col| {
            for (0..7) |row| {
                if (bits & (@as(u8, 1) << @as(u3, @intCast(row))) != 0)
                    r.pixel(@intCast(cursor_x + @as(i32, @intCast(col))), @intCast(@as(i32, y) + @as(i32, @intCast(row))), on);
            }
        }
        cursor_x += metrics(font, decoded.scalar).advance;
    }
}

pub const Decoded = struct { scalar: u21, length: u8 };

pub fn decode(bytes: []const u8, index: usize) Decoded {
    const length: u8 = @intCast(codepointBytes(bytes, index));
    if (length == 1) return .{ .scalar = if (bytes[index] < 0x80) bytes[index] else '?', .length = 1 };
    var scalar: u21 = bytes[index] & switch (length) {
        2 => @as(u8, 0x1f),
        3 => @as(u8, 0x0f),
        else => @as(u8, 0x07),
    };
    for (bytes[index + 1 .. index + length]) |part| scalar = (scalar << 6) | @as(u21, part & 0x3f);
    return .{ .scalar = scalar, .length = length };
}

/// Valid UTF-8 sequences stay intact. Invalid bytes are one fallback glyph each.
pub fn codepointBytes(bytes: []const u8, index: usize) usize {
    const first = bytes[index];
    const length: usize = if (first < 0x80) 1 else if (first >= 0xc2 and first <= 0xdf) 2 else if (first >= 0xe0 and first <= 0xef) 3 else if (first >= 0xf0 and first <= 0xf4) 4 else return 1;
    if (index + length > bytes.len) return 1;
    for (bytes[index + 1 .. index + length]) |byte| if (byte & 0xc0 != 0x80) return 1;
    if (length == 3 and ((first == 0xe0 and bytes[index + 1] < 0xa0) or (first == 0xed and bytes[index + 1] >= 0xa0))) return 1;
    if (length == 4 and ((first == 0xf0 and bytes[index + 1] < 0x90) or (first == 0xf4 and bytes[index + 1] >= 0x90))) return 1;
    return length;
}

// Column-major 5x7 glyphs. Unsupported bytes render as a visible question mark.
pub fn glyph(c_: u8) [5]u8 {
    const c = if (c_ >= 'a' and c_ <= 'z') c_ - 32 else c_;
    return switch (c) {
        ' ' => .{ 0, 0, 0, 0, 0 },
        'A' => .{ 0x7e, 0x11, 0x11, 0x11, 0x7e },
        'B' => .{ 0x7f, 0x49, 0x49, 0x49, 0x36 },
        'C' => .{ 0x3e, 0x41, 0x41, 0x41, 0x22 },
        'D' => .{ 0x7f, 0x41, 0x41, 0x22, 0x1c },
        'E' => .{ 0x7f, 0x49, 0x49, 0x49, 0x41 },
        'F' => .{ 0x7f, 0x09, 0x09, 0x09, 0x01 },
        'G' => .{ 0x3e, 0x41, 0x49, 0x49, 0x7a },
        'H' => .{ 0x7f, 0x08, 0x08, 0x08, 0x7f },
        'I' => .{ 0x41, 0x41, 0x7f, 0x41, 0x41 },
        'J' => .{ 0x20, 0x40, 0x41, 0x3f, 0x01 },
        'K' => .{ 0x7f, 0x08, 0x14, 0x22, 0x41 },
        'L' => .{ 0x7f, 0x40, 0x40, 0x40, 0x40 },
        'M' => .{ 0x7f, 0x02, 0x0c, 0x02, 0x7f },
        'N' => .{ 0x7f, 0x04, 0x08, 0x10, 0x7f },
        'O' => .{ 0x3e, 0x41, 0x41, 0x41, 0x3e },
        'P' => .{ 0x7f, 0x09, 0x09, 0x09, 0x06 },
        'Q' => .{ 0x3e, 0x41, 0x51, 0x21, 0x5e },
        'R' => .{ 0x7f, 0x09, 0x19, 0x29, 0x46 },
        'S' => .{ 0x46, 0x49, 0x49, 0x49, 0x31 },
        'T' => .{ 0x01, 0x01, 0x7f, 0x01, 0x01 },
        'U' => .{ 0x3f, 0x40, 0x40, 0x40, 0x3f },
        'V' => .{ 0x1f, 0x20, 0x40, 0x20, 0x1f },
        'W' => .{ 0x7f, 0x20, 0x18, 0x20, 0x7f },
        'X' => .{ 0x63, 0x14, 0x08, 0x14, 0x63 },
        'Y' => .{ 0x03, 0x04, 0x78, 0x04, 0x03 },
        'Z' => .{ 0x61, 0x51, 0x49, 0x45, 0x43 },
        '0' => .{ 0x3e, 0x51, 0x49, 0x45, 0x3e },
        '1' => .{ 0, 0x42, 0x7f, 0x40, 0 },
        '2' => .{ 0x42, 0x61, 0x51, 0x49, 0x46 },
        '3' => .{ 0x21, 0x41, 0x45, 0x4b, 0x31 },
        '4' => .{ 0x18, 0x14, 0x12, 0x7f, 0x10 },
        '5' => .{ 0x27, 0x45, 0x45, 0x45, 0x39 },
        '6' => .{ 0x3c, 0x4a, 0x49, 0x49, 0x30 },
        '7' => .{ 0x01, 0x71, 0x09, 0x05, 0x03 },
        '8' => .{ 0x36, 0x49, 0x49, 0x49, 0x36 },
        '9' => .{ 0x06, 0x49, 0x49, 0x29, 0x1e },
        '-' => .{ 0x08, 0x08, 0x08, 0x08, 0x08 },
        '_' => .{ 0x40, 0x40, 0x40, 0x40, 0x40 },
        ':' => .{ 0, 0x36, 0x36, 0, 0 },
        '.' => .{ 0, 0x40, 0x40, 0, 0 },
        '/' => .{ 0x60, 0x10, 0x08, 0x04, 0x03 },
        '%' => .{ 0x63, 0x13, 0x08, 0x64, 0x63 },
        '>' => .{ 0x41, 0x22, 0x14, 0x08, 0 },
        '<' => .{ 0, 0x08, 0x14, 0x22, 0x41 },
        '[' => .{ 0, 0x7f, 0x41, 0x41, 0 },
        ']' => .{ 0, 0x41, 0x41, 0x7f, 0 },
        '?' => .{ 0x02, 0x01, 0x51, 0x09, 0x06 },
        else => glyph('?'),
    };
}
