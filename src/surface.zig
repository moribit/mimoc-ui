pub const Mono1 = struct {
    bytes: []u8,
    width: i16,
    height: i16,
    first_page: u8 = 0,

    pub fn requiredBytes(width: usize, height: usize) usize {
        return width * ((height + 7) / 8);
    }
    pub fn init(bytes: []u8, width: i16, height: i16) error{InvalidSize}!Mono1 {
        if (width <= 0 or height <= 0 or bytes.len < requiredBytes(@intCast(width), @intCast(height))) return error.InvalidSize;
        return .{ .bytes = bytes, .width = width, .height = height };
    }
    pub fn page(bytes: []u8, width: i16, page_index: u8) error{InvalidSize}!Mono1 {
        if (width <= 0 or bytes.len < @as(usize, @intCast(width))) return error.InvalidSize;
        return .{ .bytes = bytes, .width = width, .height = 8, .first_page = page_index };
    }
    pub fn clear(self: *Mono1, on: bool) void {
        @memset(self.bytes, if (on) 0xff else 0);
    }
    pub fn pixel(self: *Mono1, x: i16, y: i16, on: bool) void {
        const local_y = @as(i32, y) - @as(i32, self.first_page) * 8;
        if (x < 0 or x >= self.width or local_y < 0 or local_y >= self.height) return;
        const index = @as(usize, @intCast(@divTrunc(local_y, 8))) * @as(usize, @intCast(self.width)) + @as(usize, @intCast(x));
        const bit: u3 = @intCast(@mod(local_y, 8));
        if (on) self.bytes[index] |= @as(u8, 1) << bit else self.bytes[index] &= ~(@as(u8, 1) << bit);
    }
    pub fn get(self: *const Mono1, x: i16, y: i16) bool {
        const local_y = @as(i32, y) - @as(i32, self.first_page) * 8;
        if (x < 0 or x >= self.width or local_y < 0 or local_y >= self.height) return false;
        const index = @as(usize, @intCast(@divTrunc(local_y, 8))) * @as(usize, @intCast(self.width)) + @as(usize, @intCast(x));
        return self.bytes[index] & (@as(u8, 1) << @as(u3, @intCast(@mod(local_y, 8)))) != 0;
    }
};
