const std = @import("std");
const ui = @import("root.zig");

pub fn main() void {
    const Screen = enum(u8) { home, contacts, chat };
    const Tiny = ui.runtime.Runtime(ui.profiles.tiny);
    const TinyBuilder = ui.view.InPlaceBuilder(8);
    const TinyNav = ui.navigation.Navigation(Screen, 3);
    const TinyUi = ui.ui.Ui(u16, ui.profiles.tiny);
    const tiny_ram = @sizeOf(Tiny) + @sizeOf(TinyUi) + @sizeOf(TinyNav) + @sizeOf(ui.scroll.ScrollState) + 128;
    std.debug.print("Target ABI: {s}\nNode={d} Track={d} Builder8={d} Ui8={d} Ui16={d} Runtime8x1={d} Runtime16x4={d} Runtime32x4={d} Runtime64x8={d}\nNavigationEntry={d} Navigation3={d} Navigation8={d} ScrollState={d} VariableRange={d} Scrollbar={d} Tuner={d} Knob={d} Transition={d}\nTiny ABI subtotal: runtime + high-level Ui + nav + scroll + 128-byte page = {d} B\nFlash and static RAM require a linked target firmware image; use tools/ch32-reference-regression.sh.\n", .{
        @tagName(@import("builtin").target.cpu.arch),
        @sizeOf(ui.view.Node),
        @sizeOf(ui.animation.Track),
        @sizeOf(TinyBuilder),
        @sizeOf(TinyUi),
        @sizeOf(ui.ui.Ui(u16, ui.profiles.embedded)),
        @sizeOf(Tiny),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 })),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 32, .max_animations = 4 })),
        @sizeOf(ui.runtime.Runtime(.{ .max_nodes = 64, .max_animations = 8 })),
        @sizeOf(ui.navigation.Navigation(Screen, 8).Entry),
        @sizeOf(TinyNav),
        @sizeOf(ui.navigation.Navigation(Screen, 8)),
        @sizeOf(ui.scroll.ScrollState),
        @sizeOf(ui.scroll.VariableRange),
        @sizeOf(ui.scroll.Scrollbar),
        @sizeOf(ui.widgets.Tuner),
        @sizeOf(ui.widgets.Knob),
        @sizeOf(ui.transition.Transition),
        tiny_ram,
    });
    if (@import("builtin").target.cpu.arch == .riscv32) std.debug.print("CH32V003 remaining before app/driver/stack = {d} B\n", .{2048 - @min(tiny_ram, 2048)});
}
