#!/usr/bin/env python3
"""Read-only, pinned Mo-Bus/LovyanGFX oracle and reproducible font converter.

Generated screen buffers come from the C++ renderer, never from mimoc-ui.
The host shim substitutes NVS language, clock and display transport only.
"""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
import subprocess
import tarfile
import tempfile
from mobus_product_fixtures import cpp_capture, SCENARIOS, write_zig

COMMIT = "4b6705f62160e1849cd161f9515d507df90d23d2"
ROOT = Path(__file__).resolve().parents[1]


def function(src, name):
    start = src.index(name)
    start = src.rfind("\n", 0, start) + 1
    brace = src.index("{", start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (src[end] == "{") - (src[end] == "}")
        end += 1
    return src[start:end] + "\n"


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--lgfx", type=Path, required=True, help="Existing LovyanGFX root")
    ap.add_argument("--output", type=Path, required=True, help="Staging output; does not overwrite committed baselines")
    ap.add_argument("--verify", action="store_true", help="Compare staging results against frozen inputs/assets/oracles")
    a = ap.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    if any(a.output.iterdir()):
        ap.error("output must be an empty staging directory")
    with tempfile.TemporaryDirectory(prefix="mimoc-oracle-") as temp:
        temp = Path(temp)
        src = temp / "source"
        src.mkdir()
        archive = subprocess.check_output(["git", "-C", str(a.repo), "archive", COMMIT])
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(src, filter="data")
        (temp / "nvs_rw.hpp").write_text('#pragma once\n#include <string>\ninline std::string capture_language="en";\ninline std::string get_nvs(const char*){return capture_language;}\n')
        dialog = (src / "components/display/include/display/renderer/setting_dialog_renderer.hpp").read_text()
        (temp / "confirm_capture.inc").write_text("namespace display::renderer {\ntemplate <typename Sprite, typename PresentFn>\n"+function(dialog, "ui::confirmdialog::RenderApi make_confirm_dialog_render_api(")+"template <typename Sprite, typename PresentFn>\n"+function(dialog,"ui::language::RenderApi make_language_dialog_render_api(")+"}\n")
        facade = (src / "main/runtime/display_facade.cpp").read_text()
        header = (src / "main/runtime/display_facade.hpp").read_text()
        declarations = header[header.index("enum class SettingStatusIndicator"):header.index("void render_menu_home")]
        prelude = (src/"components/display/src/legacy/runtime/prelude.hpp").read_text()
        write_zig(a.output / "product_fixtures.zig")
        (temp / "product_capture.inc").write_text(cpp_capture())
        pairs=lambda path: re.findall(r'\{"([^"\\]*)",\s*"([^"\\]*)"\}',path.read_text())
        morse=pairs(src/"components/ui/include/ui/core/morse_alphabet.hpp")
        kana=pairs(src/"components/ui/include/ui/talk/romaji_kana.hpp")
        tables='// Generated from pinned morse_alphabet.hpp / romaji_kana.hpp.\npub const Pair=struct{a:[]const u8,b:[]const u8};\n'
        for name,entries in [('morse',morse),('kana',kana)]:
            tables+='pub const '+name+'=[_]Pair{'+','.join('.{.a='+json.dumps(a,ensure_ascii=False)+',.b='+json.dumps(b,ensure_ascii=False)+'}' for a,b in entries)+'};\n'
        (a.output/"reveal_tables.zig").write_text(tables)
        canvas_font=(src/"main/runtime/ehagaki/canvas_text.hpp").read_text()
        match=re.search(r"\{'A', \{([^}]+)\}, rows\(([^)]+)\)\}",canvas_font)
        cols=[int(v.strip(),0) for v in match[1].split(',')]; rows=[int(v.strip()) for v in match[2].split(',')]
        (a.output/"canvas_font.zig").write_text('// Generated from pinned canvas_text.hpp kGlyphs; do not edit.\npub const a_columns=[_]u8{'+','.join(map(str,cols))+'};\npub const a_small=[_]u8{'+','.join(map(str,rows))+'};\n')
        (temp / "product_strings.inc").write_text('const std::string product_strings = '+json.dumps(''.join(str(v) for f in SCENARIOS for v in f.values()),ensure_ascii=False)+';\n')
        extra_names=["std::vector<std::string> wrap_chat_lines(", "void print_chat_line(", "void print_chat_wrapped_tail(", "ChatHistoryGlyphStyle select_chat_history_glyph_style(", "std::vector<std::string> wrap_chat_history_lines(", "void print_chat_history_line(", "void draw_chat_sender_separator(", "void draw_chat_direction_arrow(", "void draw_ehagaki_page_arrow(", "void draw_transient_history_notice(", "void set_ehagaki_glyph_font(", "int process_ehagaki_bounded_text(", "void render_setup_morse_hello(", "void render_open_chat_composer(", "void render_message_box(", "void render_talk_input(", "void render_realtime_talk(", "void render_realtime_scan(", "void render_synth_sequencer(", "void render_ehagaki_text_input(", "void render_ehagaki_public_confirm(", "void render_ehagaki_post_confirm(", "int render_ehagaki_viewer(", "void render_canvas_side_menu(", "void render_draw_canvas(", "void render_ehagaki_canvas("]
        extra=''.join(function(facade,n) for n in extra_names)
        helpers = ''.join(function(facade, n) for n in ["int render_localized_with_ascii_fallback(", "void draw_localized_with_ascii_fallback(", "void render_setting_menu(", "void render_profile_info(", "void render_tra_launcher(", "void render_ehagaki_menu(", "void render_step_composer(", "void render_factory_reset_confirm(", "void render_center_status(", "std::string omitted_ssid(", "void render_wifi_list(", "void render_wifi_text_input(", "void render_offline_notice(", "void render_error_notice(", "void render_blank_screen("])
        (temp / "setting_capture.inc").write_text(
            function(header,"struct RealtimePeerRow")+";\n"+function(header,"enum class RealtimeScanMode")+";\n"+function(header, "struct ComposerStepRender") + ";\n" + declarations + '\nlgfx::LGFX_Sprite sprite;\nint capture_present_x=0; bool capture_panel_bg=false;\nstruct { int height(){return 64;} void fillRect(int,int,int,int,unsigned bg){capture_panel_bg=bg!=0;} } lcd;\n'
            'inline bool ensure_sprite_surface(int,int,int,const char*){return true;}\n'
            'inline void push_sprite_safe(int x,int){capture_present_x=x;}\n'
            'inline size_t utf8_char_length(uint8_t c){return c<128?1:c<224?2:c<240?3:4;}\n' + function(facade, "constexpr unsigned char kOfflineBitmap[]") + ";\n" + function((src/"components/display/src/legacy/runtime/prelude.hpp").read_text(), "inline void draw_char_selector_row(") + function(prelude,"struct ChatGlyphStyle") + ";\n" + function(prelude,"inline ChatGlyphStyle select_chat_glyph_style(") + '\n' + function(facade,"struct ChatHistoryGlyphStyle") + ";\n" + facade[facade.index("constexpr int kChatHistoryPrefixWidth"):facade.index("ChatHistoryGlyphStyle select_chat_history_glyph_style")] + function(facade,"template <typename DrawPixel>") + helpers[:helpers.index("void render_setting_menu(")] + extra + helpers[helpers.index("void render_setting_menu("):])
        bitmap = function(facade, "constexpr unsigned char kOfflineBitmap[]")
        values = re.findall(r"0x[0-9a-fA-F]+", bitmap)
        (a.output / "icons.zig").write_text("// Generated from pinned display_facade.cpp, kOfflineBitmap.\n// Commit " + COMMIT + "\npub const offline = [_]u8{" + ",".join(values) + "};\n")
        lg = a.lgfx / "src"
        sources = ["LGFXBase.cpp", "LGFX_Sprite.cpp", "lgfx_fonts.cpp", "misc/pixelcopy.cpp", "misc/common_function.cpp", "misc/SpriteBuffer.cpp", "platforms/sdl/common.cpp", "panel/Panel_Device.cpp", "panel/Panel_HasBuffer.cpp", "panel/Panel_SSD1306.cpp"]
        font_sources = [src / "components/display/src" / n for n in ["font_mobus_custom7.cpp", "font_misaki_gothic8.cpp", "font_u8g2_b12_japanese1.cpp"]]
        cmd = ["clang++", "-std=c++20", "-O2", "-Wno-vla-cxx-extension", "-Wl,-dead_strip", "-I"+str(temp), "-I"+str(src/"main"), "-I"+str(lg), "-I/opt/homebrew/include", "-L/opt/homebrew/lib", "-lSDL2"]
        cmd += ["-I"+str(p) for p in sorted(src.glob("components/**/include"))]
        inputs = [ROOT / "tools/mobus_capture.cpp"] + font_sources + [lg / "lgfx/v1" / p for p in sources]
        ipa=lg/"lgfx/Fonts/IPA/lgfx_font_japan.c"
        subprocess.run(["clang","-O2","-c",str(ipa),"-o",str(temp/"ipa.o")],check=True)
        notices='Original font source notices, pinned Mo-Bus '+COMMIT+' and hashed LovyanGFX.\n'
        for source in font_sources+[ipa]:
            notices+='\n'+source.name+'\n'+'\n'.join(block for block in re.findall(r'/\*.*?\*/',source.read_text(),re.S) if 'Fontname:' in block)
        (a.output/"font-source-notices.txt").write_text(notices)
        (a.output/"IPA_Font_License_Agreement_v1.0.txt").write_bytes((ipa.parent/"IPA_Font_License_Agreement_v1.0.txt").read_bytes())
        cmd += [str(temp/"ipa.o")] + list(map(str, inputs)) + ["-o", str(temp / "capture")]
        subprocess.run(cmd, check=True)
        subprocess.run([str(temp / "capture"), str(a.output.resolve())], check=True)
        hashes = {str(p.relative_to(src)): digest(p) for p in sorted(src.rglob("*")) if p.is_file() and ("renderer" in p.parts or p in font_sources or "components/ui/" in str(p.relative_to(src)) or "main/runtime/" in str(p.relative_to(src)) or p.name in ["display_facade.cpp", "display_facade.hpp", "ui_strings.hpp", "prelude.hpp"])}
        # Hash the complete actual graphics dependency, including headers/font tables.
        dep_hashes = {str(p.relative_to(a.lgfx)): digest(p) for p in sorted(a.lgfx.rglob("*")) if p.is_file() and ("src" in p.relative_to(a.lgfx).parts or p.name in ["library.json", "license.txt"])}
        manifest = {"commit": COMMIT, "source_sha256": hashes, "lovyangfx_sha256": dep_hashes, "harness_sha256": digest(ROOT / "tools/mobus_capture.cpp"), "converter_sha256": digest(Path(__file__)), "fixtures_sha256": digest(ROOT/"tools/mobus_product_fixtures.py"), "capture": "original C++ renderers -> RGB332 Sprite -> original Panel_SSD1306, rotation 2 -> logical page-LSB", "clock": "2026-06-01 12:34:56 UTC", "compiler": subprocess.check_output(["clang++", "--version"], text=True).splitlines()[0], "unverified": {"text-offline.raw": "kOfflineBitmap contains 87 bytes but drawBitmap reads 90; last row is undefined", "text-error.raw": "same original bitmap out-of-bounds read"}}
        binary = (a.output / "glyphs.bin").read_bytes()
        records=[]
        masks=[]
        def mask_index(data):
            data=data.rstrip(b"\0")
            if data not in masks:
                masks.append(data)
            return masks.index(data)
        for pos in range(0,len(binary),265):
            b=binary[pos:pos+265]
            records.append('.{ .font = %d, .print = %s, .cp = %d, .advance = %d, .measure = %d, .height = %d, .ink = %d, .coverage = %d },' % (b[0],str(bool(b[1])).lower(),int.from_bytes(b[2:6],'little'),b[6],b[7],b[8],mask_index(b[9:137]),mask_index(b[137:265])))
        (a.output / "glyphs.zig").write_text('// Generated by tools/capture_mobus_reference.py. Do not edit.\n// Mo-Bus '+COMMIT+'; Original font licenses: FreeBSD / IPA / efont; see provenance.md.\npub const Glyph = struct { font:u8, print:bool, cp:u21, advance:u8, measure:u8, height:u8, ink:u16, coverage:u16 };\npub const glyphs = [_]Glyph{\n'+ '\n'.join(records)+'\n};\npub const masks = [_][]const u8{\n'+'\n'.join('&.{'+','.join(map(str,mask))+'},' for mask in masks)+'\n};\n')
        manifest["generated_sha256"] = {p.name: digest(p) for p in sorted(a.output.glob("*")) if p.is_file()}
        (a.output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+"\n")
        if a.verify:
            frozen = ROOT / "examples/mobus/reference"
            prior = json.loads((frozen / "golden/manifest.json").read_text())
            for field in ["commit", "source_sha256", "lovyangfx_sha256", "harness_sha256", "converter_sha256", "fixtures_sha256"]:
                if manifest[field] != prior[field]:
                    raise SystemExit("FAIL: pinned input changed: " + field)
            for path in sorted(a.output.glob("*.raw")):
                if path.name in manifest["unverified"]:
                    continue
                if path.read_bytes() != (frozen / "golden" / path.name).read_bytes():
                    raise SystemExit("FAIL: independent oracle changed: " + path.name)
            for name in ["glyphs.zig", "icons.zig", "canvas_font.zig", "reveal_tables.zig", "product_fixtures.zig", "product_catalog.zig"]:
                if (a.output / name).read_bytes() != (frozen / name).read_bytes():
                    raise SystemExit("FAIL: generated font/icon changed: " + name)
            for name in ["font-source-notices.txt","IPA_Font_License_Agreement_v1.0.txt"]:
                if (a.output/name).read_bytes()!=(frozen/"assets"/name).read_bytes():
                    raise SystemExit("FAIL: font provenance changed: "+name)
            print("PASS: frozen inputs/assets and all defined oracle pixels reproduced")
        print("Captured", len(list(a.output.glob("*.raw"))), "independent screens and", len(records), "glyph records /",len(masks),"unique masks at", a.output)


if __name__ == "__main__":
    main()
