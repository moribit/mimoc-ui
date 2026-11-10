# Mo-Bus product UI paths and final render state

Source baseline: `4b6705f62160e1849cd161f9515d507df90d23d2`. This inventory
follows actual user-facing Screen phases and facade calls, rather than
assuming similarly named chat/instrument renderers are interchangeable.
The [coverage matrix](mobus-product-ui-coverage.md) lists every fixed scenario;
[expression inventory](mobus-source-coordinates.md) retains original line
numbers, geometry and dependencies across all22 Screen sources.

## Baseline change review

Compared to94873ec, the current branch changes11 files (1085 insertions,
103 deletions), including247 changed lines in the display facade. Runtime
changes chiefly extend Ehagaki canvas selection/text. Render changes include
ASCII header override for CanvasText; five-entry menus; stroke/rectangle-fill
submenus; dotted selection bounds and cross; SelectStart/SelectEnd/SelectMode/
SelectPlace; TextFont/TextPlace; clear confirmation and modal toast suppression.
Menu/Contacts/Open Chat/Settings and existing other goldens did not change.
The baseline was nevertheless updated globally: all42 original VERIFIED
frames were independently recaptured and byte-compared to the prior set.

## QSP: Contacts → Message Box → Compose → Send

Source: `message_box_screen.hpp`, `message_box_mvp.hpp`, `render_message_box`,
`render_talk_input`. Message Box phases are History, Compose, Sending and
OfflineNotice. **QSP composition is the Message Box's Talk input path**;
`composer_screen.hpp` instead implements the independent step composer.
Open Chat's composer callback is a third distinct path.

| Product surface | Final state / renderer | Geometry and preserved behavior |
|---|---|---|
| History/loading | Fixed message ViewState, scroll and transient notice → render_message_box | Headery0, divider14/black15; body starts16; clip/body height, variable blocks, sender-change5px separator, arrows, outgoing12px prefix inversion; scrollbarx124, min thumb6 |
| History mixed/JP/scrolled | Original wrap_chat_history_lines → fixed entry lines | C7ASCII y+2, Misaki8others y+4; textx16,width107; fixed negative scroll offsets; not full-row inversion |
| Compose | InputViewState/message/morse/preview/cursor/language/status → render_talk_input | Original mixed glyph style, tail wrapping, cursor, language overlay, persistent send-failed notice and inverted shifted limit feedback |
| Sending | render_center_status("Sending...") | Fixed loading surface; no network worker |
| Offline | render_offline_notice | SOURCE-FAITHFUL due to original icon's undefined final row |

Fixtures include single incoming/outgoing, grouped senders, long and mixed
Japanese/English text, valid middle/bottom offsets, Loading..., NEW MESSAGES,
empty/text/Morse/preview/overlay/feedback drafts. PSRAM collections become
fixed borrowed strings/arrays only on the Zig side; no memory ownership model
from production is imported into Core.

## CQ: StartingCall / CheckingIncoming / Calling / Incoming / Active / Ending / Error

Source: `cq_chat_screen.hpp::render()` and original realtime renderers.

| Phase | Actual call / scenario group |
|---|---|
| StartingCall, Calling | Same render_realtime_scan Connecting appearance → cq/calling |
| CheckingIncoming | render_center_status("Checking CQ") → cq/checking |
| Incoming | render_realtime_scan Incoming; NO/YES selected separately |
| Active | render_realtime_talk(InputViewState, cursor, remote_text+peer_morse, status, language expiry, now); empty/local/remote/Morse/status/JP/overlay fixtures |
| Ending | render_center_status("CQ Ended") |
| Error | render_center_status("OFFLINE") or "CQ failed"; fixed peer argument |

Realtime active uses upper local content, divider32, lower remote/status.
It is not QSP history or Open Chat. Standalone Realtime Talk also has verified
scan/peer-list/incoming/connecting/active surfaces. Fixed current time supplies
cursor/overlay state; there is no transport/session/audio execution.

## Synth: grid → header → editors / slots / confirmation

Source: `synth_screen.hpp`, `render_dialog_mode()`, `render_synth_sequencer`.
Grid has6 tracks ×16 steps: K/S/H/B/L/E. Divider11, gridx14, cell width7,
row start16, row pitch8. Header contains transport, BPM, page, sound, load,
save. Active/accent/selected/playhead/4-step dividers and disabled tracks keep
separate production pixels. Playing fixtures fix current note and playhead.

| UiMode | Fixed renderer arguments / coverage |
|---|---|
| Grid | Masks[6], accents[6], selected track/step, playhead, enabled bitset, playing/note, tempo/pages |
| HeaderNavigation | header selection BPM/page/sound/load/save |
| BpmEditor | dialog mode1 |
| PageEditor | dialog mode4; length/copy/paste/clear item |
| SoundEditor | dialog mode2; track vs preset field |
| LoadSlot / SaveSlot | dialog modes3/5; fixed slot |
| LoadConfirm / SaveConfirm | dialog modes6/7; separate NO/YES |
| ClearConfirm | dialog mode8 |

27 fixtures cover the major visual modes. Original Screen's atomics, playback,
NVS and audio are not host-run: only its final render argument contract is
reconstructed from fixed data, then passed to original C++ rendering.

## Ehagaki: root → browse or post editor → canvas → publish

Source: `ehagaki_screen.hpp`, canvas/text/reveal runtime helpers, facade.

| Phase | Actual surface / fixed input |
|---|---|
| Preparing | render_center_status("Preparing", ""); empty second line remains distinct from null |
| Menu | POST / MY POST / TIMELINE root selection; both posting and browsing represented |
| BrowseLoading / BrowseError | Fixed status strings; Offline path separately SOURCE-FAITHFUL |
| BrowseFront | render_ehagaki_viewer with original 122×58 image, including canvas text rendered into that bitmap |
| BrowseBack | Title/body text with JapanGothic8, exact source wrapping, scroll, page overlay and fixed reveal elapsed |
| Title / Body | render_ehagaki_text_input, limit30/200 and original displayed count; English/Japanese variants |
| CanvasText | Same input renderer with ascii_header=true, retaining the newer production override |
| Canvas | render_ehagaki_canvas with bitmap/cursor/mode/anchor/menu/stroke/ink/overlay/stage state |
| Visibility | render_ehagaki_public_confirm private/public choice |
| Confirm | render_ehagaki_post_confirm |
| Posting / Complete / Error | Fixed production lifecycle status strings; offline error separately SOURCE-FAITHFUL |

Text editor English header/divider/content y2/14/16 vs Japanese y5/17/19.
Header font C7 vs Misaki8, counter C7; body uses original mixed talk glyphs.
Title/body counters derive from fixed text length; language selection is an
original overlay. Browse mine/public uses the same viewer; filtering does
not invent a badge. Front/back, page overlay, flip inset, scrolltop/middle/
bottom and Morse/romaji reveal are distinct fixtures.

Canvas is **122×58 at(3,3)**, not the older simplified demo. Right menu is
DOT/LINE/RECT/TEXT/COLOR; left menu is UNDO/REDO/CLEAR/SELECT/NEXT. Dot, line
anchor/preview, rectangle anchor/outline/fill, cursor, stroke popup, ink,
notice, menu focus and enabled undo/redo arguments are retained. Production
currently renders undo/redo label color identically despite those flags.

CanvasStage overlays: SelectStart, SelectEnd, SelectMode (copy/cut), SelectPlace,
TextFont, TextPlace; selection dotted perimeter and preview placement are
exactly compared. Clear confirmation has separate NO/YES. Canvas text fonts
come from converted original5×7/3×5 tables. These cases use deterministic
application-owned bitmap data, not audio/storage/draft services.

## Supporting UI and intentional scope

Settings retains headerless four16px rows and independent confirmation
geometries. Wi-Fi uses actual list truncation/inverse selection, text-input
password and connection/error states. Factory Setup adds nickname, password,
language, saving/hello/result; its password renderer currently shows unmasked
text, which is faithfully preserved. Fixed Morse hello is compared before
and after reveal. Firmware Info follows the current `render_wifi_list` route,
including its SSID-style shortening behavior rather than a nicer text modal.
Production Profile is the Name/Friend ID/Short ID list, separately named from
the earlier Profile template fixtures. Basic Draw covers bitmap/cursor/anchors;
its remaining application-specific menus are a supporting gap.

Contact-action details, some settings dialogs, maintenance/OTA screens and
Draw-specific menus remain scoped P1 additions. Watch/games are independent
P2 applications with additional fonts, not blockers for P0. No production
state, network, storage, audio or firmware integration is attempted here.
No current UI geometry or selection style was standardized.
