const mimoc = @import("mimoc_ui");

pub const Id = enum(u16) { root, content, title, line, chat, cq, ehagaki, status, indicator };

pub fn build(display: anytype, status: []const u8) void {
    const Display = @TypeOf(display.*);
    const Ui = mimoc.ui.Ui(Id, Display.configuration);
    var ui = Ui.begin(display);
    {
        var root = ui.stack(.root, .{});
        defer root.end();
        {
            var content = ui.column(.content, .{ .padding = 2, .spacing = 1 });
            defer content.end();
            ui.text(.title, "MO-BUS");
            ui.divider(.line, 124);
            ui.buttonWith(.chat, "CHAT", .{ .size = .{ .w = 124, .h = 12 } });
            ui.buttonWith(.cq, "CQ", .{ .size = .{ .w = 124, .h = 12 } });
            ui.buttonWith(.ehagaki, "EHAGAKI", .{ .size = .{ .w = 124, .h = 12 } });
            ui.text(.status, status);
        }
        const content_key = Ui.childId(Ui.rootId(.root), .content);
        const indicator_y: i16 = if (display.focused_id == Ui.childId(content_key, .cq)) 25 else if (display.focused_id == Ui.childId(content_key, .ehagaki)) 38 else 12;
        ui.filledRect(.indicator, .{ .w = 2, .h = 10 }, .{ .x = 0, .y = indicator_y }, mimoc.animation.Animation.easeOut(180));
    }
    ui.finish();
}

pub fn activated(display: anytype) ?Id {
    const Display = @TypeOf(display.*);
    const Ui = mimoc.ui.Ui(Id, Display.configuration);
    const selected = display.action(.activate) orelse return null;
    const content_key = Ui.childId(Ui.rootId(.root), .content);
    inline for (.{ Id.chat, Id.cq, Id.ehagaki }) |candidate| {
        if (selected == Ui.childId(content_key, candidate)) return candidate;
    }
    return null;
}
