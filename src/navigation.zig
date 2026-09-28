const input = @import("input.zig");

pub fn Navigation(comptime Screen: type, comptime capacity: usize) type {
    if (capacity == 0 or capacity > 255) @compileError("Navigation capacity must be 1..255");
    return struct {
        const Self = @This();
        pub const Entry = struct {
            screen: Screen,
            focused_id: ?u16 = null,
            scroll_offset: i16 = 0,
        };

        entries: [capacity]Entry = undefined,
        len: u8 = 0,

        pub fn init(root: Screen) Self {
            var self = Self{};
            self.entries[0] = .{ .screen = root };
            self.len = 1;
            return self;
        }
        pub fn current(self: *const Self) Screen {
            return self.entries[self.len - 1].screen;
        }
        pub fn entry(self: *const Self) Entry {
            return self.entries[self.len - 1];
        }
        pub fn depth(self: *const Self) u8 {
            return self.len;
        }
        pub fn remember(self: *Self, focus: ?u16, scroll: i16) void {
            self.entries[self.len - 1].focused_id = focus;
            self.entries[self.len - 1].scroll_offset = scroll;
        }
        pub fn push(self: *Self, screen: Screen) error{StackFull}!void {
            if (self.len == capacity) return error.StackFull;
            self.entries[self.len] = .{ .screen = screen };
            self.len += 1;
        }
        pub fn pop(self: *Self) bool {
            if (self.len <= 1) return false;
            self.len -= 1;
            return true;
        }
        pub fn replace(self: *Self, screen: Screen) void {
            self.entries[self.len - 1] = .{ .screen = screen };
        }
        pub fn reset(self: *Self, screen: Screen) void {
            self.entries[0] = .{ .screen = screen };
            self.len = 1;
        }
        pub fn handleBack(self: *Self, action: input.Action) bool {
            return action == .back and self.pop();
        }
    };
}

test "fixed navigation restores entry focus and scroll" {
    const std = @import("std");
    const Screen = enum(u8) { home, contacts, chat, settings };
    const Nav = Navigation(Screen, 3);
    var nav = Nav.init(.home);
    try std.testing.expectEqual(Screen.home, nav.current());
    try std.testing.expect(!nav.pop());
    nav.remember(10, 0);
    try nav.push(.contacts);
    nav.remember(23, 12);
    try nav.push(.chat);
    try std.testing.expectError(error.StackFull, nav.push(.settings));
    try std.testing.expect(nav.handleBack(.back));
    try std.testing.expectEqual(Screen.contacts, nav.current());
    try std.testing.expectEqual(@as(?u16, 23), nav.entry().focused_id);
    try std.testing.expectEqual(@as(i16, 12), nav.entry().scroll_offset);
    nav.replace(.settings);
    try std.testing.expectEqual(Screen.settings, nav.current());
    try std.testing.expectEqual(@as(?u16, null), nav.entry().focused_id);
    nav.reset(.home);
    try std.testing.expectEqual(@as(u8, 1), nav.depth());
}
