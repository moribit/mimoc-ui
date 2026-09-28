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

pub fn buildHome(view: anytype) void {
    c.screenHeader(view, "MO-BUS");
    c.at(view, .home_contacts, .button, 15, 19, .{ .w = 98, .h = 14 }, "CONTACTS");
    c.at(view, .home_ehagaki, .button, 15, 39, .{ .w = 98, .h = 14 }, "EHAGAKI");
}

pub fn buildContacts(view: anytype, state: anytype) void {
    const labels = [_][]const u8{ "ALICE", "BOB", "CAROL", "DAVE", "EMPTY", "FRANK", "GRACE", "HEIDI", "EMPTY", "JUDY" };
    c.at(view, .contact_border, .rect, 30, 2, .{ .w = 68, .h = 18 }, "");
    const label = labels[state.selected_contact];
    c.at(view, .contact_label, .text, 64 - @divTrunc(ui.font.measure(.tiny5x7, label), 2), 7, .{}, label);
    c.modeSelector(view, state.mode);
    c.contactTuner(view, &state.markers, state.selected_contact);
}

pub fn buildChat(view: anytype, state: anytype) void {
    c.screenHeader(view, "ALICE / CHAT");
    const heights = messageHeights();
    const visible = ui.scroll.variableVisibleRange(&heights, state.chat_scroll.offset, 40);
    const nearby = ui.scroll.variableVisibleRange(&heights, @max(0, visible.offset - 40), 120);
    {
        var viewport = view.clip(.chat_viewport, .{ .size = .{ .w = 123, .h = 40 }, .offset = .{ .x = 1, .y = 14 } });
        defer viewport.end();
        var content = view.stack(.chat_content, .{ .size = .{ .w = 123, .h = @intCast(@min(32767, visible.total_height)) }, .offset = .{ .y = @intCast(-visible.offset) }, .animation = ui.animation.Animation.easeOut(120) });
        defer content.end();
        var y = nearby.first_y;
        for (nearby.first..nearby.end) |index| {
            c.chatMessage(view, index, messages[index], index % 2 == 1, @intCast(y));
            y += heights[index];
        }
    }
    view.scrollbarAt(.chat_scrollbar, 40, visible.total_height, visible.offset, 5, .{ .x = 124, .y = 14 });
    c.at(view, .chat_separator, .divider, 0, 55, .{ .w = 128, .h = 1 }, "");
    c.at(view, .chat_hint, .text, 2, 57, .{}, "ENTER:WRITE  BACK");
}

pub fn buildComposer(view: anytype, state: anytype) void {
    c.screenHeader(view, "ALICE / WRITE");
    c.morseComposer(view, if (state.composer_extended) "HELLO WORLD" else "HELLO W", if (state.composer_extended) ".--. .-" else ".--.", if (state.composer_extended) "A" else "W");
}

pub fn buildEhagaki(view: anytype, state: anytype) void {
    view.bitmapAt(.canvas_bitmap, .{ .width = 122, .height = 58, .stride = 16, .data = &state.canvas }, .{ .x = 3, .y = 3 });
    c.at(view, .canvas_border, .rect, 2, 2, .{ .w = 124, .h = 60 }, "");
    c.at(view, .cursor, .rect, state.cursor_x - 2, state.cursor_y - 2, .{ .w = 5, .h = 5 }, "");
    switch (state.tool) {
        1 => c.at(view, .tool_preview, .divider, state.cursor_x, state.cursor_y, .{ .w = 20, .h = 1 }, ""),
        2 => c.at(view, .tool_preview, .rect, state.cursor_x, state.cursor_y, .{ .w = 16, .h = 10 }, ""),
        else => {},
    }
    c.canvasToolbar(view, switch (state.tool) {
        0 => "DOT",
        1 => "LINE",
        2 => "RECT",
        else => "FILL",
    }, state.overlay);
}
