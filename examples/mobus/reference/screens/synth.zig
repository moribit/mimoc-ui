//! Direct geometry port of pinned render_synth_sequencer; no audio/state ownership.
const std = @import("std");
const c = @import("common.zig");
const R = c.R;
const F = c.F;
fn t(r: *R, x: i16, y: i16, str: []const u8, fg: bool, bg: bool) void {
    c.text(r, .custom7, x, y, str, true, false, fg, bg);
}
fn arrows(r: *R, x: i16, top: i16, bottom: i16) void {
    r.pixel(x, top, true);
    r.hline(x - 1, top + 1, 3, true);
    r.hline(x - 2, top + 2, 5, true);
    r.hline(x - 2, bottom, 5, true);
    r.hline(x - 1, bottom + 1, 3, true);
    r.pixel(x, bottom + 2, true);
}
pub fn render(r: *R, f: F) void {
    if (f.playing) c.rect(r, 3, 2, 7, 7, true, true) else {
        r.vline(3, 2, 7, true);
        c.raster.line(r, 4, 3, 8, 5, true);
        c.raster.line(r, 4, 8, 8, 6, true);
        r.pixel(9, 5, true);
        r.pixel(9, 6, true);
    }
    var b: [32]u8 = undefined;
    t(r, 25, 2, std.fmt.bufPrint(&b, "{d}", .{f.tempo}) catch unreachable, true, false);
    t(r, 51, 2, std.fmt.bufPrint(&b, "{d}/{d}", .{ f.page + 1, f.pages }) catch unreachable, true, false);
    const preset = [_]u8{@intCast('A' + @mod(f.preset, 4))};
    if (f.note >= 0) {
        const names = [_][]const u8{ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
        t(r, 75, 2, std.fmt.bufPrint(&b, "{s}:{s}{d}", .{ &preset, names[@intCast(@mod(f.note, 12))], @divTrunc(f.note, 12) - 1 }) catch unreachable, true, false);
    } else t(r, 75, 2, &preset, true, false);
    if (f.header >= 0 and f.header < 3) {
        const x = [_]i16{ 12, 39, 64 };
        const w = [_]i16{ 26, 24, 23 };
        c.rect(r, x[@intCast(f.header)], 0, w[@intCast(f.header)], 10, true, false);
    }
    for ([_]i16{ 92, 112 }, 0..) |x, i| {
        if (f.header == @as(i16, @intCast(i)) + 3) c.rect(r, x - 1, 0, 15, 10, true, false);
        r.hline(x + 2, 8, 10, true);
        r.vline(x + 2, 6, 3, true);
        r.vline(x + 11, 6, 3, true);
        r.vline(x + 6, 2, 6, true);
        const tip: i16 = if (i == 1) 2 else 7;
        const d: i16 = if (i == 1) 2 else -2;
        c.raster.line(r, x + 4, tip + d, x + 6, tip, true);
        c.raster.line(r, x + 8, tip + d, x + 6, tip, true);
    }
    r.hline(0, 11, 128, true);
    const labels = "KSHBLE";
    for (0..6) |track| {
        const tr: i16 = @intCast(track);
        const y: i16 = 16 + tr * 8;
        const sel = tr == f.track and f.step == -1 and f.header < 0;
        if (sel) c.rect(r, 0, y - 1, 11, 8, true, true);
        t(r, 5, y - 1, labels[track .. track + 1], !sel, sel);
        if (@as(u16, @intCast(f.enabled)) & (@as(u16, 1) << @as(u4, @intCast(track))) == 0) r.hline(0, y + 3, 10, true);
        for (0..16) |step| {
            const st: i16 = @intCast(step);
            const x = 14 + st * 7;
            const active = f.masks[track] & (@as(u16, 1) << @as(u4, @intCast(step))) != 0;
            const accent = f.accents[track] & (@as(u16, 1) << @as(u4, @intCast(step))) != 0;
            if (active and accent) {
                c.rect(r, x, y, 6, 6, true, false);
                c.rect(r, x + 2, y + 2, 2, 2, true, true);
            } else c.rect(r, x + 1, y + 1, 4, 4, true, active);
            if (tr == f.track and st == f.step) c.rect(r, x, y, 7, 7, true, false);
            if (st == f.playhead) r.vline(x + 3, y, 7, true);
            if ((step + 1) % 4 == 0 and step != 15) {
                var yy = y;
                while (yy < y + 7) : (yy += 2) r.pixel(x + 6, yy, true);
            }
        }
    }
    if (f.dialog == 0) return;
    const page = f.dialog == 5;
    const clear = f.dialog == 6;
    const bpm = f.dialog == 7;
    const sound = f.dialog == 8;
    const confirm = f.dialog == 3 or f.dialog == 4 or clear;
    const save = f.dialog == 2 or f.dialog == 4;
    c.rect(r, if (page) 3 else 14, if (page) 12 else 15, if (page) 122 else 100, if (page) 47 else 40, false, true);
    c.rect(r, if (page) 3 else 14, if (page) 12 else 15, if (page) 122 else 100, if (page) 47 else 40, true, false);
    t(r, 64, if (page) 16 else 19, if (page or clear) "Page edit" else if (bpm) "BPM" else if (sound) "Sound" else if (save) "Save pattern" else "Load pattern", true, false);
    if (page) {
        for ([_][]const u8{ "Len", "Copy", "Paste", "Clear" }, 0..) |label, i| {
            const a: i16 = @intCast(i);
            const x = 19 + a * 30;
            const sel = a == f.page_item;
            if (sel) c.rect(r, x - 14, 35, 29, 12, true, true);
            t(r, x, 36, if (i == 0) std.fmt.bufPrint(&b, "L:{d}", .{f.pages}) catch unreachable else label, !sel, sel);
            if (i == 0 and sel) arrows(r, x, 29, 49);
        }
    } else if (bpm) {
        t(r, 64, 34, std.fmt.bufPrint(&b, "{d}", .{f.tempo}) catch unreachable, true, false);
        arrows(r, 64, 28, 45);
    } else if (sound) {
        const tracks = [_][]const u8{ "Kick", "Snare", "Hat", "Bass", "Lead", "Beep" };
        if (f.sound_field == 0) c.rect(r, 28, 33, 48, 12, true, true);
        t(r, 52, 34, tracks[@intCast(f.sound_track)], f.sound_field != 0, f.sound_field == 0);
        if (f.sound_field == 1) c.rect(r, 82, 33, 18, 12, true, true);
        t(r, 91, 34, &preset, f.sound_field != 1, f.sound_field == 1);
        arrows(r, if (f.sound_field == 0) 52 else 91, 27, 46);
    } else if (!confirm) {
        for (0..4) |i| {
            const slot: i16 = @intCast(i);
            const x = 31 + slot * 22;
            const sel = slot == f.slot;
            if (sel) c.rect(r, x - 7, 34, 15, 13, true, true);
            const label = [_]u8{@intCast('1' + slot)};
            t(r, x, 36, &label, !sel, sel);
        }
    } else {
        const q = if (clear) std.fmt.bufPrint(&b, "Clear page {d}?", .{f.page + 1}) catch unreachable else std.fmt.bufPrint(&b, "{s} {d}?", .{ if (save) "Save" else "Load", f.slot + 1 }) catch unreachable;
        t(r, 64, 31, q, true, false);
        c.rect(r, if (f.yes) 70 else 35, 43, 24, 10, true, true);
        t(r, 47, 43, "No", f.yes, !f.yes);
        t(r, 82, 43, "Yes", !f.yes, f.yes);
    }
}
