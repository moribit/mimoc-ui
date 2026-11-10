const std = @import("std");
pub const inventory = @import("inventory.zig");
pub const Screen = enum { menu, contacts, chat, settings, dialog, profile, tra, ehagaki, rooms, composer, wifi, text, qsp, qsp_compose, cq, synth, ehagaki_browse, ehagaki_edit, ehagaki_canvas, factory, firmware, profile_product, draw, realtime, open_compose };
pub const Verification = enum { verified, source_faithful, unverified };
pub const Scenario = struct { verification: Verification = .verified, name: []const u8, screen: Screen, variant: u8, expected: []const u8, now_ms: u32 = 0 };
const existing = [_]Scenario{
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
pub const scenarios = existing ++ @import("product_catalog.zig").scenarios ++ [_]Scenario{
    .{ .name = "qsp/offline", .screen = .text, .variant = 2, .verification = .source_faithful, .expected = "" },
    .{ .name = "ehagaki/browse-offline", .screen = .text, .variant = 2, .verification = .source_faithful, .expected = "" },
    .{ .name = "ehagaki/error-offline", .screen = .text, .variant = 2, .verification = .source_faithful, .expected = "" },
};
pub fn find(name: []const u8) ?Scenario {
    for (scenarios) |s| if (std.mem.eql(u8, name, s.name)) return s;
    return null;
}

pub const Feature = enum { menu, contacts, qsp, cq, synth, ehagaki, settings, wifi, open_chat, profile, dialogs, instruments, text, factory, firmware, realtime, draw };
pub fn feature(s: Scenario) Feature {
    if (std.mem.startsWith(u8, s.name, "qsp/")) return .qsp;
    if (std.mem.startsWith(u8, s.name, "ehagaki/")) return .ehagaki;
    return switch (s.screen) {
        .menu => .menu,
        .contacts => .contacts,
        .qsp, .qsp_compose => .qsp,
        .cq => .cq,
        .synth => .synth,
        .ehagaki, .ehagaki_edit, .ehagaki_browse, .ehagaki_canvas => .ehagaki,
        .settings => .settings,
        .wifi => .wifi,
        .chat, .rooms, .open_compose => .open_chat,
        .profile, .profile_product => .profile,
        .dialog => .dialogs,
        .tra, .composer => .instruments,
        .text => .text,
        .factory => .factory,
        .firmware => .firmware,
        .realtime => .realtime,
        .draw => .draw,
    };
}
pub fn surface(s: Scenario) []const u8 {
    if (s.screen == .text and std.mem.startsWith(u8, s.name, "qsp/")) return "delivery";
    if (s.screen == .text and std.mem.startsWith(u8, s.name, "ehagaki/browse")) return "browse";
    if (s.screen == .text and std.mem.startsWith(u8, s.name, "ehagaki/")) return "lifecycle";
    if (s.screen == .qsp and std.mem.eql(u8, @import("product_fixtures.zig").all[s.variant].kind, "status")) return "delivery";
    if (s.screen == .wifi) {
        if (std.mem.indexOf(u8, s.name, "password") != null) return "password";
        if (s.variant < 3) return "connection";
        return "list";
    }

    if (s.screen == .synth) {
        const n = s.name;
        if (std.mem.startsWith(u8, n, "synth/grid-")) return "grid";
        if (std.mem.startsWith(u8, n, "synth/header-")) return "header";
        if (std.mem.startsWith(u8, n, "synth/page-editor")) return "page editor";
        if (std.mem.startsWith(u8, n, "synth/sound-editor")) return "sound editor";
        if (std.mem.indexOf(u8, n, "confirm") != null) return "dialogs";
        if (std.mem.indexOf(u8, n, "slot") != null) return "slots";
        return "bpm editor";
    }
    if (s.screen == .ehagaki_canvas) {
        const n = s.name;
        if (std.mem.indexOf(u8, n, "select-") != null) return "selection";
        if (std.mem.indexOf(u8, n, "text-") != null) return "text placement";
        if (std.mem.indexOf(u8, n, "clear-") != null) return "clear dialog";
        if (std.mem.indexOf(u8, n, "menu") != null or std.mem.indexOf(u8, n, "enabled") != null or std.mem.indexOf(u8, n, "ink") != null or std.mem.indexOf(u8, n, "outline") != null or std.mem.indexOf(u8, n, "filled") != null) return "canvas menus";
        return "canvas";
    }
    if (s.screen == .ehagaki_edit) {
        const kind = @import("product_fixtures.zig").all[s.variant].kind;
        if (std.mem.eql(u8, kind, "eha_text")) return "text editor";
        if (std.mem.eql(u8, kind, "visibility")) return "visibility";
        if (std.mem.eql(u8, kind, "root")) return "root";
        return "lifecycle";
    }
    if (s.screen == .ehagaki) return "root";
    if (s.screen == .ehagaki_browse) return "browse";
    if (s.screen == .qsp) return "history";
    if (s.screen == .qsp_compose) return "composer";
    if (s.screen == .cq) {
        if (std.mem.indexOf(u8, s.name, "active") != null or std.mem.indexOf(u8, s.name, "overlay") != null) return "active";
        if (std.mem.indexOf(u8, s.name, "incoming") != null) return "incoming";
        return "connection";
    }
    return @tagName(s.screen);
}
pub fn sameSurface(a: Scenario, b: Scenario) bool {
    return feature(a) == feature(b) and std.mem.eql(u8, surface(a), surface(b));
}

pub const CoverageSurface = struct { feature: Feature, surface: []const u8 };
pub const required_p0 = [_]CoverageSurface{
    .{ .feature = .menu, .surface = "menu" },            .{ .feature = .contacts, .surface = "contacts" },
    .{ .feature = .qsp, .surface = "history" },          .{ .feature = .qsp, .surface = "composer" },
    .{ .feature = .qsp, .surface = "delivery" },         .{ .feature = .cq, .surface = "connection" },
    .{ .feature = .cq, .surface = "incoming" },          .{ .feature = .cq, .surface = "active" },
    .{ .feature = .synth, .surface = "grid" },           .{ .feature = .synth, .surface = "header" },
    .{ .feature = .synth, .surface = "bpm editor" },     .{ .feature = .synth, .surface = "page editor" },
    .{ .feature = .synth, .surface = "sound editor" },   .{ .feature = .synth, .surface = "slots" },
    .{ .feature = .synth, .surface = "dialogs" },        .{ .feature = .ehagaki, .surface = "root" },
    .{ .feature = .ehagaki, .surface = "browse" },       .{ .feature = .ehagaki, .surface = "text editor" },
    .{ .feature = .ehagaki, .surface = "canvas" },       .{ .feature = .ehagaki, .surface = "canvas menus" },
    .{ .feature = .ehagaki, .surface = "selection" },    .{ .feature = .ehagaki, .surface = "text placement" },
    .{ .feature = .ehagaki, .surface = "clear dialog" }, .{ .feature = .ehagaki, .surface = "visibility" },
    .{ .feature = .ehagaki, .surface = "lifecycle" },    .{ .feature = .settings, .surface = "settings" },
    .{ .feature = .wifi, .surface = "list" },            .{ .feature = .wifi, .surface = "password" },
    .{ .feature = .wifi, .surface = "connection" },
};
pub fn gate() bool {
    for (required_p0) |required| {
        var found = false;
        for (scenarios) |s| {
            if (feature(s) == required.feature and std.mem.eql(u8, surface(s), required.surface) and (s.verification == .verified or s.verification == .source_faithful)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}
