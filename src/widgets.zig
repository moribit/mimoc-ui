const v = @import("view.zig");
const g = @import("geometry.zig");
const font = @import("font.zig");
const Renderer = @import("renderers/mono1.zig").Renderer;
const theme = @import("theme.zig");

/// Row-major, most-significant-bit-first bitmap data. Const data can live in ROM.
pub const Icon = struct {
    width: u8,
    height: u8,
    data: []const u8,
};

pub const icons = struct {
    pub const back = Icon{ .width = 8, .height = 8, .data = &.{ 0x10, 0x20, 0x40, 0xfe, 0x40, 0x20, 0x10, 0 } };
    pub const forward = Icon{ .width = 8, .height = 8, .data = &.{ 0x08, 0x04, 0x02, 0x7f, 0x02, 0x04, 0x08, 0 } };
    pub const check = Icon{ .width = 8, .height = 8, .data = &.{ 0, 0x01, 0x02, 0x44, 0x28, 0x10, 0, 0 } };
    pub const close = Icon{ .width = 8, .height = 8, .data = &.{ 0, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0 } };
    pub const message = Icon{ .width = 8, .height = 8, .data = &.{ 0x7e, 0x42, 0x42, 0x42, 0x7e, 0x20, 0x10, 0 } };
    pub const settings = Icon{ .width = 8, .height = 8, .data = &.{ 0x18, 0x3c, 0x66, 0xc3, 0xc3, 0x66, 0x3c, 0x18 } };
    pub const wifi = Icon{ .width = 8, .height = 8, .data = &.{ 0, 0x7e, 0x81, 0x3c, 0x42, 0x18, 0x18, 0 } };
    pub const bluetooth = Icon{ .width = 8, .height = 8, .data = &.{ 0x18, 0x14, 0x92, 0x7c, 0x7c, 0x92, 0x14, 0x18 } };
    pub const battery = Icon{ .width = 8, .height = 8, .data = &.{ 0, 0x7e, 0x42, 0x5a, 0x5a, 0x42, 0x7e, 0x18 } };
};

pub fn text(builder: anytype, id: u16, value: []const u8) !void {
    try builder.add(.{ .id = id, .kind = .text, .text = value });
}
pub fn button(builder: anytype, id: u16, label: []const u8) !void {
    try builder.add(.{ .id = id, .kind = .button, .text = label });
}
pub fn icon(builder: anytype, id: u16, bitmap: Icon) !void {
    try builder.add(.{ .id = id, .kind = .icon, .text = bitmap.data, .min_size = .{ .w = bitmap.width, .h = bitmap.height } });
}
pub fn checkbox(builder: anytype, id: u16, label: []const u8, checked: bool) !void {
    try builder.add(.{ .id = id, .kind = .checkbox, .text = label, .padding = @intFromBool(checked) });
}
pub fn toggle(builder: anytype, id: u16, label: []const u8, on: bool, width: i16, style: theme.WidgetStyle) !void {
    const w = @max(width, font.measure(.tiny5x7, label) + 36);
    try builder.begin(id +% 1, .stack, 0, 0, .start);
    try builder.add(.{ .id = id, .kind = .toggle, .text = label, .min_size = .{ .w = w, .h = 12 } });
    try builder.add(.{ .id = id +% 2, .kind = .filled_rect, .min_size = .{ .w = 5, .h = 6 }, .offset = .{ .x = w - (if (on) @as(i16, 8) else @as(i16, 22)), .y = 3 }, .animation = style.animation });
    builder.end();
}
pub fn progress(builder: anytype, id: u16, current: u16, maximum: u16, width: i16, style: theme.WidgetStyle) !void {
    const w = @max(width, 4);
    const interior: i16 = w - 2;
    const fill: i16 = if (maximum == 0) 0 else @intCast(@as(u32, @intCast(interior)) * @as(u32, @min(current, maximum)) / maximum);
    try builder.begin(id +% 1, .stack, 0, 0, .start);
    try builder.add(.{ .id = id, .kind = .progress, .min_size = .{ .w = w, .h = 8 } });
    try builder.add(.{ .id = id +% 2, .kind = .filled_rect, .min_size = .{ .w = fill, .h = 6 }, .offset = .{ .x = 1, .y = 1 }, .animation = style.animation });
    builder.end();
}
pub fn beginPanel(builder: anytype, id: u16, title: ?[]const u8, size: g.Size, style: theme.WidgetStyle) !void {
    try builder.begin(id, .stack, 0, 0, .start);
    try builder.add(.{ .id = id +% 1, .kind = if (style.border) .rect else .spacer, .min_size = size });
    try builder.begin(id +% 2, .column, style.padding, style.spacing, .start);
    if (title) |heading| {
        try text(builder, id +% 3, heading);
        try builder.add(.{ .id = id +% 4, .kind = .divider, .min_size = .{ .w = @max(0, size.w - 2 * @as(i16, style.padding)), .h = 1 } });
    }
}
pub fn endPanel(builder: anytype) void {
    builder.end();
    builder.end();
}

pub fn beginClip(builder: anytype, id: u16, size: g.Size) !void {
    try builder.begin(id, .clip, 0, 0, .start);
    builder.nodes[builder.len - 1].min_size = size;
}
pub fn beginScroll(builder: anytype, id: u16, size: g.Size) !void {
    try builder.begin(id, .scroll, 0, 0, .start);
    builder.nodes[builder.len - 1].min_size = size;
}
pub fn beginList(builder: anytype, id: u16, content_id: u16, size: g.Size, offset: i16, animation: @import("animation.zig").Animation) !void {
    try beginScroll(builder, id, size);
    try builder.begin(content_id, .column, 0, 0, .start);
    builder.nodes[builder.len - 1].offset.y = @intCast(@max(-32768, @min(32767, -@as(i32, offset))));
    builder.nodes[builder.len - 1].animation = animation;
}
pub fn listItem(builder: anytype, id: u16, label: []const u8, width: i16, trailing: bool) !void {
    try builder.add(.{ .id = id, .kind = .list_item, .text = label, .min_size = .{ .w = width, .h = 10 }, .padding = @intFromBool(trailing) });
}
pub fn endList(builder: anytype) void {
    builder.end();
    builder.end();
}

pub fn drawCheckbox(r: *Renderer, frame: g.Rect, label: []const u8, checked: bool, focused: bool) void {
    if (focused) r.rect(frame, true);
    const bx = frame.x + (if (focused) @as(i16, 2) else 0);
    r.rect(.{ .x = bx, .y = frame.y + 1, .w = 9, .h = 9 }, true);
    if (checked) {
        r.line(bx + 2, frame.y + 3, bx + 6, frame.y + 7, true);
        r.line(bx + 6, frame.y + 3, bx + 2, frame.y + 7, true);
    }
    font.draw(r, .tiny5x7, frame.x + 14, frame.y + 2, label, true);
}
pub fn drawToggle(r: *Renderer, frame: g.Rect, label: []const u8, focused: bool) void {
    if (focused) r.fillRect(.{ .x = frame.x, .y = frame.y + 2, .w = 2, .h = 8 }, true);
    font.draw(r, .tiny5x7, frame.x + 4, frame.y + 2, label, true);
    r.rect(.{ .x = frame.x + frame.w - 24, .y = frame.y + 1, .w = 23, .h = 10 }, true);
}
