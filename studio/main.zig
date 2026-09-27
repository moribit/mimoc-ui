const std = @import("std");
const ui = @import("mimoc_ui");
const demo = @import("demo_view");

const StudioUi = ui.runtime.Runtime(64);
const Preview = ui.runtime.Runtime(.{ .max_nodes = 16, .max_animations = 4 });
const profiles = [_][]const u8{ "DESKTOP", "SSD1306 FULL", "SSD1306 PAGE", "CH32V003", "ESP32-S3" };
const rates = [_]u8{ 60, 30, 15, 10 };

extern fn mimoc_window_run(pixels: [*]const u8, width: c_int, height: c_int, scale: c_int, title: [*:0]const u8) void;
extern fn mimoc_window_redraw() void;
extern fn mimoc_now_ms() u32;

const Studio = struct {
    chrome: StudioUi = .{},
    preview: Preview = .{},
    canvas: [384 * 24]u8 = [_]u8{0} ** (384 * 24),
    preview_pixels: [1024]u8 = [_]u8{0} ** 1024,
    running: bool = true,
    overlay: bool = false,
    preview_scale: u8 = 2,
    fps_index: u8 = 1,
    profile_index: u8 = 2,
    frame_number: u32 = 0,
    clock_ms: u32 = 0,
    last_real_ms: ?u32 = null,
    accumulated_ms: u32 = 0,
    last_action: []const u8 = "NONE",
    preview_status: []const u8 = "READY",
    selected_id: ?u16 = null,
    frame_label: [24]u8 = undefined,
    fps_label: [24]u8 = undefined,
    nodes_label: [24]u8 = undefined,
    anim_label: [24]u8 = undefined,
    focus_label: [24]u8 = undefined,
    input_label: [24]u8 = undefined,
    runtime_label: [24]u8 = undefined,
    buffer_label: [24]u8 = undefined,
    remaining_label: [24]u8 = undefined,
    selected_label: [24]u8 = undefined,

    fn label(buffer: *[24]u8, comptime fmt: []const u8, args: anytype) []const u8 {
        return std.fmt.bufPrint(buffer, fmt, args) catch unreachable;
    }
    fn addText(b: anytype, id: u16, value: []const u8, x: i16, y: i16) void {
        b.add(.{ .id = id, .kind = .text, .text = value, .offset = .{ .x = x, .y = y } }) catch unreachable;
    }
    fn addButton(b: anytype, id: u16, value: []const u8, x: i16, y: i16, width: i16) void {
        b.add(.{ .id = id, .kind = .button, .text = value, .offset = .{ .x = x, .y = y }, .min_size = .{ .w = width, .h = 12 } }) catch unreachable;
    }
    fn frameBufferBytes(self: *const Studio) usize {
        return switch (self.profile_index) {
            2, 3 => 128,
            else => 1024,
        };
    }
    fn rebuildChrome(self: *Studio) void {
        var b = self.chrome.beginView();
        b.begin(1, .stack, 0, 0, .start) catch unreachable;
        addText(&b, 2, "MIMOC UI STUDIO", 4, 4);
        addText(&b, 3, if (self.running) "RUN" else "PAUSE", 334, 4);
        b.add(.{ .id = 4, .kind = .divider, .min_size = .{ .w = 376, .h = 1 }, .offset = .{ .x = 4, .y = 15 } }) catch unreachable;
        b.add(.{ .id = 5, .kind = .rect, .min_size = .{ .w = 264, .h = 140 }, .offset = .{ .x = 4, .y = 20 } }) catch unreachable;
        b.add(.{ .id = 6, .kind = .rect, .min_size = .{ .w = 108, .h = 140 }, .offset = .{ .x = 272, .y = 20 } }) catch unreachable;

        addText(&b, 10, profiles[self.profile_index], 276, 24);
        addText(&b, 11, "128X64 1BIT", 276, 36);
        addText(&b, 12, label(&self.fps_label, "FPS {d}", .{rates[self.fps_index]}), 276, 48);
        addText(&b, 13, label(&self.frame_label, "FRAME {d}", .{self.frame_number}), 276, 60);
        addText(&b, 14, label(&self.nodes_label, "NODES {d}/16", .{self.preview.nodeCount()}), 276, 72);
        addText(&b, 15, label(&self.anim_label, "ANIM {d}/4", .{self.preview.activeAnimationCount()}), 276, 84);
        addText(&b, 16, label(&self.focus_label, "FOCUS {d}", .{self.preview.focused_id orelse 0}), 276, 96);
        addText(&b, 17, label(&self.input_label, "INPUT {s}", .{self.last_action}), 276, 108);
        addText(&b, 18, label(&self.runtime_label, "RT {d}B", .{@sizeOf(Preview)}), 276, 120);
        addText(&b, 19, label(&self.buffer_label, "BUF {d}B", .{self.frameBufferBytes()}), 276, 132);
        const remaining = if (self.profile_index == 3) @as(i32, 2048) - @as(i32, @intCast(@sizeOf(Preview) + @sizeOf(ui.view.InPlaceBuilder(16)) + 128)) else 0;
        addText(&b, 20, if (self.profile_index == 3) label(&self.remaining_label, "LEFT {d}B", .{remaining}) else "RAM --", 276, 144);
        addText(&b, 21, label(&self.selected_label, "NODE {d} {d}X", .{ self.selected_id orelse 0, self.preview_scale }), 276, 152);

        addButton(&b, 100, "RUN", 4, 168, 40);
        addButton(&b, 101, "PAUSE", 48, 168, 46);
        addButton(&b, 102, "RESTART", 98, 168, 54);
        addButton(&b, 103, "STEP", 156, 168, 40);
        addButton(&b, 104, "FPS", 200, 168, 44);
        addButton(&b, 105, "TARGET", 248, 168, 54);
        addButton(&b, 106, "OVR", 306, 168, 38);
        addButton(&b, 107, "1/2X", 348, 168, 32);
        b.end();
        self.chrome.finishView(&b) catch unreachable;
    }
    fn paint(self: *Studio) void {
        self.rebuildChrome();
        ui.headless.render(&self.chrome, &self.canvas, 384, 192) catch unreachable;
        ui.headless.render(&self.preview, &self.preview_pixels, 128, 64) catch unreachable;
        var surface = ui.surface.Mono1.init(&self.canvas, 384, 192) catch unreachable;
        var r = ui.mono1.Renderer.init(&surface);
        const scale: i16 = self.preview_scale;
        const origin_x: i16 = 8;
        const origin_y: i16 = 24;
        r.fillRect(.{ .x = origin_x, .y = origin_y, .w = 128 * scale, .h = 64 * scale }, false);
        var preview_surface = ui.surface.Mono1.init(&self.preview_pixels, 128, 64) catch unreachable;
        for (0..64) |y| for (0..128) |x| {
            if (preview_surface.get(@intCast(x), @intCast(y))) {
                r.fillRect(.{ .x = origin_x + @as(i16, @intCast(x)) * scale, .y = origin_y + @as(i16, @intCast(y)) * scale, .w = scale, .h = scale }, true);
            }
        };
        if (self.overlay) {
            r.rect(.{ .x = origin_x, .y = origin_y, .w = 128 * scale, .h = 64 * scale }, true);
            for (self.preview.nodes[0..self.preview.len]) |node| {
                const f = self.preview.presentationRect(node.id).?;
                const bounds = ui.geometry.Rect{ .x = origin_x + f.x * scale, .y = origin_y + f.y * scale, .w = f.w * scale, .h = f.h * scale };
                r.rect(bounds, true);
                if (self.selected_id != null and self.selected_id.? == node.id) r.rect(.{ .x = bounds.x - 1, .y = bounds.y - 1, .w = bounds.w + 2, .h = bounds.h + 2 }, true);
                var id_bytes: [8]u8 = undefined;
                const id_text = std.fmt.bufPrint(&id_bytes, "{d}", .{node.id}) catch unreachable;
                ui.font.draw(&r, .tiny5x7, bounds.x, bounds.y, id_text, true);
            }
        }
        mimoc_window_redraw();
    }
    fn restart(self: *Studio) void {
        self.preview = .{};
        self.preview.update(0);
        self.preview_status = "READY";
        demo.build(&self.preview, self.preview_status);
        self.clock_ms = 0;
        self.frame_number = 0;
        self.accumulated_ms = 0;
        self.last_real_ms = null;
        self.selected_id = null;
        self.paint();
    }
    fn step(self: *Studio) void {
        self.running = false;
        self.clock_ms +%= 16;
        self.preview.update(self.clock_ms);
        self.frame_number +%= 1;
        self.paint();
    }
    fn clickControl(self: *Studio, id: u16) void {
        switch (id) {
            100 => {
                self.running = true;
                self.last_real_ms = null;
            },
            101 => self.running = false,
            102 => {
                self.restart();
                return;
            },
            103 => {
                self.step();
                return;
            },
            104 => self.fps_index = @intCast((@as(usize, self.fps_index) + 1) % rates.len),
            105 => self.profile_index = @intCast((@as(usize, self.profile_index) + 1) % profiles.len),
            106 => self.overlay = !self.overlay,
            107 => self.preview_scale = if (self.preview_scale == 1) 2 else 1,
            else => return,
        }
        self.paint();
    }
    fn input(self: *Studio, action: ui.input.Action) void {
        self.preview.update(self.clock_ms);
        if (self.preview.action(action)) |id| {
            self.preview_status = switch (id) {
                10 => "CHAT OPEN",
                11 => "CQ OPEN",
                12 => "EHAGAKI OPEN",
                else => "READY",
            };
        }
        self.last_action = switch (action) {
            .up => "UP",
            .down => "DOWN",
            .left => "LEFT",
            .right => "RIGHT",
            .activate => "ACT",
            .back => "BACK",
        };
        demo.build(&self.preview, self.preview_status);
        self.paint();
    }
    fn tick(self: *Studio, now_ms: u32) void {
        const previous = self.last_real_ms orelse {
            self.last_real_ms = now_ms;
            return;
        };
        self.last_real_ms = now_ms;
        if (!self.running) return;
        self.accumulated_ms +%= @min(now_ms -% previous, 1000);
        const interval = @divTrunc(@as(u32, 1000), rates[self.fps_index]);
        if (self.accumulated_ms < interval) return;
        self.clock_ms +%= self.accumulated_ms;
        self.accumulated_ms = 0;
        self.preview.update(self.clock_ms);
        self.frame_number +%= 1;
        self.paint();
    }
};

var studio = Studio{};

export fn mimoc_key(key: c_int) void {
    const action: ?ui.input.Action = switch (key) {
        0 => .up,
        1 => .down,
        2 => .left,
        3 => .right,
        4 => .activate,
        5 => .back,
        else => null,
    };
    if (action) |a| {
        studio.input(a);
    } else {
        switch (key) {
            6 => studio.clickControl(100),
            7 => studio.clickControl(101),
            8 => studio.clickControl(102),
            9 => studio.clickControl(103),
            10 => studio.clickControl(104),
            11 => studio.clickControl(105),
            12 => studio.clickControl(106),
            13 => studio.clickControl(107),
            else => {},
        }
    }
}
export fn mimoc_tick(now_ms: u32) void {
    studio.tick(now_ms);
}
export fn mimoc_click(x: c_int, y: c_int) void {
    for (studio.chrome.nodes[0..studio.chrome.len]) |node| {
        if (node.kind == .button and studio.chrome.presentationRect(node.id).?.contains(@intCast(x), @intCast(y))) {
            studio.clickControl(node.id);
            return;
        }
    }
    const px = @divTrunc(x - 8, studio.preview_scale);
    const py = @divTrunc(y - 24, studio.preview_scale);
    if (px < 0 or py < 0 or px >= 128 or py >= 64) return;
    var i: usize = studio.preview.len;
    while (i > 0) {
        i -= 1;
        const node = studio.preview.nodes[i];
        if (studio.preview.presentationRect(node.id).?.contains(@intCast(px), @intCast(py))) {
            studio.selected_id = node.id;
            if (node.kind == .button) {
                studio.preview.focused_id = node.id;
                demo.build(&studio.preview, studio.preview_status);
            }
            studio.paint();
            return;
        }
    }
}
pub fn main() void {
    studio.preview.update(0);
    demo.build(&studio.preview, studio.preview_status);
    studio.paint();
    studio.last_real_ms = mimoc_now_ms();
    mimoc_window_run(&studio.canvas, 384, 192, 3, "Mimoc UI Studio");
}

test "Studio changes actual update cadence and manual steps" {
    try std.testing.expectEqual(@as(usize, 3096), @sizeOf(StudioUi));
    try std.testing.expectEqual(@as(usize, 936), @sizeOf(Preview));
    var s = Studio{};
    s.last_real_ms = 0;
    s.tick(16);
    try std.testing.expectEqual(@as(u32, 0), s.frame_number);
    s.tick(32);
    try std.testing.expectEqual(@as(u32, 0), s.frame_number);
    s.tick(48);
    try std.testing.expectEqual(@as(u32, 1), s.frame_number);
    s.clickControl(101);
    s.tick(200);
    try std.testing.expectEqual(@as(u32, 1), s.frame_number);
    s.step();
    try std.testing.expectEqual(@as(u32, 2), s.frame_number);
    try std.testing.expectEqual(@as(u32, 64), s.clock_ms);
    s.clickControl(104);
    try std.testing.expectEqual(@as(u8, 15), rates[s.fps_index]);
    for (rates, 0..) |fps, index| {
        var cadence = Studio{};
        cadence.fps_index = @intCast(index);
        cadence.last_real_ms = 0;
        const interval = @divTrunc(@as(u32, 1000), fps);
        cadence.tick(interval - 1);
        try std.testing.expectEqual(@as(u32, 0), cadence.frame_number);
        cadence.tick(interval);
        try std.testing.expectEqual(@as(u32, 1), cadence.frame_number);
    }
}
