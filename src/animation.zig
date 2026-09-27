const g = @import("geometry.zig");

pub const Time = u32;
pub const Curve = enum(u8) { none, linear, ease_in, ease_out, ease_in_out, spring };

// Four bytes. Damping is used only by spring: 255 means no overshoot.
pub const Animation = packed struct {
    duration_ms: u16 = 0,
    damping: u8 = 255,
    curve: Curve = .none,

    pub fn linear(ms: u16) Animation {
        return .{ .duration_ms = ms, .curve = .linear };
    }
    pub fn easeIn(ms: u16) Animation {
        return .{ .duration_ms = ms, .curve = .ease_in };
    }
    pub fn easeOut(ms: u16) Animation {
        return .{ .duration_ms = ms, .curve = .ease_out };
    }
    pub fn easeInOut(ms: u16) Animation {
        return .{ .duration_ms = ms, .curve = .ease_in_out };
    }
    pub fn spring(ms: u16, damping: u8) Animation {
        return .{ .duration_ms = ms, .damping = damping, .curve = .spring };
    }
    pub fn enabled(self: Animation) bool {
        return self.curve != .none and self.duration_ms != 0;
    }
};

pub const Track = struct {
    from: g.Rect,
    to: g.Rect,
    current: g.Rect,
    started_at: Time,
    animation: Animation,
    id: u16,
    active: bool = false,
};

// All math is integer fixed point. Callers must sample at least once per 2^31 ms.
pub fn progress(now: Time, started_at: Time, spec: Animation) u32 {
    if (!spec.enabled()) return 65535;
    const elapsed = now -% started_at;
    if (elapsed >= spec.duration_ms) return 65535;
    return @intCast(@as(u64, elapsed) * 65535 / spec.duration_ms);
}
fn mul(a: u32, b: u32) u32 {
    return @intCast(@as(u64, a) * b / 65535);
}
pub fn eased(raw: u32, spec: Animation) u32 {
    const p = @min(raw, 65535);
    return switch (spec.curve) {
        .none, .linear => p,
        .ease_in => mul(p, p),
        .ease_out => 65535 - mul(65535 - p, 65535 - p),
        .ease_in_out => blk: {
            const p2 = mul(p, p);
            break :blk @intCast(@min(65535, @as(u64, p2) * 3 - @as(u64, mul(p2, p)) * 2));
        },
        .spring => blk: {
            const overshoot: u32 = @as(u32, 255 - spec.damping) * 32;
            if (p <= 32767) {
                const half = eased(@min(65535, p * 2), Animation.easeOut(1));
                break :blk @intCast(@as(u64, half) * (65535 + overshoot) / 65535);
            }
            const half = eased(@min(65535, (p - 32768) * 2), Animation.easeOut(1));
            break :blk 65535 + @as(u32, @intCast(@as(u64, overshoot) * (65535 - half) / 65535));
        },
    };
}
fn interpolate(a: i16, b: i16, p: u32) i16 {
    const delta = @as(i64, b) - a;
    const value = @as(i64, a) + @divTrunc(delta * @as(i64, p) + (if (delta >= 0) @as(i64, 32767) else -@as(i64, 32767)), 65535);
    return @intCast(@max(-32768, @min(32767, value)));
}
pub fn rect(from: g.Rect, to: g.Rect, p: u32) g.Rect {
    return .{
        .x = interpolate(from.x, to.x, p),
        .y = interpolate(from.y, to.y, p),
        .w = @max(0, interpolate(from.w, to.w, p)),
        .h = @max(0, interpolate(from.h, to.h, p)),
    };
}
