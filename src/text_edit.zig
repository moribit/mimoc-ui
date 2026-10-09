const std = @import("std");
const font = @import("font.zig");
const input = @import("input.zig");
pub const Intent = union(enum) { insert: []const u8, backspace, delete, left, right, home, end, submit, cancel };
pub fn intent(event: input.InputEvent) ?Intent {
    return switch (event) {
        .text => |s| .{ .insert = s },
        .key_down => |k| switch (k) {
            .backspace => .backspace,
            .delete => .delete,
            .left => .left,
            .right => .right,
            .home => .home,
            .end => .end,
            .enter => .submit,
            .escape => .cancel,
            else => null,
        },
        .action => |a| switch (a) {
            .left => .left,
            .right => .right,
            .activate => .submit,
            .back => .cancel,
            else => null,
        },
        else => null,
    };
}
pub fn boundary(text: []const u8, requested: usize) usize {
    var i: usize = 0;
    while (i < text.len) {
        const next = i + font.codepointBytes(text, i);
        if (next > requested) break;
        i = next;
    }
    return i;
}
pub fn previous(text: []const u8, cursor: usize) usize {
    if (cursor == 0) return 0;
    return boundary(text, cursor - 1);
}
/// All memory and cursor state belong to the application. Errors leave state unchanged.
pub fn apply(buffer: []u8, len: *usize, cursor: *usize, edit: Intent) error{ InvalidUtf8, CapacityExceeded, InvalidLength }!void {
    if (len.* > buffer.len) return error.InvalidLength;
    const text = buffer[0..len.*];
    const at = boundary(text, cursor.*);
    switch (edit) {
        .insert => |value| {
            if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidUtf8;
            if (value.len > buffer.len - len.*) return error.CapacityExceeded;
            std.mem.copyBackwards(u8, buffer[at + value.len .. len.* + value.len], buffer[at..len.*]);
            @memcpy(buffer[at..][0..value.len], value);
            len.* += value.len;
            cursor.* = at + value.len;
        },
        .backspace, .delete => {
            const start = if (edit == .backspace) previous(text, at) else at;
            const end = if (edit == .backspace) at else if (at < len.*) at + font.codepointBytes(text, at) else at;
            std.mem.copyForwards(u8, buffer[start .. len.* - (end - start)], buffer[end..len.*]);
            len.* -= end - start;
            cursor.* = start;
        },
        .left => cursor.* = previous(text, at),
        .right => cursor.* = if (at < len.*) at + font.codepointBytes(text, at) else at,
        .home => cursor.* = 0,
        .end => cursor.* = len.*,
        .submit, .cancel => cursor.* = at,
    }
}
pub const Field = struct {
    text: []const u8 = "",
    placeholder: []const u8 = "",
    cursor: usize = 0,
    password: bool = false,
    disabled: bool = false,
};
