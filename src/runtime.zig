const std = @import("std");
const g = @import("geometry.zig");
const v = @import("view.zig");
const layout = @import("layout.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const Renderer = @import("renderers/mono1.zig").Renderer;

pub fn Runtime(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        nodes: [capacity]v.Node = undefined,
        len: u16 = 0,
        focused_id: ?u16 = null,
        viewport: g.Rect = .{ .w = 128, .h = 64 },

        pub fn beginView(self: *Self) v.InPlaceBuilder(capacity) {
            return v.InPlaceBuilder(capacity).initInPlace(&self.nodes);
        }
        pub fn finishView(self: *Self, builder: *const v.InPlaceBuilder(capacity)) void {
            self.len = builder.len;
            self.relayout();
        }
        pub fn setView(self: *Self, builder: *const v.Builder(capacity)) void {
            self.len = builder.len;
            @memcpy(self.nodes[0..self.len], builder.items());
            self.relayout();
        }
        fn relayout(self: *Self) void {
            if (self.len > 0) layout.place(self.nodes[0..self.len], 0, self.viewport);
            if (self.focused_id == null or self.focusIndex() == null) self.focused_id = self.firstButton();
        }
        fn firstButton(self: *const Self) ?u16 {
            for (self.nodes[0..self.len]) |node| if (node.kind == .button) {
                return node.id;
            };
            return null;
        }
        fn focusIndex(self: *const Self) ?usize {
            const id = self.focused_id orelse return null;
            for (self.nodes[0..self.len], 0..) |node, i| if (node.kind == .button and node.id == id) {
                return i;
            };
            return null;
        }
        pub fn action(self: *Self, event: input.Action) ?u16 {
            if (event == .activate) return self.focused_id;
            if (event != .up and event != .down and event != .left and event != .right) return null;
            if (self.len == 0) return null;
            const forward = event == .down or event == .right;
            var index = self.focusIndex() orelse 0;
            var attempts: usize = 0;
            while (attempts < self.len) : (attempts += 1) {
                index = if (forward) (index + 1) % self.len else (index + self.len - 1) % self.len;
                if (self.nodes[index].kind == .button) {
                    self.focused_id = self.nodes[index].id;
                    break;
                }
            }
            return null;
        }
        pub fn render(self: *const Self, r: *Renderer) void {
            for (self.nodes[0..self.len]) |node| {
                r.setClip(self.viewport);
                const f = node.frame;
                switch (node.kind) {
                    .text => font.draw(r, node.font, f.x, f.y, node.text, true),
                    .rect => r.rect(f, true),
                    .divider => r.hline(f.x, f.y, f.w, true),
                    .button => {
                        const selected = self.focused_id != null and self.focused_id.? == node.id;
                        r.rect(f, true);
                        if (selected and f.w > 2 and f.h > 2) {
                            r.fillRect(.{ .x = f.x + 1, .y = f.y + 1, .w = f.w - 2, .h = f.h - 2 }, true);
                            font.draw(r, node.font, f.x + 6, f.y + 2, node.text, false);
                        } else font.draw(r, node.font, f.x + 6, f.y + 2, node.text, true);
                    },
                    else => {},
                }
            }
        }
        pub fn nodeCount(self: *const Self) u16 {
            return self.len;
        }
        pub fn bytes() usize {
            return @sizeOf(Self);
        }
    };
}

test "focus follows stable ids" {
    const Ui = Runtime(8);
    var b = v.Builder(8).init();
    try b.begin(1, .column, 0, 0, .start);
    try b.add(.{ .id = 11, .kind = .button, .text = "A" });
    try b.add(.{ .id = 12, .kind = .button, .text = "B" });
    b.end();
    var ui = Ui{};
    ui.setView(&b);
    try std.testing.expectEqual(@as(?u16, 11), ui.focused_id);
    _ = ui.action(.down);
    try std.testing.expectEqual(@as(?u16, 12), ui.action(.activate));
    ui.setView(&b);
    try std.testing.expectEqual(@as(?u16, 12), ui.focused_id);
}
