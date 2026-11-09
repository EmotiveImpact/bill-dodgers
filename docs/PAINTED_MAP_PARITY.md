# Native painted overworld and title

## Source and ownership

`game/index.html` is the reference. Its `MAP4`, `GAME` and `IMG` declarations are parsed as JSON by the existing deterministic importer into generated `godot/content/map.json`. No map JavaScript is executed, and no source-web file or deployment configuration is changed. All eighteen referenced pictures retain their original bytes and share the content-addressed asset store. The six island paintings are neither downsampled nor converted into a tile/pixel-grid approximation.

Native presentation is in `campaign_map.gd`, `campaign_map_painter.gd` and `title_menu.gd`. The host's existing `Campaign` rules and `start_campaign_level` remain the authority for stage entry, story eligibility, unlocks and actual progression. The map cannot clear a stage, award receipts, grant a skill or bank Kitty money.

## Implemented

- Original title painting, Press start, original cast-roll attract scene after seven seconds, one 19.8-second attract interval, interruption and background pause. Attract playback uses its own native story player and never writes story-seen flags.
- Source intro-before-map sequence for fresh Story mode and confirmed New story, followed by normal guarded first-stage entry without replaying that introduction. Continue returns directly to the map.
- Story/continue, completed-story menu, separate development/free-play picker, eligible story library, credits replay, controls help and explicit new-story confirmation. Native reset is atomic, preserves the selected housemate and cannot alter a browser save.
- All six original island placements, 42 stage stops, Home, intermediate gates, complete authored route polylines, source path prerequisites, bridge and ferry routes.
- Mirrored painted sea plus drifting layer, glints, authored turning-boat animation, gull animation, lighthouse pulse, sea stacks, whale appearances, balloon, waterfalls, chimney smoke, drifting clouds and locked-island cloud banks.
- Source-style stage/bonus/home/boss markers, cleared marks and boss flags, animated golden trails, bridge construction, source walker idle/run frames and ferry pose. Walker speed is 260 world pixels/second, ferry speed 300. Camera follow, near/overview zoom and long-route hops retain source behavior.
- Boss-to-next-island banner, cloud opening and trail reveal followed by automatic walking. Bonus stops retain their actual graph prerequisites and do not displace the next main-stage destination.
- Stage cards with original name, kind and description, receipts, guarded Play/Play again and Close. A native Worlds/stage list provides a practical keyboard-accessible alternative to finding small markers in the painting.
- Mouse/touch stop selection, drag-to-look, pinch/wheel zoom, arrow-key graph navigation, Enter/Space, Escape and M. Releases over header controls, cancelled touches, interrupted pinches, focus changes and repeated navigation cannot retain a contact or turn a cancelled pinch into a stage tap.
- Six-housemate portraits in original order, selected native character, Kitty total and access to the title menu from the map.
- Validated native presentation persistence: `friend`, `map_at`, and `map_shown`. Restoration intersects locations/edge IDs with the real graph and verified campaign state. Writes happen at arrivals, finished reveals and character changes, not every frame. Storage failures appear in the map footer. Presentation fields cannot forge an unlock.

## Deliberate safeguards and remaining differences

- The original web map's `Mark as cleared` and unrestricted `save.preview` completion shortcuts are not exposed in the native campaign. Development inspection remains a separate explicit path and uses existing guarded native completion rules.
- Locked-island tint and breathing coastline/shadow layers approximate the source canvas grayscale/color-matrix and half-size silhouette blur. The native version reuses the untouched paintings and modulated layers; it does not claim pixel-identical fog/foam compositing.
- The whale uses the original sprite, emergence timing and translucent ripples, but does not reproduce the source's exact rectangular waterline clipping. Path-reveal sparkles are deterministic native draw effects; footstep dust and the source's exact randomized sparkle distribution remain cosmetic differences.
- Map navigation uses native Buttons/panels and the bundled Pixelify/Silkscreen fonts instead of browser CSS/Figtree. The long title menu uses the source bottom-row fallback so it does not obscure the cast. Short title pages and cards use native text wrapping.
- The source's `bd-crunch` credit flag has no producer or repayment interaction anywhere in the supplied HTML/JavaScript. No payment mechanic or state is invented. Credits continue to use the source unpaid default.
- This work does not establish exact cross-device visual fidelity, human difficulty, physical iPhone/Android touch behavior, frame pacing, memory/battery performance, accessibility certification or store readiness. Rendering evidence below is desktop software OpenGL, not a phone benchmark.

## Verification

- Python importer suite: ten passing tests, including original eight regressions and two new map-specific tests. Exact `MAP4` and `GAME` values, source SHA-256, all eighteen original image byte strings, determinism and the no-JavaScript-execution boundary are covered.
- `test_campaign_map.gd`: 26 passing map/data/route fixtures. Covers fresh locks, original graph routing, arrival cards, disabled entries, source near/whole-map camera, drag/pinch cancellation, focus suspension, no reward/progress changes, boss bridge handoff, long-distance hop, disk restoration and malicious/out-of-range presentation state.
- `test_campaign_map_integration.gd`: 42 passing checks using actual `Input.parse_input_event` GUI dispatch. Covers title attract/debounce/help wrapping/library, Worlds and disabled-world controls, stage list, walking, card Play, story Skip, gameplay Map return, housemate selection, drag release over header, OS cancellation, title/development navigation, completed-title layout/credits, cancel/confirm reset, disk read and keyboard controls. Campaign progress and clocks are explicitly seeded where needed; these are interface tests, not proof of objective completion or unassisted full-game runs.
- `capture_map_visuals.gd`: thirteen 1280×720 frames rendered by the real Godot 4.6.3 OpenGL compatibility backend with Mesa llvmpipe. Inspected title/Press start/attract/help/completed-menu/reset, Home, first card, locked and unlocked overviews, housemates, bridge opening and World 2 card.
- Initial visual inspection found a mirrored-sea tiling gap and overlapping card/footer controls. Both were corrected and the capture set rerun. Later inspection caught overflowing help text; wrapping/minimum sizing was repaired and verified in the final capture set. Final renderer log has no script/render errors; the virtual display reports unsupported VSync control.

Capture output is a local QA artifact in `native-artifacts/screenshots/map/` outside the source repository. The reproducible capture script is committed with the native project; it requires a real rendering backend and explicitly rejects headless rendering.

## Explicit character change and stage continuity (2026-11-09)

The map header now explicitly says “Change character”, with a 44px-high touch target. This is map-only and preserves clear, receipt, skill and Kitty progress. The choice is saved and retained across stage loads. In the hidden pair configuration, choosing the existing mate swaps identities instead of disabling the mode or duplicating characters. The UI regression has 47 checks. The full campaign synthetic progression regression has 308 checks, including all 36 stage entries retaining Mei, all 35 intermediate map returns without title/reselection, and all 19 campaign cutscenes. Synthetic progression does not certify input-driven gameplay or phone acceptance.
