const g = @import("geometry.zig");

/// The application owns this value and supplies it when rebuilding the view.
pub const ScrollState = struct {
    offset: i16 = 0,

    pub fn clamp(self: *ScrollState, content_height: i16, viewport_height: i16) void {
        self.offset = @intCast(@max(0, @min(@as(i32, self.offset), @as(i32, content_height) - viewport_height)));
    }
};

pub const Range = struct { first: usize, end: usize };

/// For fixed-height rows. Callers may build only these rows and use stable item IDs.
pub fn visibleRange(count: usize, row_height: i16, offset: i16, viewport_height: i16) Range {
    if (row_height <= 0 or viewport_height <= 0) return .{ .first = 0, .end = 0 };
    const first = @min(count, @as(usize, @intCast(@divTrunc(@max(0, offset), row_height))));
    const end = @min(count, @as(usize, @intCast(@divTrunc(@as(i32, @max(0, offset)) + viewport_height + row_height - 1, row_height))) + 1);
    return .{ .first = first, .end = @max(first, end) };
}

pub fn viewport(size: g.Size) g.Rect {
    return .{ .w = size.w, .h = size.h };
}
