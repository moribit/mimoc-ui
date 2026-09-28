const font = @import("font.zig");
const Renderer = @import("renderers/mono1.zig").Renderer;

pub const Line = struct { bytes: []const u8, width: i16 };

/// The same iterator drives measurement and drawing, including explicit newlines.
pub const Iterator = struct {
    text: []const u8,
    font: font.Font,
    max_width: i16,
    cursor: usize = 0,
    trailing_empty: bool = false,

    pub fn next(self: *Iterator) ?Line {
        if (self.cursor == self.text.len) {
            if (self.trailing_empty) {
                self.trailing_empty = false;
                return .{ .bytes = "", .width = 0 };
            }
            return null;
        }
        const start = self.cursor;
        const max_width = @max(1, self.max_width);
        var pos = start;
        var width: i16 = 0;
        var space_pos: ?usize = null;
        var space_width: i16 = 0;
        while (pos < self.text.len) {
            if (self.text[pos] == '\n') {
                self.cursor = pos + 1;
                self.trailing_empty = self.cursor == self.text.len;
                return .{ .bytes = self.text[start..pos], .width = width };
            }
            const decoded = font.decode(self.text, pos);
            const advance: i16 = font.metrics(self.font, decoded.scalar).advance;
            if (width + advance > max_width and pos > start) {
                if (self.text[pos] == ' ') {
                    self.cursor = pos + 1;
                    while (self.cursor < self.text.len and self.text[self.cursor] == ' ') self.cursor += 1;
                    return .{ .bytes = self.text[start..pos], .width = width };
                }
                if (space_pos) |space| {
                    self.cursor = space + 1;
                    while (self.cursor < self.text.len and self.text[self.cursor] == ' ') self.cursor += 1;
                    return .{ .bytes = self.text[start..space], .width = space_width };
                }
                self.cursor = pos;
                return .{ .bytes = self.text[start..pos], .width = width };
            }
            if (self.text[pos] == ' ') {
                space_pos = pos;
                space_width = width;
            }
            pos += decoded.length;
            width += advance;
        }
        self.cursor = pos;
        return .{ .bytes = self.text[start..pos], .width = width };
    }
};

pub fn lineCount(font_kind: font.Font, text: []const u8, max_width: i16) u16 {
    if (text.len == 0) return 0;
    var it = Iterator{ .text = text, .font = font_kind, .max_width = max_width };
    var count: u16 = 0;
    while (it.next() != null) count +|= 1;
    return count;
}

pub fn height(font_kind: font.Font, text: []const u8, max_width: i16, line_height: u8) i16 {
    const lines = lineCount(font_kind, text, max_width);
    return @intCast(@min(@as(u32, lines) * line_height, 32767));
}

pub fn draw(r: *Renderer, font_kind: font.Font, x: i16, y: i16, text: []const u8, max_width: i16, line_height: u8) void {
    var it = Iterator{ .text = text, .font = font_kind, .max_width = max_width };
    var line: i32 = 0;
    while (it.next()) |item| : (line += 1) {
        const line_y = @as(i32, y) + line * line_height;
        if (line_y >= -32768 and line_y <= 32767) font.draw(r, font_kind, x, @intCast(line_y), item.bytes, true);
    }
}
