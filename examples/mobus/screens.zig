const ui = @import("mimoc_ui");
const c = @import("components.zig");

pub const messages = [_][]const u8{
    "CQ CQ", "HELLO", "THIS IS A LONG MESSAGE FROM ALICE", "OK", "THE SIGNAL IS GOOD TODAY", "QSP?", "YES. I CAN HEAR YOU.", "SEND A POSTCARD", "WE ARE AT THE HARBOR NOW", "ROGER", "SEE YOU SOON", "73",
};

pub fn messageHeights() [messages.len]u16 {
    var heights: [messages.len]u16 = undefined;
    for (messages, 0..) |message, i| heights[i] = @intCast(ui.wrap.height(.tiny5x7, message, 98, 8) + 5);
    return heights;
}

pub fn buildHome(builder: anytype) void {
    c.screenHeader(builder, "MO-BUS");
    c.at(builder, 10, .button, 15, 19, .{ .w = 98, .h = 14 }, "CONTACTS");
    c.at(builder, 11, .button, 15, 39, .{ .w = 98, .h = 14 }, "EHAGAKI");
}

pub fn buildContacts(builder: anytype, state: anytype) void {
    const labels = [_][]const u8{ "ALICE", "BOB", "CAROL", "DAVE", "EMPTY", "FRANK", "GRACE", "HEIDI", "EMPTY", "JUDY" };
    c.at(builder, 4, .rect, 30, 2, .{ .w = 68, .h = 18 }, "");
    const label = labels[state.selected_contact];
    c.at(builder, 5, .text, 64 - @divTrunc(ui.font.measure(.tiny5x7, label), 2), 7, .{}, label);
    c.modeSelector(builder, state.mode);
    c.contactTuner(builder, &state.markers, state.selected_contact);
}

pub fn buildChat(builder: anytype, state: anytype) void {
    c.screenHeader(builder, "ALICE / CHAT");
    const heights = messageHeights();
    const visible = ui.scroll.variableVisibleRange(&heights, state.chat_scroll.offset, 40);
    const nearby = ui.scroll.variableVisibleRange(&heights, @max(0, visible.offset - 40), 120);
    ui.widgets.beginClip(builder, 50, .{ .w = 123, .h = 40 }) catch unreachable;
    builder.nodes[builder.len - 1].offset = .{ .x = 1, .y = 14 };
    builder.begin(51, .stack, 0, 0, .start) catch unreachable;
    builder.nodes[builder.len - 1].min_size = .{ .w = 123, .h = @intCast(@min(32767, visible.total_height)) };
    builder.nodes[builder.len - 1].offset.y = @intCast(-visible.offset);
    builder.nodes[builder.len - 1].animation = ui.animation.Animation.easeOut(120);
    var y = nearby.first_y;
    for (nearby.first..nearby.end) |index| {
        const outgoing = index % 2 == 1;
        c.chatMessage(builder, @intCast(100 + index * 2), messages[index], outgoing, @intCast(y));
        y += heights[index];
    }
    builder.end();
    builder.end();
    const scroll_index = builder.len;
    ui.widgets.scrollbar(builder, 60, 40, visible.total_height, visible.offset, 5) catch unreachable;
    if (builder.len > scroll_index) builder.nodes[scroll_index].offset = .{ .x = 124, .y = 14 };
    c.at(builder, 70, .divider, 0, 55, .{ .w = 128, .h = 1 }, "");
    c.at(builder, 71, .text, 2, 57, .{}, "ENTER:WRITE  BACK");
}

pub fn buildComposer(builder: anytype, state: anytype) void {
    c.screenHeader(builder, "ALICE / WRITE");
    c.morseComposer(builder, if (state.composer_extended) "HELLO WORLD" else "HELLO W", if (state.composer_extended) ".--. .-" else ".--.", if (state.composer_extended) "A" else "W");
}

pub fn buildEhagaki(builder: anytype, state: anytype) void {
    ui.widgets.bitmap(builder, 10, .{ .width = 122, .height = 58, .stride = 16, .data = &state.canvas }) catch unreachable;
    builder.nodes[builder.len - 1].offset = .{ .x = 3, .y = 3 };
    c.at(builder, 11, .rect, 2, 2, .{ .w = 124, .h = 60 }, "");
    c.at(builder, 12, .rect, state.cursor_x - 2, state.cursor_y - 2, .{ .w = 5, .h = 5 }, "");
    switch (state.tool) {
        1 => c.at(builder, 13, .divider, state.cursor_x, state.cursor_y, .{ .w = 20, .h = 1 }, ""),
        2 => c.at(builder, 13, .rect, state.cursor_x, state.cursor_y, .{ .w = 16, .h = 10 }, ""),
        else => {},
    }
    c.canvasToolbar(builder, switch (state.tool) {
        0 => "DOT",
        1 => "LINE",
        2 => "RECT",
        else => "FILL",
    }, state.overlay);
}
