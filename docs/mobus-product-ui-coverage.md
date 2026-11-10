# Mo-Bus product UI coverage

Baseline: `4b6705f62160e1849cd161f9515d507df90d23d2` (`fix/after-release`).

## Coverage gate

**29/29 required P0 major surfaces, 100%.** Catalog: **196 scenarios**, **191
VERIFIED**, **5 SOURCE-FAITHFUL**, **0 UNVERIFIED P0**. All 191 defined oracle
frames match1024 bytes exactly; all196 are deterministic100 times and equal
between Native Zig and generated C. All Candidate seeds have zero difference.
This is major-surface coverage, not every possible edge case or persistent
transition sequence. `zig build check-mobus-product-coverage` gates the
`catalog.required_p0` list; ordinary tests also enforce it.

VERIFIED = exact independent original renderer/panel output. SOURCE-FAITHFUL
= source port with explicit reference uncertainty. UNVERIFIED = investigated
but uncaptured/uncompared path. MISSING = no reference scenario yet. The five
SOURCE-FAITHFUL entries share the original87-byte/90-byte Offline icon defect;
no oracle performs its out-of-bounds final-row read.

## Implemented surfaces

The names below are actual CLI and Studio scenario IDs. P0 rows are required
before Design System work. New Candidate entries are seeded directly from
Legacy; no redesign has been performed.

| Tier | Feature | Surface | Original renderer | Scenarios | Legacy status |
|---|---|---|---|---|---|
| P0 | MENU | menu | `render_menu_home / menu_renderer` | `menu/default`<br>`menu/selected-settings`<br>`menu/notification`<br>`menu/radio-offline` | 4 VERIFIED |
| P0 | CONTACTS | contacts | `render_contact_book / contact_renderer` | `contacts/default`<br>`contacts/pending`<br>`contacts/unread`<br>`contacts/mode-cq`<br>`contacts/mode-focused`<br>`contacts/loading` | 6 VERIFIED |
| P1 | OPEN_CHAT | chat | `open_chat_renderer / composer render API` | `chat/default`<br>`chat/long-message`<br>`chat/mine-selected`<br>`chat/japanese` | 4 VERIFIED |
| P0 | SETTINGS | settings | `render_setting_menu` | `settings/default`<br>`settings/selected`<br>`settings/scrolled` | 3 VERIFIED |
| P1 | DIALOGS | dialog | `confirm API / render_factory_reset_confirm` | `dialog/confirm-no`<br>`dialog/confirm-yes`<br>`dialog/factory-reset-no`<br>`dialog/factory-reset-yes` | 4 VERIFIED |
| P1 | PROFILE | profile | `render_profile / profile_renderer` | `profile/default`<br>`profile/scrolled` | 2 VERIFIED |
| P1 | INSTRUMENTS | tra | `render_tra_menu / render_step_composer` | `tra/default`<br>`tra/selected-synth` | 2 VERIFIED |
| P0 | EHAGAKI | root | `render_ehagaki_menu` | `ehagaki/menu-default`<br>`ehagaki/menu-timeline`<br>`ehagaki/root-post-selected`<br>`ehagaki/root-browse-selected` | 4 VERIFIED |
| P1 | OPEN_CHAT | rooms | `open_chat_renderer / composer render API` | `rooms/default`<br>`rooms/selected` | 2 VERIFIED |
| P1 | INSTRUMENTS | composer | `render_tra_menu / render_step_composer` | `composer/default`<br>`composer/playing` | 2 VERIFIED |
| P0 | WIFI | connection | `render_wifi_list / render_text_input / render_center_status` | `wifi/scanning`<br>`wifi/connecting`<br>`wifi/error` | 3 VERIFIED |
| P0 | WIFI | list | `render_wifi_list / render_text_input / render_center_status` | `wifi/list`<br>`wifi/selected`<br>`wifi/scrolled` | 3 VERIFIED |
| P0 | WIFI | password | `render_wifi_list / render_text_input / render_center_status` | `wifi/password`<br>`wifi/password-delete` | 2 VERIFIED |
| P1 | TEXT | text | `render_*_notice / render_center_status` | `text/default`<br>`text/two-lines`<br>`text/offline`<br>`text/error`<br>`text/blank` | 3 VERIFIED, 2 SOURCE-FAITHFUL |
| P0 | QSP | history | `render_message_box` | `qsp/empty-loading`<br>`qsp/single-incoming`<br>`qsp/single-outgoing`<br>`qsp/mixed`<br>`qsp/sender-change`<br>`qsp/long-wrap`<br>`qsp/scrolled-middle`<br>`qsp/scrolled-bottom`<br>`qsp/japanese`<br>`qsp/mixed-japanese-english`<br>`qsp/transient-notice` | 11 VERIFIED |
| P0 | QSP | composer | `render_talk_input` | `qsp-compose/empty`<br>`qsp-compose/text`<br>`qsp-compose/morse`<br>`qsp-compose/decoded-preview`<br>`qsp-compose/long-wrap`<br>`qsp-compose/japanese`<br>`qsp-compose/language-overlay`<br>`qsp-compose/send-failed`<br>`qsp-compose/limit-feedback` | 9 VERIFIED |
| P0 | CQ | connection | `render_realtime_scan / render_realtime_talk / render_center_status` | `cq/checking`<br>`cq/calling`<br>`cq/ending`<br>`cq/error-offline`<br>`cq/error-failed` | 5 VERIFIED |
| P0 | CQ | incoming | `render_realtime_scan / render_realtime_talk / render_center_status` | `cq/incoming-no-selected`<br>`cq/incoming-yes-selected` | 2 VERIFIED |
| P0 | CQ | active | `render_realtime_scan / render_realtime_talk / render_center_status` | `cq/active-empty`<br>`cq/active-local-text`<br>`cq/active-remote-text`<br>`cq/active-morse`<br>`cq/language-overlay`<br>`cq/active-japanese`<br>`cq/active-status` | 7 VERIFIED |
| P0 | SYNTH | grid | `render_synth_sequencer` | `synth/grid-default`<br>`synth/grid-pattern`<br>`synth/grid-selected-step`<br>`synth/grid-selected-track`<br>`synth/grid-accent`<br>`synth/grid-disabled-track`<br>`synth/grid-playing`<br>`synth/grid-playhead` | 8 VERIFIED |
| P0 | SYNTH | header | `render_synth_sequencer` | `synth/header-bpm`<br>`synth/header-page`<br>`synth/header-sound`<br>`synth/header-load`<br>`synth/header-save` | 5 VERIFIED |
| P0 | SYNTH | bpm editor | `render_synth_sequencer` | `synth/bpm-editor` | 1 VERIFIED |
| P0 | SYNTH | page editor | `render_synth_sequencer` | `synth/page-editor-length`<br>`synth/page-editor-copy`<br>`synth/page-editor-paste`<br>`synth/page-editor-clear` | 4 VERIFIED |
| P0 | SYNTH | sound editor | `render_synth_sequencer` | `synth/sound-editor-track`<br>`synth/sound-editor-preset` | 2 VERIFIED |
| P0 | SYNTH | slots | `render_synth_sequencer` | `synth/load-slot`<br>`synth/save-slot` | 2 VERIFIED |
| P0 | SYNTH | dialogs | `render_synth_sequencer` | `synth/load-confirm-no`<br>`synth/load-confirm-yes`<br>`synth/save-confirm-no`<br>`synth/save-confirm-yes`<br>`synth/clear-confirm` | 5 VERIFIED |
| P0 | EHAGAKI | lifecycle | `render_ehagaki_post_confirm / status / offline` | `ehagaki/preparing`<br>`ehagaki/browse-loading`<br>`ehagaki/browse-error`<br>`ehagaki/posting`<br>`ehagaki/complete`<br>`ehagaki/error`<br>`ehagaki/post-confirm`<br>`ehagaki/error-offline` | 7 VERIFIED, 1 SOURCE-FAITHFUL |
| P0 | EHAGAKI | browse | `render_ehagaki_viewer / status / offline` | `ehagaki/browse-front-image`<br>`ehagaki/browse-front-text`<br>`ehagaki/browse-back`<br>`ehagaki/browse-page-overlay`<br>`ehagaki/browse-text-scroll-top`<br>`ehagaki/browse-text-scroll-middle`<br>`ehagaki/browse-text-scroll-bottom`<br>`ehagaki/browse-mine`<br>`ehagaki/browse-public`<br>`ehagaki/browse-flip`<br>`ehagaki/browse-text-reveal`<br>`ehagaki/browse-offline` | 11 VERIFIED, 1 SOURCE-FAITHFUL |
| P0 | EHAGAKI | text editor | `render_ehagaki_text_input` | `ehagaki/title-en`<br>`ehagaki/title-ja`<br>`ehagaki/body-en`<br>`ehagaki/body-ja`<br>`ehagaki/text-language-overlay`<br>`ehagaki/text-long-wrap`<br>`ehagaki/canvas-text` | 7 VERIFIED |
| P0 | EHAGAKI | visibility | `render_ehagaki_public_confirm` | `ehagaki/visibility-private`<br>`ehagaki/visibility-public` | 2 VERIFIED |
| P0 | EHAGAKI | canvas | `render_ehagaki_canvas` | `ehagaki/canvas-empty`<br>`ehagaki/canvas-drawing`<br>`ehagaki/canvas-dot`<br>`ehagaki/canvas-line-anchor`<br>`ehagaki/canvas-line-preview`<br>`ehagaki/canvas-rect-anchor`<br>`ehagaki/canvas-rect-preview`<br>`ehagaki/canvas-rect-fill`<br>`ehagaki/canvas-cursor`<br>`ehagaki/canvas-notice` | 10 VERIFIED |
| P0 | EHAGAKI | canvas menus | `render_ehagaki_canvas` | `ehagaki/canvas-menu-right`<br>`ehagaki/canvas-menu-left`<br>`ehagaki/canvas-undo-enabled`<br>`ehagaki/canvas-redo-enabled`<br>`ehagaki/canvas-stroke-menu`<br>`ehagaki/canvas-rect-outline`<br>`ehagaki/canvas-rect-filled`<br>`ehagaki/canvas-white-ink`<br>`ehagaki/canvas-black-ink` | 9 VERIFIED |
| P0 | EHAGAKI | selection | `render_ehagaki_canvas` | `ehagaki/canvas-select-start`<br>`ehagaki/canvas-select-end`<br>`ehagaki/canvas-select-mode-move`<br>`ehagaki/canvas-select-mode-copy`<br>`ehagaki/canvas-select-place` | 5 VERIFIED |
| P0 | EHAGAKI | text placement | `render_ehagaki_canvas` | `ehagaki/canvas-text-font-small`<br>`ehagaki/canvas-text-font-normal`<br>`ehagaki/canvas-text-place` | 3 VERIFIED |
| P0 | EHAGAKI | clear dialog | `render_ehagaki_canvas` | `ehagaki/canvas-clear-no`<br>`ehagaki/canvas-clear-yes` | 2 VERIFIED |
| P1 | FACTORY | factory | `render_* setup status/input/language/morse` | `factory/authenticating`<br>`factory/saving`<br>`factory/failed`<br>`factory/complete`<br>`factory/login-id`<br>`factory/password`<br>`factory/nickname`<br>`factory/language-en`<br>`factory/language-ja`<br>`factory/hello-start`<br>`factory/hello-settled` | 11 VERIFIED |
| P1 | FIRMWARE | firmware | `render_wifi_list` | `firmware/default`<br>`firmware/scrolled` | 2 VERIFIED |
| P1 | PROFILE | profile_product | `render_profile / profile_renderer` | `profile/product-default`<br>`profile/product-scrolled` | 2 VERIFIED |
| P1 | DRAW | draw | `render_draw_canvas` | `draw/empty`<br>`draw/drawing`<br>`draw/line-preview`<br>`draw/rect-preview`<br>`draw/cursor` | 5 VERIFIED |
| P1 | REALTIME | realtime | `render_realtime_*` | `realtime/scanning`<br>`realtime/peers`<br>`realtime/incoming`<br>`realtime/connecting`<br>`realtime/active` | 5 VERIFIED |
| P1 | OPEN_CHAT | open_compose | `open_chat_renderer / composer render API` | `open-compose/empty`<br>`open-compose/text`<br>`open-compose/morse`<br>`open-compose/japanese` | 4 VERIFIED |
| P0 | QSP | delivery | `render_center_status / render_offline_notice` | `qsp/sending`<br>`qsp/offline` | 1 VERIFIED, 1 SOURCE-FAITHFUL |

## Supporting/optional paths outside the gate

| Tier | Feature / surface | Current evidence | Legacy status / reason |
|---|---|---|---|
| P1 | Contacts pending/action/accept/reject/friend-code dialogs | Screen/facade call sites inventoried; Contact Book main states verified | MISSING additional dialog fixtures |
| P1 | Settings language confirmation, sound and boot-sound dialogs | Renderer expressions inventoried; Factory language selection verified | MISSING remaining settings variants |
| P1 | Settings RTC, text-modal, OTA/update progress | Facade/source inventory; Firmware Info's actual list path verified | MISSING additional setting paths |
| P1 | Draw side menus and all canvas application transitions | Basic Draw and shared advanced Ehagaki canvas verified | MISSING Draw-specific menu fixtures |
| P1 | Low battery / charging standby | Existing renderer expressions retained in inventory | UNVERIFIED capture/bitmap variants |
| P2 | Watch / TRA watch | Font4 path inventoried | UNVERIFIED font/clock capture |
| P2 | Typing/trainer/arcade games | Font0/FreeMono/GFX paths inventoried | UNVERIFIED font datum/game fixture capture |

These supporting/optional gaps do not substitute for any P0 UI. In particular,
Open Chat is not counted as QSP history, step Composer is not counted as Synth,
and the older simplified Ehagaki demo is not counted as the production canvas.
Remaining non-P0 work is explicitly scoped instead of certifying unseen states.

## Data, capture and comparison

`tools/mobus_product_fixtures.py` contains149 fixed final-render-argument fixtures,
generated into `product_fixtures.zig` and `product_catalog.zig`; the existing44
entries and three explicit Offline aliases bring the total to196. The original
C++ adapter is generated from the same fixture values, with original wrapping
and raster functions. Zig has separate source-faithful drawing code, not bitmap
replay. Captured raw frames are comparison data only.

```sh
zig build mobus-reference-snapshot -- --coverage
zig build check-mobus-product-coverage
zig build check-mobus-reference
zig build check-mobus-reference-c
```

The first command outputs feature/surface/status/name TSV. The final comparison
covers every catalog entry. See [baseline/capture details](mobus-pixel-reference.md)
and [product transitions](mobus-product-ui-inventory.md). Physical OLED captures,
network/audio/storage integration and redesign are outside this task.
