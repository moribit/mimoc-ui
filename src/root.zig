pub const geometry = @import("geometry.zig");
pub const surface = @import("surface.zig");
pub const font = @import("font.zig");
pub const view = @import("view.zig");
pub const layout = @import("layout.zig");
pub const input = @import("input.zig");
pub const animation = @import("animation.zig");
pub const runtime = @import("runtime.zig");
pub const mono1 = @import("renderers/mono1.zig");
pub const headless = @import("renderers/headless.zig");

test {
    _ = @import("geometry.zig");
    _ = @import("renderers/mono1.zig");
    _ = @import("runtime.zig");
    _ = @import("tests.zig");
}
