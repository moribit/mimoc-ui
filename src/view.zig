const g = @import("geometry.zig");
const Font = @import("font.zig").Font;
const Animation = @import("animation.zig").Animation;

pub const Kind = enum { column, row, stack, text, wrapped_text, rect, filled_rect, spacer, button, divider, icon, bitmap, checkbox, toggle, progress, clip, scroll, list_item, tuner, tuner_indicator, knob, knob_indicator, text_field, pressable };
pub const Align = enum { start, center, end };
pub const Node = struct {
    text: []const u8 = "",
    frame: g.Rect = .{},
    min_size: g.Size = .{},
    offset: g.Point = .{},
    animation: Animation = .{},
    parent: u16 = 0xffff,
    id: u16 = 0,
    subtree_end: u16 = 0,
    kind: Kind,
    font: Font = .tiny5x7,
    padding: u8 = 0,
    spacing: u8 = 0,
    alignment: Align = .start,
    disabled: bool = false,
};

pub fn Builder(comptime capacity: usize) type {
    return BuilderImpl(capacity, false);
}
pub fn InPlaceBuilder(comptime capacity: usize) type {
    return BuilderImpl(capacity, true);
}

fn BuilderImpl(comptime capacity: usize, comptime borrowed: bool) type {
    return struct {
        const Self = @This();
        nodes: if (borrowed) *[capacity]Node else [capacity]Node = undefined,
        len: u16 = 0,
        stack: [capacity]u16 = undefined,
        depth: u16 = 0,

        pub fn init() Self {
            if (borrowed) @compileError("Use initInPlace for borrowed node storage");
            return .{};
        }
        pub fn initInPlace(storage: *[capacity]Node) Self {
            if (!borrowed) @compileError("Use init for owned node storage");
            return .{ .nodes = storage };
        }
        pub fn begin(self: *Self, id: u16, kind: Kind, padding: u8, spacing: u8, alignment: Align) error{CapacityExceeded}!void {
            const index = try self.append(.{ .id = id, .kind = kind, .padding = padding, .spacing = spacing, .alignment = alignment });
            self.stack[self.depth] = index;
            self.depth += 1;
        }
        pub fn end(self: *Self) void {
            if (self.depth == 0) return;
            self.depth -= 1;
            self.nodes[self.stack[self.depth]].subtree_end = self.len;
        }
        pub fn add(self: *Self, node: Node) error{CapacityExceeded}!void {
            _ = try self.append(node);
        }
        fn append(self: *Self, node_: Node) error{CapacityExceeded}!u16 {
            if (self.len >= capacity) return error.CapacityExceeded;
            var node = node_;
            node.parent = if (self.depth == 0) 0xffff else self.stack[self.depth - 1];
            node.subtree_end = self.len + 1;
            const index = self.len;
            self.nodes[index] = node;
            self.len += 1;
            return index;
        }
        pub fn items(self: *const Self) []const Node {
            return self.nodes[0..self.len];
        }
    };
}
