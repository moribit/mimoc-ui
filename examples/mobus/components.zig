const ui = @import("mimoc_ui");
const id = @import("id.zig");

pub fn at(view: anytype, logical: id.Id, kind: ui.view.Kind, x: i16, y: i16, size: ui.geometry.Size, value: []const u8) void {
    view.primitive(logical, kind, value, .{ .size = size, .offset = .{ .x = x, .y = y } });
}

pub fn screenHeader(view: anytype, title: []const u8) void {
    var header = view.scope(.header);
    defer header.end();
    at(view, .title, .text, 2, 1, .{}, title);
    at(view, .line, .divider, 0, 11, .{ .w = 128, .h = 1 }, "");
}

pub fn contactTuner(view: anytype, markers: []const ui.widgets.Marker, selected: u8) void {
    view.tunerAt(.tuner, .{ .markers = markers, .selected = selected, .animation = ui.animation.Animation.easeOut(140) }, .{ .x = 10, .y = 48 });
}

pub fn modeSelector(view: anytype, value: u8) void {
    at(view, .qsp_label, .text, 27, 23, .{}, "QSP");
    at(view, .cq_label, .text, 81, 23, .{}, "CQ");
    view.knobAt(.knob, .{ .value = value, .animation = ui.animation.Animation.easeOut(140) }, .{ .x = 53, .y = 29 });
}

pub fn chatMessage(view: anytype, index: usize, text: []const u8, outgoing: bool, y: i16) void {
    const x: i16 = if (outgoing) 20 else 2;
    at(view, id.message(index, 0), .text, x, y, .{}, if (outgoing) ">" else "<");
    view.wrappedTextAt(id.message(index, 1), text, 98, .{ .x = x + 8, .y = y });
}

pub fn morseComposer(view: anytype, body: []const u8, sequence: []const u8, preview: []const u8) void {
    view.wrappedTextAt(.body, body, 122, .{ .x = 2, .y = 15 });
    at(view, .morse, .text, 2, 39, .{}, sequence);
    at(view, .decoded, .text, 2, 47, .{}, preview);
    at(view, .footer_line, .divider, 0, 55, .{ .w = 128, .h = 1 }, "");
    at(view, .footer_hint, .text, 2, 57, .{}, "ENTER:SEND BACK");
}

pub fn canvasToolbar(view: anytype, tool: []const u8, overlay: bool) void {
    if (overlay) {
        at(view, .toolbar_panel, .rect, 2, 47, .{ .w = 124, .h = 16 }, "");
        at(view, .toolbar_title, .text, 5, 49, .{}, tool);
        at(view, .toolbar_hint, .text, 5, 56, .{}, "ACT:TOOL BACK");
    } else at(view, .toolbar_title, .text, 4, 55, .{}, tool);
}
