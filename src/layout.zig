const g = @import("geometry.zig");
const v = @import("view.zig");
const font = @import("font.zig");

fn add(a: i16, b: i16) i16 {
    return @intCast(@min(32767, @as(i32, a) + b));
}
fn childNext(nodes: []const v.Node, index: usize) usize {
    return nodes[index].subtree_end;
}

pub fn measure(nodes: []const v.Node, index: usize) g.Size {
    const node = nodes[index];
    switch (node.kind) {
        .text => return .{ .w = @max(node.min_size.w, font.measure(node.font, node.text)), .h = @max(node.min_size.h, font.metrics(node.font, 0).height) },
        .button => return .{ .w = @max(node.min_size.w, add(font.measure(node.font, node.text), 12)), .h = @max(node.min_size.h, 12) },
        .rect => return node.min_size,
        .divider => return .{ .w = node.min_size.w, .h = @max(node.min_size.h, 1) },
        .spacer => return node.min_size,
        else => {},
    }
    var w: i16 = 0;
    var h: i16 = 0;
    var count: i16 = 0;
    var i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measure(nodes, i);
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
    nodes[index].frame = frame;
    const node = nodes[index];
    if (node.kind != .column and node.kind != .row and node.kind != .stack) return;
    const p: i16 = node.padding;
    const inner = g.Rect{ .x = add(frame.x, p), .y = add(frame.y, p), .w = @max(0, frame.w - 2 * p), .h = @max(0, frame.h - 2 * p) };
    var fixed: i16 = 0;
    var spacers: i16 = 0;
    var count: i16 = 0;
    var i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measure(nodes, i);
        if (nodes[i].kind == .spacer) spacers += 1 else fixed = add(fixed, if (node.kind == .row) size.w else size.h);
        count += 1;
    }
    const available = if (node.kind == .row) inner.w else inner.h;
    const flexible = if (spacers > 0) @max(0, @divTrunc(available - fixed - @max(0, count - 1) * @as(i16, node.spacing), spacers)) else 0;
    var cursor: i16 = if (node.kind == .row) inner.x else inner.y;
    i = index + 1;
    while (i < node.subtree_end) : (i = childNext(nodes, i)) {
        const size = measure(nodes, i);
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
        place(nodes, i, child);
    }
}
fn aligned(start: i16, extent: i16, child: i16, alignment: v.Align) i16 {
    return add(start, switch (alignment) {
        .start => 0,
        .center => @divTrunc(extent - child, 2),
        .end => extent - child,
    });
}
