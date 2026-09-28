const ui = @import("mimoc_ui");
const g = ui.geometry;

pub fn at(builder: anytype, id: u16, kind: ui.view.Kind, x: i16, y: i16, size: g.Size, value: []const u8) void {
    builder.add(.{ .id = id, .kind = kind, .text = value, .min_size = size, .offset = .{ .x = x, .y = y } }) catch unreachable;
}

pub fn screenHeader(builder: anytype, title: []const u8) void {
    at(builder, 2, .text, 2, 1, .{}, title);
    at(builder, 3, .divider, 0, 11, .{ .w = 128, .h = 1 }, "");
}

pub fn contactTuner(builder: anytype, markers: []const ui.widgets.Marker, selected: u8) void {
    const index = builder.len;
    ui.widgets.tuner(builder, 100, .{ .markers = markers, .selected = selected, .animation = ui.animation.Animation.easeOut(140) }) catch unreachable;
    builder.nodes[index].offset = .{ .x = 10, .y = 48 };
}

pub fn modeSelector(builder: anytype, value: u8) void {
    at(builder, 40, .text, 27, 23, .{}, "QSP");
    at(builder, 41, .text, 81, 23, .{}, "CQ");
    const index = builder.len;
    ui.widgets.knob(builder, 110, .{ .value = value, .animation = ui.animation.Animation.easeOut(140) }) catch unreachable;
    builder.nodes[index].offset = .{ .x = 53, .y = 29 };
}

pub fn chatMessage(builder: anytype, id: u16, text: []const u8, outgoing: bool, y: i16) void {
    const x: i16 = if (outgoing) 20 else 2;
    at(builder, id, .text, x, y, .{}, if (outgoing) ">" else "<");
    ui.widgets.wrappedText(builder, id + 1, text, 98) catch unreachable;
    builder.nodes[builder.len - 1].offset = .{ .x = x + 8, .y = y };
}

pub fn morseComposer(builder: anytype, body: []const u8, sequence: []const u8, preview: []const u8) void {
    ui.widgets.wrappedText(builder, 20, body, 122) catch unreachable;
    builder.nodes[builder.len - 1].offset = .{ .x = 2, .y = 15 };
    at(builder, 21, .text, 2, 39, .{}, sequence);
    at(builder, 22, .text, 2, 47, .{}, preview);
    at(builder, 23, .divider, 0, 55, .{ .w = 128, .h = 1 }, "");
    at(builder, 24, .text, 2, 57, .{}, "ENTER:SEND BACK");
}

pub fn canvasToolbar(builder: anytype, tool: []const u8, overlay: bool) void {
    if (overlay) {
        at(builder, 80, .rect, 2, 47, .{ .w = 124, .h = 16 }, "");
        at(builder, 81, .text, 5, 49, .{}, tool);
        at(builder, 82, .text, 5, 56, .{}, "ACT:TOOL BACK");
    } else at(builder, 81, .text, 4, 55, .{}, tool);
}
