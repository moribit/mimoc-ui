const builtin = @import("builtin");
const std = @import("std");
const geometry = @import("geometry.zig");
const view = @import("view.zig");
const runtime = @import("runtime.zig");
const widgets = @import("widgets.zig");
const scroll = @import("scroll.zig");
const font = @import("font.zig");
const animation = @import("animation.zig");
const theme = @import("theme.zig");

pub const Failure = enum(u8) {
    node_capacity,
    animation_capacity,
    identity_collision,
    duplicate_id,
    unclosed_scope,
    double_end,
    invalid_hierarchy,
    invalid_widget,
    invalid_scroll_range,
};
pub const Diagnostic = struct {
    failure: Failure,
    used: u16,
    capacity: u16,
    id: u16,
    widget: []const u8,
    screen: []const u8,
};
pub const Options = struct {
    padding: u8 = 0,
    spacing: u8 = 0,
    alignment: view.Align = .start,
    size: geometry.Size = .{},
    offset: geometry.Point = .{},
    animation: animation.Animation = .{},
};
pub const ToggleOptions = struct { width: i16 = 86, animation: animation.Animation = .{} };
pub const ProgressOptions = struct { width: i16 = 86, animation: animation.Animation = .{} };

/// A short, deterministic identity derived from parent scope, logical ID and part role.
/// The builder checks every generated ID for collisions before appending a Node.
pub fn derive(parent: u16, local: u16, role: u16) u16 {
    var hash: u32 = 2166136261;
    inline for (.{ parent, local, role }) |word| {
        hash = (hash ^ @as(u8, @truncate(word))) *% 16777619;
        hash = (hash ^ @as(u8, @truncate(word >> 8))) *% 16777619;
    }
    return @truncate(hash ^ (hash >> 16));
}

pub fn Ui(comptime Id: type, comptime config: anytype) type {
    const capacity: usize = if (@TypeOf(config) == comptime_int) config else config.max_nodes;
    const diagnostics_enabled: bool = if (@TypeOf(config) == comptime_int) builtin.mode != .ReleaseSmall else if (@hasField(@TypeOf(config), "diagnostics")) config.diagnostics else builtin.mode != .ReleaseSmall;
    if (capacity == 0) @compileError("Ui requires at least one node");
    if (Id != u16) {
        if (@typeInfo(Id) != .@"enum" or @typeInfo(Id).@"enum".tag_type != u16) @compileError("Ui ID must be enum(u16) or u16");
    }
    return struct {
        const Self = @This();
        pub const Runtime = runtime.Runtime(config);
        pub const Error = error{ NodeCapacityExceeded, AnimationCapacityExceeded, IdentityCollision, DuplicateId, UnclosedScope, DoubleEnd, InvalidHierarchy, InvalidWidget, InvalidScrollRange };
        pub const root_scope: u16 = 0x6d6f;

        runtime: *Runtime,
        builder: view.InPlaceBuilder(capacity),
        scope_key: u16 = root_scope,
        open_scopes: u16 = 0,
        failure: ?Failure = null,
        details: if (diagnostics_enabled) ?Diagnostic else void = if (diagnostics_enabled) null else {},
        screen_name: if (diagnostics_enabled) []const u8 else void = if (diagnostics_enabled) "" else {},

        pub fn begin(target: *Runtime) Self {
            return .{ .runtime = target, .builder = target.beginView() };
        }
        pub fn screen(self: *Self, name: []const u8) void {
            if (comptime diagnostics_enabled) self.screen_name = name;
        }
        fn raw(logical: Id) u16 {
            return if (Id == u16) logical else @intFromEnum(logical);
        }
        pub fn rootId(logical: Id) u16 {
            return derive(root_scope, raw(logical), 0);
        }
        pub fn childId(parent: u16, logical: Id) u16 {
            return derive(parent, raw(logical), 0);
        }
        pub fn id(self: *const Self, logical: Id) u16 {
            return childId(self.scope_key, logical);
        }
        pub fn diagnostic(self: *const Self) ?Diagnostic {
            if (comptime diagnostics_enabled) return self.details;
            return null;
        }
        fn record(self: *Self, failure: Failure, key: u16, widget: []const u8) void {
            if (self.failure != null) return;
            self.failure = failure;
            if (comptime diagnostics_enabled) self.details = .{
                .failure = failure,
                .used = self.builder.len,
                .capacity = @intCast(capacity),
                .id = key,
                .widget = widget,
                .screen = self.screen_name,
            };
        }
        fn collision(self: *Self, key: u16, widget: []const u8) bool {
            if (self.failure != null) return true;
            for (self.builder.items()) |node| if (node.id == key) {
                self.record(.identity_collision, key, widget);
                return true;
            };
            return false;
        }
        fn add(self: *Self, node: view.Node, widget: []const u8) void {
            if (self.collision(node.id, widget)) return;
            self.builder.add(node) catch self.record(.node_capacity, node.id, widget);
        }
        fn beginNode(self: *Self, key: u16, kind: view.Kind, options: Options, widget: []const u8) bool {
            if (self.collision(key, widget)) return false;
            self.builder.begin(key, kind, options.padding, options.spacing, options.alignment) catch {
                self.record(.node_capacity, key, widget);
                return false;
            };
            var node = &self.builder.nodes[self.builder.len - 1];
            node.min_size = options.size;
            node.offset = options.offset;
            node.animation = options.animation;
            return true;
        }
        pub const Scope = struct {
            ui: *Self,
            key: u16,
            previous: u16,
            close_count: u8,
            active: bool = true,

            pub fn id(self: *const Scope, logical: Id) u16 {
                return childId(self.key, logical);
            }
            pub fn end(self: *Scope) void {
                if (!self.active) {
                    self.ui.record(.double_end, self.key, "scope");
                    return;
                }
                self.active = false;
                if (self.ui.scope_key != self.key or self.ui.open_scopes == 0) {
                    self.ui.record(.invalid_hierarchy, self.key, "scope");
                    return;
                }
                for (0..self.close_count) |_| self.ui.builder.end();
                self.ui.scope_key = self.previous;
                self.ui.open_scopes -= 1;
            }
        };
        fn entered(self: *Self, key: u16, previous: u16, close_count: u8) Scope {
            self.scope_key = key;
            self.open_scopes += 1;
            return .{ .ui = self, .key = key, .previous = previous, .close_count = close_count };
        }
        pub fn scope(self: *Self, logical: Id) Scope {
            const previous = self.scope_key;
            return self.entered(self.id(logical), previous, 0);
        }
        fn container(self: *Self, logical: Id, kind: view.Kind, options: Options) Scope {
            const previous = self.scope_key;
            const key = self.id(logical);
            const opened = self.beginNode(key, kind, options, @tagName(kind));
            return self.entered(key, previous, @intFromBool(opened));
        }
        pub fn column(self: *Self, logical: Id, options: Options) Scope {
            return self.container(logical, .column, options);
        }
        pub fn row(self: *Self, logical: Id, options: Options) Scope {
            return self.container(logical, .row, options);
        }
        pub fn stack(self: *Self, logical: Id, options: Options) Scope {
            return self.container(logical, .stack, options);
        }
        pub fn clip(self: *Self, logical: Id, options: Options) Scope {
            return self.container(logical, .clip, options);
        }
        pub fn scrollView(self: *Self, logical: Id, options: Options) Scope {
            return self.container(logical, .scroll, options);
        }
        pub fn list(self: *Self, logical: Id, size: geometry.Size, offset: i16, motion: animation.Animation) Scope {
            return self.listAt(logical, size, offset, motion, .{});
        }
        pub fn listAt(self: *Self, logical: Id, size: geometry.Size, offset: i16, motion: animation.Animation, position: geometry.Point) Scope {
            const previous = self.scope_key;
            const key = self.id(logical);
            if (offset < 0 or size.w < 0 or size.h < 0) self.record(.invalid_scroll_range, key, "List");
            const root_open = self.beginNode(key, .scroll, .{ .size = size, .offset = position }, "List");
            const content_open = if (root_open) self.beginNode(derive(key, 1, 1), .column, .{ .offset = .{ .y = -offset }, .animation = motion }, "ListContent") else false;
            return self.entered(key, previous, @as(u8, @intFromBool(root_open)) + @as(u8, @intFromBool(content_open)));
        }
        pub fn panel(self: *Self, logical: Id, title: ?[]const u8, size: geometry.Size, style: theme.WidgetStyle) Scope {
            return self.panelAt(logical, title, size, style, .{});
        }
        pub fn panelAt(self: *Self, logical: Id, title: ?[]const u8, size: geometry.Size, style: theme.WidgetStyle, offset: geometry.Point) Scope {
            const previous = self.scope_key;
            const key = self.id(logical);
            const root_open = self.beginNode(key, .stack, .{ .size = size, .offset = offset }, "Panel");
            self.add(.{ .id = derive(key, 1, 1), .kind = if (style.border) .rect else .spacer, .min_size = size }, "PanelBorder");
            const content_open = if (root_open) self.beginNode(derive(key, 2, 1), .column, .{ .padding = style.padding, .spacing = style.spacing }, "PanelContent") else false;
            if (title) |heading| {
                self.add(.{ .id = derive(key, 3, 1), .kind = .text, .text = heading }, "PanelTitle");
                self.add(.{ .id = derive(key, 4, 1), .kind = .divider, .min_size = .{ .w = @max(0, size.w - 2 * @as(i16, style.padding)), .h = 1 } }, "PanelDivider");
            }
            return self.entered(key, previous, @as(u8, @intFromBool(root_open)) + @as(u8, @intFromBool(content_open)));
        }
        pub fn text(self: *Self, logical: Id, value: []const u8) void {
            self.textWith(logical, value, .{});
        }
        pub fn textWith(self: *Self, logical: Id, value: []const u8, options: Options) void {
            self.add(.{ .id = self.id(logical), .kind = .text, .text = value, .min_size = options.size, .offset = options.offset, .animation = options.animation }, "Text");
        }
        pub fn wrappedText(self: *Self, logical: Id, value: []const u8, width: i16) void {
            self.wrappedTextAt(logical, value, width, .{});
        }
        pub fn wrappedTextAt(self: *Self, logical: Id, value: []const u8, width: i16, position: geometry.Point) void {
            self.add(.{ .id = self.id(logical), .kind = .wrapped_text, .text = value, .min_size = .{ .w = width }, .offset = position, .spacing = 8 }, "WrappedText");
        }
        pub fn rect(self: *Self, logical: Id, size: geometry.Size) void {
            self.add(.{ .id = self.id(logical), .kind = .rect, .min_size = size }, "Rect");
        }
        pub fn filledRect(self: *Self, logical: Id, size: geometry.Size, offset: geometry.Point, motion: animation.Animation) void {
            self.add(.{ .id = self.id(logical), .kind = .filled_rect, .min_size = size, .offset = offset, .animation = motion }, "FilledRect");
        }
        /// Typed escape hatch for uncommon primitives; the low-level Builder remains available.
        pub fn primitive(self: *Self, logical: Id, kind: view.Kind, value: []const u8, options: Options) void {
            self.add(.{ .id = self.id(logical), .kind = kind, .text = value, .min_size = options.size, .offset = options.offset, .animation = options.animation, .padding = options.padding, .spacing = options.spacing, .alignment = options.alignment }, @tagName(kind));
        }
        pub fn divider(self: *Self, logical: Id, width: i16) void {
            self.add(.{ .id = self.id(logical), .kind = .divider, .min_size = .{ .w = width, .h = 1 } }, "Divider");
        }
        pub fn button(self: *Self, logical: Id, label: []const u8) void {
            self.buttonWith(logical, label, .{});
        }
        pub fn buttonWith(self: *Self, logical: Id, label: []const u8, options: Options) void {
            self.add(.{ .id = self.id(logical), .kind = .button, .text = label, .min_size = options.size, .offset = options.offset, .animation = options.animation }, "Button");
        }
        pub fn checkbox(self: *Self, logical: Id, label: []const u8, checked: bool) void {
            self.add(.{ .id = self.id(logical), .kind = .checkbox, .text = label, .padding = @intFromBool(checked) }, "Checkbox");
        }
        pub fn icon(self: *Self, logical: Id, image: widgets.Icon) void {
            self.add(.{ .id = self.id(logical), .kind = .icon, .text = image.data, .min_size = .{ .w = image.width, .h = image.height } }, "Icon");
        }
        pub fn bitmap(self: *Self, logical: Id, image: widgets.Bitmap) void {
            self.bitmapAt(logical, image, .{});
        }
        pub fn bitmapAt(self: *Self, logical: Id, image: widgets.Bitmap, position: geometry.Point) void {
            const stride: usize = if (image.format == .row_msb) (@as(usize, image.width) + 7) / 8 else image.width;
            const rows: usize = if (image.format == .row_msb) image.height else (@as(usize, image.height) + 7) / 8;
            const key = self.id(logical);
            if (image.stride < stride or image.data.len < @as(usize, image.stride) * rows) {
                self.record(.invalid_widget, key, "Bitmap");
                return;
            }
            self.add(.{ .id = key, .kind = .bitmap, .text = image.data, .min_size = .{ .w = image.width, .h = image.height }, .offset = position, .padding = image.stride, .spacing = @intFromEnum(image.format) }, "Bitmap");
        }
        pub fn listItem(self: *Self, logical: Id, label: []const u8, width: i16, trailing: bool) void {
            self.add(.{ .id = self.id(logical), .kind = .list_item, .text = label, .min_size = .{ .w = width, .h = 10 }, .padding = @intFromBool(trailing) }, "ListItem");
        }
        pub fn toggle(self: *Self, logical: Id, label: []const u8, on: bool) void {
            self.toggleWith(logical, label, on, .{});
        }
        pub fn toggleWith(self: *Self, logical: Id, label: []const u8, on: bool, options: ToggleOptions) void {
            const key = self.id(logical);
            const width = @max(options.width, font.measure(.tiny5x7, label) + 36);
            const opened = self.beginNode(derive(key, 1, 1), .stack, .{}, "ToggleRoot");
            self.add(.{ .id = key, .kind = .toggle, .text = label, .min_size = .{ .w = width, .h = 12 } }, "Toggle");
            self.add(.{ .id = derive(key, 2, 1), .kind = .filled_rect, .min_size = .{ .w = 5, .h = 6 }, .offset = .{ .x = width - (if (on) @as(i16, 8) else @as(i16, 22)), .y = 3 }, .animation = options.animation }, "ToggleKnob");
            if (opened) self.builder.end();
        }
        pub fn progress(self: *Self, logical: Id, current: u16, maximum: u16) void {
            self.progressWith(logical, current, maximum, .{});
        }
        pub fn progressWith(self: *Self, logical: Id, current: u16, maximum: u16, options: ProgressOptions) void {
            const key = self.id(logical);
            const width = @max(options.width, 4);
            const interior: i16 = width - 2;
            const fill: i16 = if (maximum == 0) 0 else @intCast(@as(u32, @intCast(interior)) * @as(u32, @min(current, maximum)) / maximum);
            const opened = self.beginNode(derive(key, 1, 1), .stack, .{}, "ProgressRoot");
            self.add(.{ .id = key, .kind = .progress, .min_size = .{ .w = width, .h = 8 } }, "Progress");
            self.add(.{ .id = derive(key, 2, 1), .kind = .filled_rect, .min_size = .{ .w = fill, .h = 6 }, .offset = .{ .x = 1, .y = 1 }, .animation = options.animation }, "ProgressFill");
            if (opened) self.builder.end();
        }
        pub fn tuner(self: *Self, logical: Id, options: widgets.Tuner) void {
            self.tunerAt(logical, options, .{});
        }
        pub fn tunerAt(self: *Self, logical: Id, options: widgets.Tuner, position: geometry.Point) void {
            const key = self.id(logical);
            if (options.markers.len == 0 or options.markers.len > 255 or options.width < 2) {
                self.record(.invalid_widget, key, "Tuner");
                return;
            }
            const opened = self.beginNode(derive(key, 1, 1), .stack, .{ .offset = position }, "TunerRoot");
            self.add(.{ .id = key, .kind = .tuner, .text = @as([*]const u8, @ptrCast(options.markers.ptr))[0..options.markers.len], .min_size = .{ .w = options.width, .h = 14 } }, "Tuner");
            self.add(.{ .id = derive(key, 2, 1), .kind = .tuner_indicator, .min_size = .{ .w = 1, .h = 1 }, .offset = .{ .x = widgets.tunerTick(options.width, options.markers.len, @min(options.selected, @as(u8, @intCast(options.markers.len - 1)))), .y = 8 }, .animation = options.animation }, "TunerIndicator");
            if (opened) self.builder.end();
        }
        pub fn knob(self: *Self, logical: Id, options: widgets.Knob) void {
            self.knobAt(logical, options, .{});
        }
        pub fn knobAt(self: *Self, logical: Id, options: widgets.Knob, position: geometry.Point) void {
            const key = self.id(logical);
            const opened = self.beginNode(derive(key, 1, 1), .stack, .{ .offset = position }, "KnobRoot");
            self.add(.{ .id = key, .kind = .knob, .min_size = .{ .w = 22, .h = 22 } }, "Knob");
            self.add(.{ .id = derive(key, 2, 1), .kind = .knob_indicator, .min_size = .{ .w = 1, .h = 1 }, .offset = widgets.knobPoint(options.steps, options.value), .animation = options.animation }, "KnobIndicator");
            if (opened) self.builder.end();
        }
        pub fn scrollbar(self: *Self, logical: Id, viewport_height: i16, content_height: i32, offset: i32, min_thumb: i16) void {
            self.scrollbarAt(logical, viewport_height, content_height, offset, min_thumb, .{});
        }
        pub fn scrollbarAt(self: *Self, logical: Id, viewport_height: i16, content_height: i32, offset: i32, min_thumb: i16, position: geometry.Point) void {
            if (viewport_height < 0 or content_height < 0 or offset < 0 or min_thumb < 0) {
                self.record(.invalid_scroll_range, self.id(logical), "Scrollbar");
                return;
            }
            const thumb = scroll.scrollbar(viewport_height, content_height, offset, min_thumb);
            if (!thumb.visible) return;
            const key = self.id(logical);
            const opened = self.beginNode(derive(key, 1, 1), .stack, .{ .offset = position }, "ScrollbarRoot");
            self.add(.{ .id = key, .kind = .rect, .min_size = .{ .w = 3, .h = viewport_height } }, "ScrollbarTrack");
            self.add(.{ .id = derive(key, 2, 1), .kind = .filled_rect, .min_size = .{ .w = 3, .h = thumb.height }, .offset = .{ .y = thumb.y } }, "ScrollbarThumb");
            if (opened) self.builder.end();
        }
        pub fn finishChecked(self: *Self) Error!void {
            if (self.failure) |failure| return switch (failure) {
                .node_capacity => error.NodeCapacityExceeded,
                .animation_capacity => error.AnimationCapacityExceeded,
                .identity_collision => error.IdentityCollision,
                .duplicate_id => error.DuplicateId,
                .unclosed_scope => error.UnclosedScope,
                .double_end => error.DoubleEnd,
                .invalid_hierarchy => error.InvalidHierarchy,
                .invalid_widget => error.InvalidWidget,
                .invalid_scroll_range => error.InvalidScrollRange,
            };
            if (self.open_scopes != 0 or self.builder.depth != 0) {
                self.record(.unclosed_scope, self.scope_key, "scope");
                return error.UnclosedScope;
            }
            self.runtime.finishView(&self.builder) catch |err| {
                switch (err) {
                    error.DuplicateId => {
                        self.record(.duplicate_id, 0, "View");
                        return error.DuplicateId;
                    },
                    error.UnclosedContainer => {
                        self.record(.unclosed_scope, 0, "View");
                        return error.UnclosedScope;
                    },
                    error.AnimationCapacityExceeded => {
                        self.record(.animation_capacity, 0, "Animation");
                        return error.AnimationCapacityExceeded;
                    },
                }
            };
        }
        pub fn finish(self: *Self) void {
            self.finishChecked() catch {
                if (comptime builtin.mode == .ReleaseSmall) @trap();
                if (comptime diagnostics_enabled) {
                    if (self.details) |detail| std.debug.panic("Mimoc UI {s}: used {d}/{d}, widget {s}, screen {s}, node {d}", .{
                        @tagName(detail.failure), detail.used, detail.capacity, detail.widget, detail.screen, detail.id,
                    });
                }
                @panic("Mimoc UI programming/configuration error; inspect diagnostic() in Debug");
            };
        }
    };
}
