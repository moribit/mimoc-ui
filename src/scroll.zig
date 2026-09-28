const g = @import("geometry.zig");

/// The application owns this value and supplies it when rebuilding the view.
pub const ScrollState = struct {
    offset: i16 = 0,

    pub fn clamp(self: *ScrollState, content_height: i16, viewport_height: i16) void {
        self.offset = @intCast(@max(0, @min(@as(i32, self.offset), @as(i32, content_height) - viewport_height)));
    }
};

pub const Range = struct { first: usize, end: usize };

/// Pure index over application-owned item heights. No per-item runtime storage.
pub const VariableRange = struct {
    first: usize,
    end: usize,
    first_y: i32,
    total_height: i32,
    offset: i32,
};

pub fn variableTotalHeight(heights: []const u16) i32 {
    var total: i32 = 0;
    for (heights) |height| total = @intCast(@min(2147483647, @as(i64, total) + height));
    return total;
}

pub fn variableVisibleRange(heights: []const u16, requested_offset: i32, viewport_height: i16) VariableRange {
    const total = variableTotalHeight(heights);
    const offset = @max(0, @min(requested_offset, total - @as(i32, @max(0, viewport_height))));
    if (viewport_height <= 0) return .{ .first = 0, .end = 0, .first_y = 0, .total_height = total, .offset = offset };
    var y: i32 = 0;
    var first: usize = heights.len;
    var end: usize = heights.len;
    var first_y: i32 = total;
    for (heights, 0..) |height, index| {
        const next: i32 = @intCast(@min(2147483647, @as(i64, y) + height));
        if (first == heights.len and next > offset) {
            first = index;
            first_y = y;
        }
        if (first != heights.len and @as(i64, y) < @as(i64, offset) + viewport_height) end = index + 1;
        y = next;
    }
    return .{ .first = first, .end = end, .first_y = first_y, .total_height = total, .offset = offset };
}

pub const Scrollbar = struct { y: i16, height: i16, visible: bool };

pub fn scrollbar(viewport_height: i16, content_height: i32, offset: i32, min_thumb: i16) Scrollbar {
    if (viewport_height <= 0 or content_height <= viewport_height) return .{ .y = 0, .height = 0, .visible = false };
    const h: i32 = @intCast(@min(viewport_height, @max(min_thumb, @divTrunc(@as(i64, viewport_height) * viewport_height, content_height))));
    const max_offset = content_height - viewport_height;
    const clamped = @max(0, @min(offset, max_offset));
    return .{ .y = @intCast(@divTrunc(@as(i64, clamped) * (@as(i32, viewport_height) - h), max_offset)), .height = @intCast(h), .visible = true };
}

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
