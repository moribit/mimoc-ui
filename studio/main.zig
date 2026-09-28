const std = @import("std");
const ui = @import("mimoc_ui");
const demo = @import("demo_view");
const showcase = @import("showcase");
const mobus = @import("mobus_demo");

pub const studio_width: i16 = 704;
pub const studio_height: i16 = 336;
const studio_viewport = ui.geometry.Rect{ .w = studio_width, .h = studio_height };
const preview_viewport = ui.geometry.Rect{ .w = 128, .h = 64 };
const preview_area = ui.geometry.Rect{ .x = 16, .y = 44, .w = 512, .h = 256 };
pub const pbm_header = std.fmt.comptimePrint("P4\n{d} {d}\n", .{ studio_width, studio_height });
const appkit_scale: c_int = 2;

const StudioUi = ui.runtime.Runtime(64);
const Preview = ui.runtime.Runtime(.{ .max_nodes = 64, .max_animations = 8 });
// Updated by `zig build resource-report` and the RV32 footprint probe.
const ch32_runtime_bytes: usize = 968;
const ch32_ui_budget: usize = ch32_runtime_bytes + 40 + 42 + 2 + 24 + 128;
const profiles = [_][]const u8{ "DESKTOP", "SSD1306 FULL", "SSD1306 PAGE", "CH32V003", "ESP32-S3" };
const rates = [_]u8{ 60, 30, 15, 10 };

extern fn mimoc_window_run(pixels: [*]const u8, width: c_int, height: c_int, scale: c_int, title: [*:0]const u8) void;
extern fn mimoc_window_redraw() void;
extern fn mimoc_now_ms() u32;

pub const Studio = struct {
    chrome: StudioUi = .{ .viewport = studio_viewport },
    preview: Preview = .{ .viewport = preview_viewport },
    showcase_state: showcase.State = .{},
    mobus_state: mobus.State = .{},
    demo_mode: showcase.Mode = .classic,
    canvas: [@as(usize, studio_width) * (@as(usize, studio_height) / 8)]u8 = [_]u8{0} ** (@as(usize, studio_width) * (@as(usize, studio_height) / 8)),
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
    inspect_details: bool = false,
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
    scale_label: [24]u8 = undefined,
    demo_label: [24]u8 = undefined,
    nav_label: [24]u8 = undefined,
    detail_labels: [8][24]u8 = undefined,

    pub fn rebuildPreview(self: *Studio) void {
        if (self.demo_mode == .classic) demo.build(&self.preview, self.preview_status) else if (self.demo_mode == .mobus) mobus.build(&self.preview, &self.mobus_state) else showcase.build(&self.preview, &self.showcase_state, self.demo_mode);
    }

    fn label(buffer: *[24]u8, comptime fmt: []const u8, args: anytype) []const u8 {
        return std.fmt.bufPrint(buffer, fmt, args) catch unreachable;
    }
    fn addText(view: anytype, id: u16, value: []const u8, x: i16, y: i16) void {
        view.textWith(id, value, .{ .offset = .{ .x = x, .y = y } });
    }
    fn addButton(view: anytype, id: u16, value: []const u8, x: i16, y: i16, width: i16) void {
        view.buttonWith(id, value, .{ .offset = .{ .x = x, .y = y }, .size = .{ .w = width, .h = 12 } });
    }
    fn frameBufferBytes(self: *const Studio) usize {
        return switch (self.profile_index) {
            2, 3 => 128,
            else => 1024,
        };
    }
    fn rebuildChrome(self: *Studio) void {
        const View = ui.ui.Ui(u16, StudioUi.configuration);
        var view = View.begin(&self.chrome);
        view.screen("Studio");
        {
            var root = view.stack(1, .{});
            defer root.end();
            addText(&view, 2, "MIMOC UI STUDIO", 8, 7);
            addText(&view, 3, if (self.running) "RUNNING" else "PAUSED", 326, 7);
            view.primitive(4, .divider, "", .{ .size = .{ .w = 688, .h = 1 }, .offset = .{ .x = 8, .y = 23 } });
            view.primitive(5, .rect, "", .{ .size = .{ .w = 528, .h = 276 }, .offset = .{ .x = 8, .y = 28 } });
            addText(&view, 6, "PREVIEW", 16, 34);
            {
                var panel = view.panelAt(200, "INSPECTOR", .{ .w = 152, .h = 276 }, .{ .padding = 6, .spacing = 8 }, .{ .x = 544, .y = 28 });
                defer panel.end();
                if (self.inspect_details) {
                    if (self.selectedNodeIndex()) |index| {
                        const node = self.preview.nodes[index];
                        const presentation = self.preview.presentationRect(node.id).?;
                        const clip = self.clipFor(index);
                        view.text(10, label(&self.detail_labels[0], "ID {d}", .{node.id}));
                        view.text(11, label(&self.detail_labels[1], "KIND {s}", .{@tagName(node.kind)}));
                        view.text(12, label(&self.detail_labels[2], "RECT {d},{d} {d}X{d}", .{ node.frame.x, node.frame.y, node.frame.w, node.frame.h }));
                        view.text(13, label(&self.detail_labels[3], "SHOW {d},{d} {d}X{d}", .{ presentation.x, presentation.y, presentation.w, presentation.h }));
                        view.text(14, label(&self.detail_labels[4], "PARENT {d}", .{if (node.parent == 0xffff) @as(u16, 0) else self.preview.nodes[node.parent].id}));
                        view.text(15, label(&self.detail_labels[5], "FOCUS {s}", .{if (self.focusable(node.kind)) "YES" else "NO"}));
                        view.text(16, label(&self.detail_labels[6], "CLIP {d},{d} {d}X{d}", .{ clip.x, clip.y, clip.w, clip.h }));
                        view.text(17, label(&self.detail_labels[7], "MOTION {s}", .{@tagName(node.animation.curve)}));
                    } else view.text(10, "SELECT PREVIEW NODE");
                } else {
                    const usage = self.preview.resources();
                    const nav_used: u8 = switch (self.demo_mode) {
                        .navigation => self.showcase_state.nav.usage().used,
                        .mobus => self.mobus_state.nav.usage().used,
                        else => 0,
                    };
                    const nav_capacity: u8 = switch (self.demo_mode) {
                        .navigation => self.showcase_state.nav.usage().capacity,
                        .mobus => self.mobus_state.nav.usage().capacity,
                        else => 0,
                    };
                    view.text(10, label(&self.demo_label, "TARGET {s}", .{profiles[self.profile_index]}));
                    view.text(11, "SIZE 128X64 1BIT");
                    view.text(12, label(&self.fps_label, "FPS {d}", .{rates[self.fps_index]}));
                    view.text(13, label(&self.frame_label, "FRAME {d}", .{self.frame_number}));
                    view.text(14, label(&self.nodes_label, "NODES {d}/{d}", .{ usage.nodes.used, if (self.profile_index == 3) @as(u16, 16) else usage.nodes.capacity }));
                    view.text(15, label(&self.anim_label, "ANIM {d}/{d}", .{ usage.animations.used, usage.animations.capacity }));
                    view.text(16, label(&self.focus_label, "FOCUS {d}", .{self.preview.focused_id orelse 0}));
                    view.text(17, label(&self.input_label, "INPUT {s}", .{self.last_action}));
                    view.text(18, label(&self.runtime_label, "RUNTIME {d}B", .{if (self.profile_index == 3) ch32_runtime_bytes else @as(usize, @sizeOf(Preview))}));
                    view.text(19, label(&self.buffer_label, "BUFFER {d}B", .{self.frameBufferBytes()}));
                    const remaining = if (self.profile_index == 3) @as(i32, 2048 - ch32_ui_budget) else 0;
                    view.text(20, if (self.profile_index == 3) label(&self.remaining_label, "RAM LEFT {d}B", .{remaining}) else "RAM LEFT --");
                    view.text(21, label(&self.scale_label, "SCALE {d}X", .{self.preview_scale}));
                    view.text(22, label(&self.selected_label, "NODE {d}", .{self.selected_id orelse 0}));
                    view.text(23, label(&self.nav_label, "NAV {d}/{d}", .{ nav_used, nav_capacity }));
                }
            }
            addButton(&view, 100, "RUN", 414, 5, 48);
            addButton(&view, 101, "PAUSE", 466, 5, 54);
            addButton(&view, 102, "RESTART", 524, 5, 72);
            addButton(&view, 103, "STEP +16MS", 600, 5, 96);
            view.primitive(7, .divider, "", .{ .size = .{ .w = 688, .h = 1 }, .offset = .{ .x = 8, .y = 309 } });
            addButton(&view, 104, "FPS", 8, 315, 46);
            addButton(&view, 107, "SCALE", 58, 315, 54);
            addButton(&view, 106, if (self.overlay) "OVR ON" else "OVERLAY", 116, 315, 64);
            addButton(&view, 105, "TARGET", 184, 315, 58);
            addButton(&view, 108, "DEMO", 246, 315, 50);
            addText(&view, 109, switch (self.demo_mode) {
                .classic => "CLASSIC",
                .widgets => "WIDGETS",
                .navigation => "NAVIGATION",
                .mobus => "MO-BUS",
            }, 306, 317);
            addButton(&view, 110, if (self.inspect_details) "SUMMARY" else "DETAIL", 400, 315, 78);
        }
        view.finish();
    }
    fn selectedNodeIndex(self: *const Studio) ?usize {
        const key = self.selected_id orelse return null;
        for (self.preview.nodes[0..self.preview.len], 0..) |node, index| if (node.id == key) return index;
        return null;
    }
    fn clipFor(self: *const Studio, index: usize) ui.geometry.Rect {
        var clip = self.preview.viewport;
        var parent = self.preview.nodes[index].parent;
        while (parent != 0xffff) {
            const ancestor = self.preview.nodes[parent];
            if (ancestor.kind == .clip or ancestor.kind == .scroll) clip = ui.geometry.Rect.intersect(clip, self.preview.presentationRect(ancestor.id).?);
            parent = ancestor.parent;
        }
        return clip;
    }
    fn focusable(_: *const Studio, kind: ui.view.Kind) bool {
        return kind == .button or kind == .checkbox or kind == .toggle or kind == .list_item or kind == .tuner or kind == .knob;
    }
    fn controlId(key: u16) ?u16 {
        const View = ui.ui.Ui(u16, StudioUi.configuration);
        const root = View.rootId(1);
        for (100..111) |candidate| {
            const raw: u16 = @intCast(candidate);
            if (View.childId(root, raw) == key) return raw;
        }
        return null;
    }
    fn previewOrigin(self: *const Studio) ui.geometry.Point {
        const scale: i16 = self.preview_scale;
        return .{
            .x = preview_area.x + @divTrunc(preview_area.w - 128 * scale, 2),
            .y = preview_area.y + @divTrunc(preview_area.h - 64 * scale, 2),
        };
    }
    fn compose(self: *Studio) void {
        self.rebuildChrome();
        ui.headless.render(&self.chrome, &self.canvas, studio_width, studio_height) catch unreachable;
        if (self.demo_mode == .navigation or self.demo_mode == .mobus) {
            const shifted = ui.transition.Shifted(Preview){ .runtime = &self.preview, .offset = if (self.demo_mode == .mobus) self.mobus_state.transition.incoming else self.showcase_state.transition.incoming };
            ui.headless.render(&shifted, &self.preview_pixels, 128, 64) catch unreachable;
        } else ui.headless.render(&self.preview, &self.preview_pixels, 128, 64) catch unreachable;
        var surface = ui.surface.Mono1.init(&self.canvas, studio_width, studio_height) catch unreachable;
        var r = ui.mono1.Renderer.init(&surface);
        const scale: i16 = self.preview_scale;
        const origin = self.previewOrigin();
        r.fillRect(preview_area, false);
        r.rect(.{ .x = origin.x - 2, .y = origin.y - 2, .w = 128 * scale + 4, .h = 64 * scale + 4 }, true);
        var preview_surface = ui.surface.Mono1.init(&self.preview_pixels, 128, 64) catch unreachable;
        for (0..64) |y| for (0..128) |x| {
            if (preview_surface.get(@intCast(x), @intCast(y))) {
                r.fillRect(.{ .x = origin.x + @as(i16, @intCast(x)) * scale, .y = origin.y + @as(i16, @intCast(y)) * scale, .w = scale, .h = scale }, true);
            }
        };
        if (self.overlay) {
            r.setClip(preview_area);
            r.rect(.{ .x = origin.x, .y = origin.y, .w = 128 * scale, .h = 64 * scale }, true);
            for (self.preview.nodes[0..self.preview.len], 0..) |node, index| {
                const f = self.preview.presentationRect(node.id).?;
                const bounds = ui.geometry.Rect{ .x = origin.x + f.x * scale, .y = origin.y + f.y * scale, .w = f.w * scale, .h = f.h * scale };
                r.rect(bounds, true);
                if (node.kind == .clip or node.kind == .scroll) {
                    r.rect(.{ .x = bounds.x + 1, .y = bounds.y + 1, .w = @max(0, bounds.w - 2), .h = @max(0, bounds.h - 2) }, true);
                }
                if (self.preview.focused_id != null and self.preview.focused_id.? == node.id) {
                    r.rect(.{ .x = bounds.x - 2, .y = bounds.y - 2, .w = bounds.w + 4, .h = bounds.h + 4 }, true);
                }
                if (self.selected_id != null and self.selected_id.? == node.id) r.rect(.{ .x = bounds.x - 1, .y = bounds.y - 1, .w = bounds.w + 2, .h = bounds.h + 2 }, true);
                if (self.selected_id != null and self.selected_id.? == node.id) {
                    const clip = self.clipFor(index);
                    r.rect(.{ .x = origin.x + clip.x * scale, .y = origin.y + clip.y * scale, .w = clip.w * scale, .h = clip.h * scale }, true);
                }
                var id_bytes: [8]u8 = undefined;
                const id_text = std.fmt.bufPrint(&id_bytes, "{d}", .{node.id}) catch unreachable;
                ui.font.draw(&r, .tiny5x7, bounds.x, bounds.y, id_text, true);
            }
        }
    }
    fn paint(self: *Studio) void {
        self.compose();
        mimoc_window_redraw();
    }
    pub fn pbmSnapshot(self: *Studio, output: []u8) error{InvalidSize}!void {
        if (output.len != pbm_header.len + self.canvas.len) return error.InvalidSize;
        self.compose();
        @memcpy(output[0..pbm_header.len], pbm_header);
        @memset(output[pbm_header.len..], 0);
        var surface = ui.surface.Mono1.init(&self.canvas, studio_width, studio_height) catch unreachable;
        for (0..@as(usize, studio_height)) |y| for (0..@as(usize, studio_width)) |x| {
            if (surface.get(@intCast(x), @intCast(y))) {
                const index = pbm_header.len + y * (@as(usize, studio_width) / 8) + x / 8;
                output[index] |= @as(u8, 0x80) >> @as(u3, @intCast(x % 8));
            }
        };
    }
    fn restart(self: *Studio) void {
        self.preview = .{ .viewport = preview_viewport };
        self.showcase_state = .{};
        self.mobus_state = .{};
        self.preview.update(0);
        self.preview_status = "READY";
        self.rebuildPreview();
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
        self.showcase_state.transition.update(self.clock_ms);
        self.mobus_state.transition.update(self.clock_ms);
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
            107 => self.preview_scale = switch (self.preview_scale) {
                1 => 2,
                2 => 4,
                else => 1,
            },
            108 => {
                self.demo_mode = switch (self.demo_mode) {
                    .classic => .widgets,
                    .widgets => .navigation,
                    .navigation => .mobus,
                    .mobus => .classic,
                };
                self.restart();
                return;
            },
            110 => self.inspect_details = !self.inspect_details,
            else => return,
        }
        self.paint();
    }
    fn input(self: *Studio, action: ui.input.Action) void {
        self.preview.update(self.clock_ms);
        if (self.demo_mode == .classic) {
            if (action == .activate) {
                self.preview_status = switch (demo.activated(&self.preview) orelse .root) {
                    .chat => "CHAT OPEN",
                    .cq => "CQ OPEN",
                    .ehagaki => "EHAGAKI OPEN",
                    else => "READY",
                };
            } else _ = self.preview.action(action);
            self.rebuildPreview();
        } else if (self.demo_mode == .mobus) {
            mobus.handle(&self.preview, &self.mobus_state, action, self.clock_ms);
            self.rebuildPreview();
        } else {
            showcase.handle(&self.preview, &self.showcase_state, self.demo_mode, action, self.clock_ms);
            self.rebuildPreview();
        }
        self.last_action = switch (action) {
            .up => "UP",
            .down => "DOWN",
            .left => "LEFT",
            .right => "RIGHT",
            .activate => "ACT",
            .back => "BACK",
        };
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
        self.showcase_state.transition.update(self.clock_ms);
        self.mobus_state.transition.update(self.clock_ms);
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
            14 => studio.clickControl(108),
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
            if (Studio.controlId(node.id)) |control| studio.clickControl(control);
            return;
        }
    }
    const origin = studio.previewOrigin();
    const scale: c_int = studio.preview_scale;
    if (x < origin.x or y < origin.y or x >= @as(c_int, origin.x) + 128 * scale or y >= @as(c_int, origin.y) + 64 * scale) return;
    const px = @divTrunc(x - origin.x, scale);
    const py = @divTrunc(y - origin.y, scale);
    var i: usize = studio.preview.len;
    while (i > 0) {
        i -= 1;
        const node = studio.preview.nodes[i];
        if (studio.preview.presentationRect(node.id).?.contains(@intCast(px), @intCast(py))) {
            studio.selected_id = node.id;
            if (node.kind == .button or node.kind == .checkbox or node.kind == .toggle or node.kind == .list_item or node.kind == .tuner or node.kind == .knob) {
                studio.preview.focused_id = node.id;
                studio.rebuildPreview();
            }
            studio.paint();
            return;
        }
    }
}
pub fn main() void {
    studio.preview.update(0);
    studio.rebuildPreview();
    studio.paint();
    studio.last_real_ms = mimoc_now_ms();
    mimoc_window_run(&studio.canvas, studio_width, studio_height, appkit_scale, "Mimoc UI Studio");
}

test "Studio changes actual update cadence and manual steps" {
    try std.testing.expectEqual(@as(usize, 3096), @sizeOf(StudioUi));
    try std.testing.expectEqual(@as(usize, 4024), @sizeOf(Preview));
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

test "Studio demo selector builds components and navigation screens" {
    var s = Studio{};
    s.clickControl(108);
    try std.testing.expectEqual(showcase.Mode.widgets, s.demo_mode);
    try std.testing.expect(s.preview.nodeCount() > 10);
    s.clickControl(108);
    try std.testing.expectEqual(showcase.Mode.navigation, s.demo_mode);
    const View = ui.ui.Ui(u16, Preview.configuration);
    try std.testing.expectEqual(@as(?u16, View.childId(View.childId(View.rootId(1), 2), 10)), s.preview.focused_id);
    s.input(.activate);
    try std.testing.expectEqual(showcase.Screen.contacts, s.showcase_state.nav.current());
    s.input(.back);
    try std.testing.expectEqual(showcase.Screen.home, s.showcase_state.nav.current());
    s.clickControl(108);
    try std.testing.expectEqual(showcase.Mode.mobus, s.demo_mode);
    try std.testing.expectEqual(mobus.Screen.home, s.mobus_state.nav.current());
}

test "Studio detail inspector and overlay leave logical preview unchanged" {
    var s = Studio{};
    s.preview.update(0);
    s.rebuildPreview();
    s.selected_id = s.preview.focused_id;
    const selected = s.selected_id.?;
    s.clickControl(110);
    try std.testing.expect(s.inspect_details);
    try std.testing.expect(s.selectedNodeIndex() != null);
    var before: [1024]u8 = undefined;
    try ui.headless.render(&s.preview, &before, 128, 64);
    s.clickControl(106);
    try std.testing.expect(s.overlay);
    try std.testing.expectEqual(selected, s.selected_id.?);
    var after: [1024]u8 = undefined;
    try ui.headless.render(&s.preview, &after, 128, 64);
    try std.testing.expectEqualSlices(u8, &before, &after);
}

test "Studio PBM snapshot keeps panels, controls and preview in separate viewports" {
    var s = Studio{};
    s.preview.update(0);
    s.rebuildPreview();
    try std.testing.expectEqual(studio_viewport, s.chrome.viewport);
    try std.testing.expectEqual(preview_viewport, s.preview.viewport);
    var pbm: [pbm_header.len + @as(usize, studio_width) * (@as(usize, studio_height) / 8)]u8 = undefined;
    try s.pbmSnapshot(&pbm);
    try std.testing.expectEqualSlices(u8, pbm_header, pbm[0..pbm_header.len]);
    try std.testing.expectEqual(@as(u64, 12374510687983544201), std.hash.Wyhash.hash(0, &pbm));

    const bounds = studio_viewport;
    const inspector = ui.geometry.Rect{ .x = 544, .y = 28, .w = 152, .h = 276 };
    for (s.chrome.nodes[0..s.chrome.len]) |node| {
        const rect = s.chrome.presentationRect(node.id).?;
        try std.testing.expectEqual(rect, ui.geometry.Rect.intersect(bounds, rect));
        const View = ui.ui.Ui(u16, StudioUi.configuration);
        const panel_id = View.childId(View.rootId(1), 200);
        for (10..24) |logical| {
            if (node.id == View.childId(panel_id, @intCast(logical))) try std.testing.expectEqual(rect, ui.geometry.Rect.intersect(inspector, rect));
        }
    }
    var surface = try ui.surface.Mono1.init(&s.canvas, studio_width, studio_height);
    try std.testing.expect(surface.get(8, 28));
    try std.testing.expect(surface.get(544, 28));
    try std.testing.expect(surface.get(414, 5));
    try std.testing.expect(surface.get(600, 5));
    try std.testing.expect(surface.get(8, 315));
    var preview_surface = try ui.surface.Mono1.init(&s.preview_pixels, 128, 64);
    const origin = s.previewOrigin();
    for (0..64) |y| for (0..128) |x| {
        const expected = preview_surface.get(@intCast(x), @intCast(y));
        for (0..s.preview_scale) |dy| for (0..s.preview_scale) |dx| {
            try std.testing.expectEqual(expected, surface.get(origin.x + @as(i16, @intCast(x * s.preview_scale + dx)), origin.y + @as(i16, @intCast(y * s.preview_scale + dy))));
        };
    };
    var page: [128]u8 = undefined;
    for (0..8) |index| {
        try ui.headless.renderPage(&s.preview, &page, 128, @intCast(index));
        try std.testing.expectEqualSlices(u8, s.preview_pixels[index * 128 ..][0..128], &page);
    }
}

test "Preview scales 1x, 2x and 4x inside the panel" {
    var s = Studio{};
    s.preview.update(0);
    s.rebuildPreview();
    for ([_]u8{ 1, 2, 4 }) |scale| {
        s.preview_scale = scale;
        s.compose();
        const origin = s.previewOrigin();
        const image = ui.geometry.Rect{ .x = origin.x, .y = origin.y, .w = @as(i16, scale) * 128, .h = @as(i16, scale) * 64 };
        try std.testing.expectEqual(image, ui.geometry.Rect.intersect(preview_area, image));
        var canvas = try ui.surface.Mono1.init(&s.canvas, studio_width, studio_height);
        var preview = try ui.surface.Mono1.init(&s.preview_pixels, 128, 64);
        for (0..64) |y| for (0..128) |x| {
            const on = preview.get(@intCast(x), @intCast(y));
            try std.testing.expectEqual(on, canvas.get(origin.x + @as(i16, @intCast(x)) * scale, origin.y + @as(i16, @intCast(y)) * scale));
        };
    }
}

test "Mo-Bus preview navigates independently inside the Studio PBM surface" {
    var s = Studio{};
    s.demo_mode = .mobus;
    s.preview.update(0);
    s.rebuildPreview();
    try std.testing.expectEqual(preview_viewport, s.preview.viewport);
    try std.testing.expectEqual(studio_viewport, s.chrome.viewport);
    s.input(.activate);
    try std.testing.expectEqual(mobus.Screen.contacts, s.mobus_state.nav.current());
    s.input(.right);
    s.input(.activate);
    try std.testing.expectEqual(mobus.Screen.chat, s.mobus_state.nav.current());
    s.input(.down);
    s.input(.activate);
    try std.testing.expectEqual(mobus.Screen.composer, s.mobus_state.nav.current());
    s.input(.back);
    try std.testing.expectEqual(mobus.Screen.chat, s.mobus_state.nav.current());
    s.input(.back);
    try std.testing.expectEqual(mobus.Screen.contacts, s.mobus_state.nav.current());
    var pbm: [pbm_header.len + @as(usize, studio_width) * (@as(usize, studio_height) / 8)]u8 = undefined;
    try s.pbmSnapshot(&pbm);
    var surface = try ui.surface.Mono1.init(&s.canvas, studio_width, studio_height);
    try std.testing.expect(surface.get(8, 28));
    try std.testing.expect(surface.get(544, 28));
    try std.testing.expect(surface.get(8, 315));
    try std.testing.expect(s.preview.nodeCount() > 4);
    var full: [1024]u8 = undefined;
    const shifted = ui.transition.Shifted(Preview){ .runtime = &s.preview, .offset = s.mobus_state.transition.incoming };
    try ui.headless.render(&shifted, &full, 128, 64);
    for (0..8) |page| {
        var bytes: [128]u8 = undefined;
        try ui.headless.renderPage(&shifted, &bytes, 128, @intCast(page));
        try std.testing.expectEqualSlices(u8, full[page * 128 ..][0..128], &bytes);
    }
}
