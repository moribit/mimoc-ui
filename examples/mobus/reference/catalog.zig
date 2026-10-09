const std = @import("std");
pub const inventory = @import("inventory.zig");
pub const Screen = enum { menu, contacts, chat, settings, dialog, profile, tra, ehagaki, rooms, composer, wifi, text };
pub const Verification = enum { verified, source_faithful, unverified };
pub const Scenario = struct { verification: Verification = .verified, name: []const u8, screen: Screen, variant: u8, expected: []const u8, now_ms: u32 = 0 };
pub const scenarios = [_]Scenario{
    .{ .name = "menu/default", .screen = .menu, .variant = 0, .expected = @embedFile("golden/menu-default.raw") },
    .{ .name = "menu/selected-settings", .screen = .menu, .variant = 1, .expected = @embedFile("golden/menu-selected-settings.raw") },
    .{ .name = "menu/notification", .screen = .menu, .variant = 2, .expected = @embedFile("golden/menu-notification.raw") },
    .{ .name = "menu/radio-offline", .screen = .menu, .variant = 3, .expected = @embedFile("golden/menu-radio-offline.raw") },
    .{ .name = "contacts/default", .screen = .contacts, .variant = 0, .expected = @embedFile("golden/contacts-default.raw") },
    .{ .name = "contacts/pending", .screen = .contacts, .variant = 1, .expected = @embedFile("golden/contacts-pending.raw") },
    .{ .name = "contacts/unread", .screen = .contacts, .variant = 2, .expected = @embedFile("golden/contacts-unread.raw") },
    .{ .name = "contacts/mode-cq", .screen = .contacts, .variant = 3, .expected = @embedFile("golden/contacts-mode-cq.raw") },
    .{ .name = "contacts/mode-focused", .screen = .contacts, .variant = 4, .expected = @embedFile("golden/contacts-mode-focused.raw") },
    .{ .name = "contacts/loading", .screen = .contacts, .variant = 5, .expected = @embedFile("golden/contacts-loading.raw") },
    .{ .name = "chat/default", .screen = .chat, .variant = 0, .expected = @embedFile("golden/chat-default.raw") },
    .{ .name = "chat/long-message", .screen = .chat, .variant = 1, .expected = @embedFile("golden/chat-long-message.raw") },
    .{ .name = "chat/mine-selected", .screen = .chat, .variant = 2, .expected = @embedFile("golden/chat-mine-selected.raw") },
    .{ .name = "chat/japanese", .screen = .chat, .variant = 3, .expected = @embedFile("golden/chat-japanese.raw") },
    .{ .name = "settings/default", .screen = .settings, .variant = 0, .expected = @embedFile("golden/settings-default.raw") },
    .{ .name = "settings/selected", .screen = .settings, .variant = 1, .expected = @embedFile("golden/settings-selected.raw") },
    .{ .name = "settings/scrolled", .screen = .settings, .variant = 2, .expected = @embedFile("golden/settings-scrolled.raw") },
    .{ .name = "dialog/confirm-no", .screen = .dialog, .variant = 0, .expected = @embedFile("golden/dialog-confirm-no.raw") },
    .{ .name = "dialog/confirm-yes", .screen = .dialog, .variant = 1, .expected = @embedFile("golden/dialog-confirm-yes.raw") },

    .{ .name = "dialog/factory-reset-no", .screen = .dialog, .variant = 2, .expected = @embedFile("golden/dialog-factory-reset-no.raw") },
    .{ .name = "dialog/factory-reset-yes", .screen = .dialog, .variant = 3, .expected = @embedFile("golden/dialog-factory-reset-yes.raw") },
    .{ .name = "profile/default", .screen = .profile, .variant = 0, .expected = @embedFile("golden/profile-default.raw") },
    .{ .name = "profile/scrolled", .screen = .profile, .variant = 1, .expected = @embedFile("golden/profile-scrolled.raw") },
    .{ .name = "tra/default", .screen = .tra, .variant = 0, .expected = @embedFile("golden/tra-default.raw") },
    .{ .name = "tra/selected-synth", .screen = .tra, .variant = 1, .expected = @embedFile("golden/tra-selected-synth.raw") },
    .{ .name = "ehagaki/menu-default", .screen = .ehagaki, .variant = 0, .expected = @embedFile("golden/ehagaki-menu-default.raw") },
    .{ .name = "ehagaki/menu-timeline", .screen = .ehagaki, .variant = 1, .expected = @embedFile("golden/ehagaki-menu-timeline.raw") },
    .{ .name = "rooms/default", .screen = .rooms, .variant = 0, .expected = @embedFile("golden/rooms-default.raw") },
    .{ .name = "rooms/selected", .screen = .rooms, .variant = 1, .expected = @embedFile("golden/rooms-selected.raw") },
    .{ .name = "composer/default", .screen = .composer, .variant = 0, .expected = @embedFile("golden/composer-default.raw") },
    .{ .name = "composer/playing", .screen = .composer, .variant = 1, .expected = @embedFile("golden/composer-playing.raw") },

    .{ .name = "wifi/scanning", .screen = .wifi, .variant = 0, .expected = @embedFile("golden/wifi-scanning.raw") },
    .{ .name = "wifi/connecting", .screen = .wifi, .variant = 1, .expected = @embedFile("golden/wifi-connecting.raw") },
    .{ .name = "wifi/error", .screen = .wifi, .variant = 2, .expected = @embedFile("golden/wifi-error.raw") },
    .{ .name = "wifi/list", .screen = .wifi, .variant = 3, .expected = @embedFile("golden/wifi-list.raw") },
    .{ .name = "wifi/selected", .screen = .wifi, .variant = 4, .expected = @embedFile("golden/wifi-selected.raw") },
    .{ .name = "wifi/scrolled", .screen = .wifi, .variant = 5, .expected = @embedFile("golden/wifi-scrolled.raw") },
    .{ .name = "wifi/password", .screen = .wifi, .variant = 6, .expected = @embedFile("golden/wifi-password.raw") },
    .{ .name = "wifi/password-delete", .screen = .wifi, .variant = 7, .expected = @embedFile("golden/wifi-password-delete.raw") },
    .{ .name = "text/default", .screen = .text, .variant = 0, .expected = @embedFile("golden/text-default.raw") },
    .{ .name = "text/two-lines", .screen = .text, .variant = 1, .expected = @embedFile("golden/text-two-lines.raw") },
    .{ .name = "text/offline", .verification = .source_faithful, .screen = .text, .variant = 2, .expected = "" },
    .{ .name = "text/error", .verification = .source_faithful, .screen = .text, .variant = 3, .expected = "" },
    .{ .name = "text/blank", .screen = .text, .variant = 4, .expected = @embedFile("golden/text-blank.raw") },
};
pub fn find(name: []const u8) ?Scenario {
    for (scenarios) |s| if (std.mem.eql(u8, name, s.name)) return s;
    return null;
}
