const ui = @import("root.zig");

const Screen = enum(u8) { home, contacts, chat, composer, ehagaki };

/// Compile this object for the target and inspect the exported little-endian u32 values.
pub export var mimoc_footprint: [17]u32 = .{
    @sizeOf(ui.view.Node),
    @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 })),
    @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 })),
    @sizeOf(ui.view.InPlaceBuilder(16)),
    @sizeOf(ui.animation.Track),
    @sizeOf(ui.navigation.Navigation(Screen, 5)),
    @sizeOf(ui.scroll.ScrollState),
    @sizeOf(ui.scroll.VariableRange),
    @sizeOf(ui.scroll.Scrollbar),
    @sizeOf(ui.widgets.Tuner),
    @sizeOf(ui.widgets.Knob),
    @sizeOf(ui.transition.Transition),
    @sizeOf(ui.runtime.Runtime(ui.profiles.tiny)),
    @sizeOf(ui.view.InPlaceBuilder(8)),
    @sizeOf(ui.navigation.Navigation(Screen, 3)),
    @sizeOf(ui.ui.Ui(u16, ui.profiles.tiny)),
    @sizeOf(ui.ui.Ui(u16, ui.profiles.embedded)),
};
