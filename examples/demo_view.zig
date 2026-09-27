const ui = @import("mimoc_ui");

pub fn build(display: anytype, status: []const u8) void {
    var b = display.beginView();
    b.begin(0, .stack, 0, 0, .start) catch unreachable;
    b.begin(1, .column, 2, 1, .start) catch unreachable;
    b.add(.{ .id = 2, .kind = .text, .text = "MO-BUS" }) catch unreachable;
    b.add(.{ .id = 3, .kind = .divider, .min_size = .{ .w = 124, .h = 1 } }) catch unreachable;
    b.add(.{ .id = 10, .kind = .button, .text = "CHAT", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 11, .kind = .button, .text = "CQ", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 12, .kind = .button, .text = "EHAGAKI", .min_size = .{ .w = 124, .h = 12 } }) catch unreachable;
    b.add(.{ .id = 20, .kind = .text, .text = status }) catch unreachable;
    b.end();
    const indicator_y: i16 = switch (display.focused_id orelse 10) {
        11 => 25,
        12 => 38,
        else => 12,
    };
    b.add(.{ .id = 30, .kind = .filled_rect, .min_size = .{ .w = 2, .h = 10 }, .offset = .{ .x = 0, .y = indicator_y }, .animation = ui.animation.Animation.easeOut(180) }) catch unreachable;
    b.end();
    display.finishView(&b) catch unreachable;
}
