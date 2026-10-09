# Current Mo-Bus UI consistency audit

Baseline: `Mobus_ESP_IDF/fix/after-release` at
`94873ec79bd70d2f38040d173f2f9c89853b5734`. This is an inventory of differences,
not a request to fix Legacy Reference. All coordinates derive from the pinned
[renderer expressions](mobus-source-coordinates.md).

## Typography

MENU/TRA/Synth use C7, English Contacts/Open Chat/Profile use Font2. SETTINGS
uses C7 ASCII even when its initial font selection is localized Font2. Message
Box uses C7 ASCII at y+2 and Misaki8 others at y+4; Talk uses another mixed
glyph style with non-ASCII y+3; Ehagaki back text switches to lgfxJapanGothic_8.
Watch uses Font4; games add Font0 and FreeMono9/12. Built-in Font2 has height16,
converted C7/Misaki8 report height7; their names do not define line height.

The current Misaki asset is Katakana-only. ASCII, hiragana and kanji in that
font use fallback raster. Legacy retains this; a Candidate font role must
deliberately decide supported glyph coverage. Missing-glyph data is not a
successful Japanese-font implementation merely because UTF-8 parsing succeeds.

## Spacing and headers/footers

| UI | Header / divider | Body / margin | Footer / row pitch |
|---|---|---|---|
| Menu | Mode y9; lines20,42 | outer margin5; icon x15/53/93,y29 | battery/time y49 |
| Contacts | name box y2,h18 | centre knob y37; tuner54; no common body margin | no shared footer |
| Open Chat | centre0; divider12 | x0,y16; width128 | footer56; English18px/Japanese12px rows |
| Message Box | centre0; divider14, black15 | text x16; clip typically16..63; prefix12 | variable blocks +5px sender gap; scrollbar x124 |
| Settings | none | labels x2,y6+16*i | four16px rows; no footer |
| Wi-Fi | title argument unused | x10,y16*i; localized y+4 | four16px rows |
| Room Selector | centre0; divider12 | x4,y16+12*i; inverse y−2,h12 | footer56; F2 font16 exceeds row pitch12 |
| Profile | none | x0; label/value separated14px | block28px |
| Talk edit | enclosing frame3,3,122,58 | x7,y7,width114; tail rows14 | optional separator48/status50 |
| Ehagaki edit English | header2; divider14 | y16,width126; rows14 | count gap4 |
| Ehagaki edit Japanese | header5; divider17 | y19,width126; rows14 | count remains C7 |
| Firmware info | centre0 | left x2, supplied line y | hint54 |
| TRA | none | 3×2 cells39×25, gap3/4, origin2,5 | text y+3/+13 or y+8 |

There is no current single header height, body inset or baseline. Normalizing
these would be a redesign and must happen only in `examples/mobus/design/`.

## Selection, lists and status

Selection uses brackets on MENU, triangle slots plus focused double circle on
CONTACTS, whole inverse rows on SETTINGS/Wi-Fi/Open Chat, inverse **prefix
only** on Message Box outgoing entries, rounded fill on Ehagaki menu and
dialogs, cell fill on TRA, and separate cursor/playhead frames on Composer.
Draw/Ehagaki canvases additionally use inverted bitmap cursor and tool borders.

SETTINGS and Wi-Fi share16px pitch but differ in x2/x10, font and baseline.
Room Selector has12px pitch with a16px English font and intentionally permits
overlap. Profile uses28px blocks with no title bar. Message Box sums variable
row heights and sender gaps. There is no universal scrollbar: Contact tuner,
list windowing and Message Box proportional thumb are different interactions.

Unread is circles r3/r1 in Contacts, while MENU notification uses r4 and
inverts to black when selected. Settings On uses filled r3; Off clears r4 and
outlines r3; Busy uses three r1 dots. Do not replace these with a shared status
widget in the frozen renderer.

## Dialogs and colour

Generic confirm title10/buttons34/text36 differs from Contact confirm title14
and factory/incoming dialogs with buttons44/text46 and extra lines. Language
highlight height is16px English vs14px Japanese. Sound dialog centres at
6/18/30/42/52/60, while Boot sound uses6/24/40/52; bottom text can clip.
Canvas toast is a60×22 rounded frame at34,21; language overlay24×18 at52,24.

Integer/uint16 white and unsigned RGB888 whites are not interchangeable:
Open Chat inverse glyph background0xFFFFu becomes cyan and is dithered, while
its rectangle fill0xFFFF is white. Contacts0xC618 and canvas0x7BEF are converted
through RGB332 and OLED gamma/Bayer. Message Box scrollbar uses0x2104. A future
1-bit colour role should specify this explicitly; Legacy must preserve it.

The Offline bitmap requests24×30 from87 bytes (29 rows). The safe port labels
this SOURCE-FAITHFUL and does not invent a golden for the unknown row. This is
source uncertainty, separate from aesthetic inconsistency.

## Candidate design-system opportunities

The Candidate entrypoint receives the same fixed fixtures/scenarios as Legacy.
It starts unchanged so the initial diff is0; no tokens below are applied yet.

| Future area | Candidate decision to investigate |
|---|---|
| Typography | FontRole title/body/small/status; actual glyph coverage, baseline, line height and missing-glyph policy |
| Spacing | xxs/xs/sm/md measured in logical pixels; screen margin, text inset and status gaps |
| Layout | header/footer heights, row height, divider placement, clip boundaries |
| Components | Header, Footer, ListRow, SelectedRow, Dialog, StatusBar, Scrollbar, Tuner, Knob, Notification |
| Interaction | navigation focus vs active selection vs pressed; text capture and disabled/loading presentation |
| Monochrome colour | explicit on/off/dither roles, background opacity and inverse semantics |

Compare representative scenarios using Legacy/Candidate side-by-side, alternate
and XOR before choosing tokens. Keep source SHA, golden files, legacy fonts and
legacy geometry frozen. Changes to Candidate must not silently change baseline
fixtures or recapture goldens from Candidate output.
