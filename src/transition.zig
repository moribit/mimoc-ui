const g = @import("geometry.zig");
const anim = @import("animation.zig");
const Renderer = @import("renderers/mono1.zig").Renderer;

pub const Direction = enum(u8) { none, slide_left, slide_right, slide_up, slide_down };
pub const Capability = enum(u8) { none, single_view, full };

/// A frozen presentation offset. update() is called once per frame, before any pages render.
pub const Transition = struct {
    direction: Direction = .none,
    capability: Capability = .single_view,
    animation: anim.Animation = anim.Animation.easeOut(180),
    started_at: anim.Time = 0,
    size: g.Size = .{},
    incoming: g.Point = .{},
    outgoing: g.Point = .{},
    active: bool = false,

    pub fn start(self: *Transition, direction: Direction, now: anim.Time, size: g.Size) void {
        self.direction = direction;
        self.started_at = now;
        self.size = size;
        self.active = direction != .none and self.capability != .none and self.animation.enabled();
        self.update(now);
    }
    pub fn update(self: *Transition, now: anim.Time) void {
        if (!self.active) {
            self.incoming = .{};
            self.outgoing = .{};
            return;
        }
        const raw = anim.progress(now, self.started_at, self.animation);
        const p = anim.eased(raw, self.animation);
        const incoming_from: g.Point = switch (self.direction) {
            .none => .{},
            .slide_left => .{ .x = self.size.w },
            .slide_right => .{ .x = @intCast(@max(-32768, -@as(i32, self.size.w))) },
            .slide_up => .{ .y = self.size.h },
            .slide_down => .{ .y = @intCast(@max(-32768, -@as(i32, self.size.h))) },
        };
        self.incoming = .{ .x = anim.rect(.{ .x = incoming_from.x }, .{}, p).x, .y = anim.rect(.{ .y = incoming_from.y }, .{}, p).y };
        self.outgoing = .{ .x = self.incoming.x - incoming_from.x, .y = self.incoming.y - incoming_from.y };
        if (raw == 65535) {
            self.active = false;
            self.incoming = .{};
        }
    }
};

pub fn Shifted(comptime RuntimeType: type) type {
    return struct {
        runtime: *const RuntimeType,
        offset: g.Point,
        pub fn render(self: *const @This(), renderer: *Renderer) void {
            self.runtime.renderShifted(renderer, self.offset);
        }
    };
}

/// Optional richer backend path; each runtime is supplied by the caller.
pub fn Pair(comptime OldType: type, comptime NewType: type) type {
    return struct {
        old: *const OldType,
        new: *const NewType,
        transition: *const Transition,
        pub fn render(self: *const @This(), renderer: *Renderer) void {
            if (self.transition.active) self.old.renderShifted(renderer, self.transition.outgoing);
            self.new.renderShifted(renderer, self.transition.incoming);
        }
    };
}

test "transition start midpoint end and delayed frame" {
    const std = @import("std");
    var t = Transition{ .animation = anim.Animation.linear(100) };
    t.start(.slide_left, 0, .{ .w = 128, .h = 64 });
    try std.testing.expectEqual(@as(i16, 128), t.incoming.x);
    t.update(50);
    try std.testing.expectEqual(@as(i16, 64), t.incoming.x);
    try std.testing.expectEqual(@as(i16, -64), t.outgoing.x);
    t.update(200);
    try std.testing.expectEqual(@as(i16, 0), t.incoming.x);
    try std.testing.expect(!t.active);
    t.start(.slide_right, 200, .{ .w = 128, .h = 64 });
    try std.testing.expectEqual(@as(i16, -128), t.incoming.x);
    t.capability = .none;
    t.start(.slide_up, 300, .{ .w = 128, .h = 64 });
    try std.testing.expectEqual(@as(i16, 0), t.incoming.y);
    t.capability = .single_view;
    t.start(.slide_up, 400, .{ .w = 128, .h = 64 });
    try std.testing.expectEqual(@as(i16, 64), t.incoming.y);
    t.start(.slide_down, 500, .{ .w = 128, .h = 64 });
    try std.testing.expectEqual(@as(i16, -64), t.incoming.y);
}
