const std = @import("std");
const g = @import("geometry.zig");
const v = @import("view.zig");
const layout = @import("layout.zig");
const input = @import("input.zig");
const font = @import("font.zig");
const anim = @import("animation.zig");
const Renderer = @import("renderers/mono1.zig").Renderer;

pub fn Runtime(comptime config: anytype) type {
    const capacity: usize = if (@TypeOf(config) == comptime_int) config else config.max_nodes;
    const animation_capacity: usize = if (@TypeOf(config) == comptime_int) 0 else config.max_animations;
    if (capacity > 65535 or animation_capacity > 65535) @compileError("Runtime capacities must fit in u16");
    return struct {
        const Self = @This();
        nodes: [capacity]v.Node = undefined,
        tracks: [animation_capacity]anim.Track = undefined,
        len: u16 = 0,
        track_len: u16 = 0,
        focused_id: ?u16 = null,
        viewport: g.Rect = .{ .w = 128, .h = 64 },
        now_ms: anim.Time = 0,

        pub fn beginView(self: *Self) v.InPlaceBuilder(capacity) {
            self.captureAnimatedRects();
            return v.InPlaceBuilder(capacity).initInPlace(&self.nodes);
        }
        pub fn finishView(self: *Self, builder: *const v.InPlaceBuilder(capacity)) error{ DuplicateId, UnclosedContainer }!void {
            try validate(builder.items(), builder.depth);
            self.len = builder.len;
            self.relayout();
            self.retargetTracks();
        }
        pub fn setView(self: *Self, builder: *const v.Builder(capacity)) error{ DuplicateId, UnclosedContainer }!void {
            try validate(builder.items(), builder.depth);
            self.captureAnimatedRects();
            for (builder.items()) |node| if (node.animation.enabled()) self.captureId(node.id);
            self.len = builder.len;
            @memcpy(self.nodes[0..self.len], builder.items());
            self.relayout();
            self.retargetTracks();
        }
        fn validate(nodes: []const v.Node, depth: u16) error{ DuplicateId, UnclosedContainer }!void {
            if (depth != 0) return error.UnclosedContainer;
            for (nodes, 0..) |node, i| {
                for (nodes[0..i]) |prior| if (prior.id == node.id) return error.DuplicateId;
            }
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
        fn visualRect(node: v.Node) g.Rect {
            return .{
                .x = @intCast(@max(-32768, @min(32767, @as(i32, node.frame.x) + node.offset.x))),
                .y = @intCast(@max(-32768, @min(32767, @as(i32, node.frame.y) + node.offset.y))),
                .w = node.frame.w,
                .h = node.frame.h,
            };
        }
        fn sameRect(a: g.Rect, b: g.Rect) bool {
            return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h;
        }
        fn trackIndex(self: *const Self, id: u16) ?usize {
            for (self.tracks[0..self.track_len], 0..) |track, i| if (track.id == id) return i;
            return null;
        }
        fn captureAnimatedRects(self: *Self) void {
            if (comptime animation_capacity == 0) return;
            for (self.nodes[0..self.len]) |node| {
                if (node.animation.enabled()) self.captureId(node.id);
            }
        }
        fn captureId(self: *Self, id: u16) void {
            if (comptime animation_capacity == 0) return;
            if (self.trackIndex(id) != null or self.track_len >= animation_capacity) return;
            for (self.nodes[0..self.len]) |node| if (node.id == id) {
                const f = visualRect(node);
                self.tracks[self.track_len] = .{
                    .id = id,
                    .from = f,
                    .to = f,
                    .current = f,
                    .started_at = self.now_ms,
                    .animation = node.animation,
                };
                self.track_len += 1;
                return;
            };
        }
        fn retargetTracks(self: *Self) void {
            if (comptime animation_capacity == 0) return;
            var i: usize = 0;
            while (i < self.track_len) {
                var matched: ?v.Node = null;
                for (self.nodes[0..self.len]) |node| if (node.id == self.tracks[i].id) {
                    matched = node;
                    break;
                };
                if (matched == null or !matched.?.animation.enabled()) {
                    self.track_len -= 1;
                    self.tracks[i] = self.tracks[self.track_len];
                    continue;
                }
                const node = matched.?;
                const target = visualRect(node);
                var track = &self.tracks[i];
                if (!sameRect(track.to, target)) {
                    track.from = track.current;
                    track.to = target;
                    track.started_at = self.now_ms;
                    track.animation = node.animation;
                    track.active = true;
                }
                i += 1;
            }
        }
        pub fn update(self: *Self, now_ms: anim.Time) void {
            self.now_ms = now_ms;
            for (self.tracks[0..self.track_len]) |*track| {
                if (!track.active) continue;
                const raw = anim.progress(now_ms, track.started_at, track.animation);
                if (raw >= 65535) {
                    track.current = track.to;
                    track.active = false;
                } else track.current = anim.rect(track.from, track.to, anim.eased(raw, track.animation));
            }
        }
        pub fn presentationRect(self: *const Self, id: u16) ?g.Rect {
            for (self.nodes[0..self.len]) |node| if (node.id == id) {
                if (comptime animation_capacity > 0) {
                    if (self.trackIndex(id)) |i| return self.tracks[i].current;
                }
                return visualRect(node);
            };
            return null;
        }
        pub fn activeAnimationCount(self: *const Self) u16 {
            var count: u16 = 0;
            for (self.tracks[0..self.track_len]) |track| if (track.active) {
                count += 1;
            };
            return count;
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
                const f = self.presentationRect(node.id).?;
                switch (node.kind) {
                    .text => font.draw(r, node.font, f.x, f.y, node.text, true),
                    .rect => r.rect(f, true),
                    .filled_rect => r.fillRect(f, true),
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
    try ui.setView(&b);
    try std.testing.expectEqual(@as(?u16, 11), ui.focused_id);
    _ = ui.action(.down);
    try std.testing.expectEqual(@as(?u16, 12), ui.action(.activate));
    try ui.setView(&b);
    try std.testing.expectEqual(@as(?u16, 12), ui.focused_id);
}
