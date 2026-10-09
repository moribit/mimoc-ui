pub const Action = enum { up, down, left, right, activate, back };
pub const Key = enum { enter, escape, tab, backspace, delete, space, up, down, left, right, home, end, unknown };
pub const Point = @import("geometry.zig").Point;
pub const ScrollDelta = struct { point: Point = .{}, x: i16 = 0, y: i16 = 0 };
/// Text is borrowed for the duration of dispatch; copy into application storage before returning.
pub const InputEvent = union(enum) {
    action: Action,
    text: []const u8,
    key_down: Key,
    key_up: Key,
    pointer_down: Point,
    pointer_up: Point,
    pointer_move: Point,
    scroll: ScrollDelta,
};
pub const Interaction = enum { input, pressed, released, activate, focus, blur };
pub const Result = struct { previous_focus: ?u16 = null, activated: bool = false, target: ?u16 = null, interaction: Interaction = .input, event: InputEvent };
