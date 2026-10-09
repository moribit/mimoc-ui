const g = @import("geometry.zig");
const v = @import("view.zig");
const font = @import("font.zig");
const wrap = @import("wrap.zig");

fn add(a: i16, b: i16) i16 {
    return @intCast(@min(32767, @as(i32, a) + b));
}
fn childNext(nodes: []const v.Node, index: usize) usize {
    return nodes[index].subtree_end;
}

pub fn measure(nodes: []const v.Node, index: usize) g.Size {
    return measureWith(null, nodes, index);
}
pub fn measureWith(provider: anytype, nodes: []const v.Node, index: usize) g.Size {
    const node = nodes[index];
    switch (node.kind) {
        .text => return .{ .w = @max(node.min_size.w, font.measureWith(provider, node.font, node.text)), .h = @max(node.min_size.h, if (provider) |p| p.line_height else font.metrics(node.font, 0).height) },
        .wrapped_text => return .{ .w = node.min_size.w, .h = @max(node.min_size.h, wrap.heightWith(provider, node.font, node.text, node.min_size.w, if (provider) |p| p.line_height else if (node.spacing == 0) 8 else node.spacing)) },
        .button, .pressable => return .{ .w = @max(node.min_size.w, add(font.measureWith(provider, node.font, node.text), 12)), .h = @max(node.min_size.h, if (provider) |p| @as(i16, p.line_height) + 4 else 12) },
        .text_field => return node.min_size,
        .checkbox => return .{ .w = @max(node.min_size.w, add(font.measureWith(provider, node.font, node.text), 16)), .h = @max(node.min_size.h, 12) },
        .toggle => return .{ .w = @max(node.min_size.w, add(font.measureWith(provider, node.font, node.text), 36)), .h = @max(node.min_size.h, 12) },
        .progress => return .{ .w = @max(node.min_size.w, 40), .h = @max(node.min_size.h, 8) },
        .icon, .bitmap, .clip, .scroll, .tuner, .tuner_indicator, .knob, .knob_indicator => return node.min_size,
        .rect, .filled_rect => return node.min_size,
        .divider => return .{ .w = node.min_size.w, .h = @max(node.min_size.h, 1) },
        .spacer => return node.min_size,
        else => {},
    }
    var w: i16 = 0;
    var h: i16 = 0;
    var count: i16 = 0;
    var i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measureWith(provider, nodes, i);
        switch (node.kind) {
            .row => {
                w = add(w, size.w);
                h = @max(h, size.h);
            },
            .column => {
                w = @max(w, size.w);
                h = add(h, size.h);
            },
            .stack => {
                w = @max(w, size.w);
                h = @max(h, size.h);
            },
            else => {},
        }
        count += 1;
    }
    if (node.kind == .column) h = add(h, @max(0, count - 1) * @as(i16, node.spacing));
    if (node.kind == .row) w = add(w, @max(0, count - 1) * @as(i16, node.spacing));
    return .{ .w = @max(node.min_size.w, add(w, @as(i16, node.padding) * 2)), .h = @max(node.min_size.h, add(h, @as(i16, node.padding) * 2)) };
}

pub fn place(nodes: []v.Node, index: usize, frame: g.Rect) void {
    placeWith(null, nodes, index, frame);
}
pub fn placeWith(provider: anytype, nodes: []v.Node, index: usize, frame: g.Rect) void {
    nodes[index].frame = frame;
    const node = nodes[index];
    if (node.kind == .clip or node.kind == .scroll) {
        var child_index = index + 1;
        while (child_index < node.subtree_end) : (child_index = childNext(nodes, child_index)) {
            const size = measureWith(provider, nodes, child_index);
            placeWith(provider, nodes, child_index, .{ .x = frame.x, .y = frame.y, .w = size.w, .h = size.h });
        }
        return;
    }
    if (node.kind != .column and node.kind != .row and node.kind != .stack) return;
    const p: i16 = node.padding;
    const inner = g.Rect{ .x = add(frame.x, p), .y = add(frame.y, p), .w = @max(0, frame.w - 2 * p), .h = @max(0, frame.h - 2 * p) };
    var fixed: i16 = 0;
    var spacers: i16 = 0;
    var count: i16 = 0;
    var i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measureWith(provider, nodes, i);
        if (nodes[i].kind == .spacer) spacers += 1 else fixed = add(fixed, if (node.kind == .row) size.w else size.h);
        count += 1;
    }
    const available = if (node.kind == .row) inner.w else inner.h;
    const flexible = if (spacers > 0) @max(0, @divTrunc(available - fixed - @max(0, count - 1) * @as(i16, node.spacing), spacers)) else 0;
    var cursor: i16 = if (node.kind == .row) inner.x else inner.y;
    i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measureWith(provider, nodes, i);
        const is_spacer = nodes[i].kind == .spacer;
        var child = g.Rect{ .x = inner.x, .y = inner.y, .w = size.w, .h = size.h };
        switch (node.kind) {
            .column => {
                child.y = cursor;
                child.h = if (is_spacer) flexible else size.h;
                if (size.w == 0 or is_spacer) child.w = inner.w;
                child.x = aligned(inner.x, inner.w, child.w, node.alignment);
                cursor = add(cursor, add(child.h, node.spacing));
            },
            .row => {
                child.x = cursor;
                child.w = if (is_spacer) flexible else size.w;
                if (size.h == 0 or is_spacer) child.h = inner.h;
                child.y = aligned(inner.y, inner.h, child.h, node.alignment);
                cursor = add(cursor, add(child.w, node.spacing));
            },
            .stack => {
                child.x = aligned(inner.x, inner.w, child.w, node.alignment);
                child.y = aligned(inner.y, inner.h, child.h, node.alignment);
            },
            else => unreachable,
        }
        placeWith(provider, nodes, i, child);
    }
}
fn aligned(start: i16, extent: i16, child: i16, alignment: v.Align) i16 {
    return add(start, switch (alignment) {
        .start => 0,
        .center => @divTrunc(extent - child, 2),
        .end => extent - child,
    });
}
