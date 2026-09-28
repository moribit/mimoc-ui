const std = @import("std");
const ui = @import("root.zig");

pub fn main() void {
    const Screen = enum(u8) { home, contacts, chat };
    std.debug.print("Node={d} Runtime16x4={d} Runtime32x4={d} Runtime64x8={d} Builder16={d} Track={d} NavigationEntry={d} Navigation8={d} ScrollState={d} VariableRange={d} Scrollbar={d} Tuner={d} Knob={d} Transition={d}\n", .{
        @sizeOf(ui.view.Node),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 })),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 })),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 64, .max_animations = 8 })),
        @sizeOf(ui.view.InPlaceBuilder(16)),
        @sizeOf(ui.animation.Track),
        @sizeOf(ui.navigation.Navigation(Screen, 8).Entry),
        @sizeOf(ui.navigation.Navigation(Screen, 8)),
        @sizeOf(ui.scroll.ScrollState),
        @sizeOf(ui.scroll.VariableRange),
        @sizeOf(ui.scroll.Scrollbar),
        @sizeOf(ui.widgets.Tuner),
        @sizeOf(ui.widgets.Knob),
        @sizeOf(ui.transition.Transition),
    });
}
