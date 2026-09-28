const Animation = @import("animation.zig").Animation;

pub const WidgetStyle = struct {
    padding: u8 = 2,
    spacing: u8 = 2,
    border: bool = true,
    animation: Animation = Animation.easeOut(120),
};

pub const default: WidgetStyle = .{};
