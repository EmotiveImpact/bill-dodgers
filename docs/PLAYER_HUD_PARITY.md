# Native player HUD, effects and controls

Implemented source `drawHUD` and ability `hud` from the original HTML as a native screen-space canvas, shared across all six world families. Original painted assets are used without regeneration or downsampling.

## Shared HUD

- Original 66-pixel translucent header and green rule.
- Original idle-frame head crops for all six housemates, names and three highlighted pixel hearts. Damage dims hearts immediately.
- Original 150-by-8 character-coloured special meter. During a special it shows remaining duration; the ready state blinks and displays C or TAP. Original 260ms activation wash is restored.
- Original jar and 120-point Kitty fill. Collected-coin count excludes receipt Kitty rewards. Split Shot, Direct Debit and Wellies use their source `x3`, `DD` and `WB` countdowns.
- Source central stage/checkpoint/skill/warning banners, fade-in through 300ms, hold until 2400ms, then 400ms fade-out, moving warning stripes, and blinking Go arrows. Presentation clocks pause with the game. Later-world event adapters do not duplicate gameplay rewards or sounds.
- Original bottom Jar Thief health bar on stage 1-1, with red/gold hurt/dizzy state. Other stage-specific meters belong to their world renderers.
- A single native Menu button sits below the authored header in solo and paired play. Its pause panel contains Resume, Story, Sound and Level map. Original graphical action icons and the circular special charge/active countdown replace text blocks. See [mobile HUD and menu](MOBILE_HUD_MENU.md) for current layout and verification.
- Header is above world art/night shaders and below controls/transitions/pause. It is hidden for story and menus and never transformed by the world camera.

## Bounded paired HUD

When the explicitly configured `1-1` PartySession fixture is active, the same source HUD reads both runtime actors. The right panel uses its original mirrored portrait, pink P2/CPU name, right-to-left hearts, personal coin count, weapon countdown and right-filled special meter. A CPU uses `READY`; a human second player uses `R` or the native touch label. Shared Kitty remains global, and simultaneous special activations produce one source-style activation wash rather than stacked washes. Drawing does not modify either actor.

Solo and paired states now share one native Menu launcher below the authored HUD, beginning at y78, with status text at y132. No character control appears in gameplay. Inactive or unsupported pair configurations do not display a stale second panel. The latest mobile menu and graphical-button verification is recorded in [MOBILE_HUD_MENU.md](MOBILE_HUD_MENU.md); it does not certify physical-device or complete co-op acceptance.

## Shared visual effects

`shared_effects_renderer.gd` translates source `drawShot`, `drawBill`, `drawFx` and `drawAura`: spinning coins, five-petal flowers, bubbles, folded directional planes, patterned footballs, wrapped sweets, printed banknotes, Coin Rain glints, trapped-enemy bubbles, Ricochet Football trails/shadows, Maya's flower shield, Leo's glider and strings, Mei's rainbow trails, ready ellipses and ground-pound streaks.

Builders are read-only: no simulation changes, RNG advancement or texture/resource cache. Existing per-world enemy projectiles remain routed through their bespoke painters. World-1 enemies now draw before the player, matching the source aura overlap.

## Shared W1/W2 pickup artwork

`shared_loot_renderer.gd` replaces the prototype circles in `main._draw_loot` with original `drawItem`/`coinIcon` artwork. Hearts use the source 27 four-pixel cells, 26 red and one pink highlight; Split Shot and Direct Debit use 40px rounded green/navy badges with a 3px gold border and 15px `x3`/`DD` lettering. The white quarter-alpha pickup glow pulses independently of the 3px bob. Coins use source rectangular gold/light/shadow pixels and the four 60ms spin frames. Items and coins reproduce their separate 120ms/100ms late blink after 9 seconds. Fractional camera offsets are compensated without changing positions or clocks. The builder has no RNG, cache or game-state writes. Other worlds keep their own existing pickup routing. Crates now use the original 68-by-64 shadow body, 62-by-58 wood face, slat, glint and 28px pale question-mark panel with 22px text. Broken crates are hidden. Hit tremble retains the source ±2px bound, but uses a deterministic 60Hz cosmetic hash rather than sampling gameplay randomness during drawing; an explicit visual jitter snapshot is also accepted.

## Source feedback presentation

`visual_feedback.gd` owns source square impact puffs, cardboard fragments, coin sparkles, ability bursts, rising pickup/special text and world-only shake. It has an independent seeded cosmetic RNG; command building never advances time, samples randomness or changes gameplay. Stage load clears it, pause freezes it, and the night overlay shares the same shake transform while the HUD and touch targets stay still. Shake is applied before zoom, matching the source draw order. Its reduced-motion flag is tested, but an operating-system preference bridge is not yet connected.

Guarded production hooks cover ordinary enemy shot hits/deaths, crate breaks, wall/floor bill impacts, coin and heart/weapon pickups across all six combat families, player landing/hurt, all six special activations and Maya's final flower burst. W6 floating text is routed to its existing `world_six` owner rather than rendered twice. Captain's white hit/pink valve puffs, Crew/defeat text, fragments and shake now consume his presentation events without repeating damage, rewards, sounds or combat RNG.

The W4 capture exposed a separate inherited mirror defect. Godot mirrors a negative-width destination rectangle in place; translating its x by another tile width had left alternating gaps and overlapping paintings. `holiday_renderer.gd` now preserves each source tile's x while mirroring its width. Actual before/after frames confirm the coast, islands, beach and jetty are contiguous. The broader mirror correction is owned and tested separately by the texture-mirroring worker; see that worker's framebuffer comparisons. The dark rectangle directly above Captain's head is his authored hat band, not missing sky. His source Crew! position (`ground - 330`) falls behind the shared HUD in the captured camera and is deliberately not moved.

## Controls

`touch_controls.gd` separates visual style from digital side-scroller actions. The selected translucent joystick has a neutral center, single-thumb diagonals and independent graphical right-side actions. A Classic cross remains an explicit alternative test path. Active contact tracking survives dragging through neutral or across GUI controls; release, focus loss, pause and resize clear the inputs.

A provisional reference-style joystick is implemented for comparison, but Classic remains the default until the user confirms a replacement. The joystick has a radial dead zone, eight direction sectors, an anchored travel zone and clamped translucent thumb grip. It retains one steering thumb while separate fingers shoot, jump or use power. Up aims; down ducks; jump remains separate. It does not silently change movement speed or the source physics.

## Verification

Latest isolated native Godot 4.6.3 headless runs:

- `test_player_hud.gd`: 200 checks. Source contracts, actual damage/receipt pickups, all six characters/world families, active/ready state and flash, WB countdown, boss bar, CanvasItem callbacks, safe margins and story/pause/menu lifecycle.
- `test_party_hud.gd`: 50 checks. Source paired anchors/crops/colours, independent hearts/coins/power, mirrored special charge and CPU label, single activation wash, read-only actor snapshots, actual CanvasItem draw, safe single-menu placement and correct solo restoration.
- `test_shared_effects_renderer.gd`: 80 checks. Source geometry/clocks/colours, camera snapping, auras, ghost suppression, RNG/state purity and reset lifecycle.
- `test_hud_notifications.gd`: 42 checks. Source banner geometry, timing, opacity, warning stripes, Go blink and door duration, all six stage introductions, checkpoint/boss/Captain hooks, pause and reward purity.
- `test_touch_controls.gd`: 175 checks. Classic and joystick sectors, neutral, real dispatched mouse/touch drags, simultaneous actions, thumb ownership, release and safe layout.
- `test_native_audit.gd`: 119 checks. Existing independent GUI-crossing/input audit still passes.
- `test_shared_loot_renderer.gd`: 85 checks. W1/W2 source contracts, heart cells, coin phases, badges, glow/bob/blink clocks, source crate layers and hit tremble, fractional-camera snapping, actual draw callbacks and state/RNG purity.
- `test_visual_feedback.gd`: 88 checks. Source particle dimensions, speeds, gravity, lifetimes, colours, float motion, alpha, shake, reduced-motion flag and pure rendering.
- `test_visual_feedback_integration.gd`: 70 checks. Real six-world callbacks, no combat RNG drift, Captain reward isolation, pause/reset and night-overlay/HUD separation.
- `test_holiday_renderer.gd`: 153 checks, including actual destination-rectangle contracts and contiguous mirrored coastline tiles.
- Focused regression reruns also passed: combat56, supermarket109, festival146, holiday runtime164, World5 integration197 and World6 host seams27. These are focused fixtures, not full-game coverage.

These tests are not physical-device certification. Notches, orientation, thumb comfort and export performance still require actual phone testing.

## Actual rendered captures

All paths below are in the sibling `native-artifacts/screenshots` directory, outside exported content.

- `bill-dodgers-restored-hud.jpg` and `bill-dodgers-hud-active.jpg`: earlier actual native gameplay captures. These predate the new controls and shared effects.
- `shared-vfx/native-hud-vfx-{jp,maya,ama,leo,theo,mei}.png`: visually inspected native viewport fixtures exercising actual production draw paths. The on-screen label identifies scripted test state, with two hearts, £65 Kitty, 60 collected coins, a pickup timer and active specials.
- `shared-vfx/native-hud-warning.png` and `native-hud-go.png`: native source banner and Go-arrow fixtures.
- `shared-vfx/native-boss-hud.png`: native fixture showing Jar Thief's bottom health bar.
- `shared-vfx/native-menu.png` and `native-credits-midpoint-fixture.png`: current native menu and synthetic all-36-clear credits at 34% of the scroll, captured for the integration owner. No personal save was changed and this is not evidence of a completed playthrough.
- `shared-vfx/native-controls-classic.png`, `native-controls-joystick.png`, `native-controls-joystick-held.png`: actual native control comparison fixtures. The held joystick frame shows simultaneous steering/aim and SHOOT input.

- `feedback/native-loot-1-1-fixture.png` and `native-loot-2-1-fixture.png`: visually inspected production W1/W2 pickup and crate art, with all four coin spin frames shown using explicitly held fixture clocks.
- `feedback/native-feedback-shared-fixture.png`: actual native Maya burst, crate fragments, shot impact and pickup/special text.
- `feedback/native-feedback-captain-before-skyline-fix.png` and `native-feedback-captain-fixture.png`: same native Captain fixture before/after the W4 mirror repair. Both are genuine viewport captures, not composites.
- `party/native-party-hud-p2-fixture.png` and `native-party-hud-cpu-fixture.png`: visually inspected actual paired header and relocated native controls, with independent actor hearts, coins, weapons and special meters. Their labels identify synthetic bounded `1-1` fixture state, not a completed co-op playthrough.

The fixture runners are `godot/tools/capture_feedback_visuals.gd`, `godot/tools/capture_native_visuals.gd` and `godot/tools/capture_party_hud_visuals.gd`; they refuse the headless renderer. Captures use a real GL Compatibility viewport at 1280x720, not image mock-ups. They demonstrate rendering, not unscripted gameplay or phone validation. The capture host used dummy audio after its unavailable ALSA device, so these runs make no audio-quality claim.

## Remaining parity scope

The shared HUD and effects do not certify complete visual parity. The following source-backed omissions remain outside this checkpoint:

- W1–5 receipt-found floats, source fall-recovery dust/text and additional scene-specific hints still need their event hooks. W6 receipt and world floats already have their own implementation.
- `startSpecial` is covered, but ongoing Mei sugar and Leo glider particle emission, Maya block bursts, several movement-skill dust/bursts and source stage-clear confetti are not yet covered by this feedback module.
- W1 Jar Thief backup/dizzy/defeat/stomp feedback and Binman-specific event particles need comparison. W2 security/trolley/scene text and W3 tie/wellies/miniboss/harvester feedback are not certified by common enemy hooks.
- W4 Captain charge spray is not yet emitted. Other holiday foe splash/banana/towel/melon/hold feedback still needs its own source event audit.
- W5 removals, sofa/mimic, lift and King-specific floating messages/particles need event-level comparison.
- W6 source mini/flier/SirCharge particles and shake are residuals separate from the already completed world floats: hit puff4, flier fragments/leaf scraps, mini death shake14/three fragment bursts, fee/rock impacts, SirCharge phase/charge/slam/defeat feedback. No gameplay work is implied.

Settlement/title/map screens are separate from this HUD work. World-specific receipt/timer/progress/boss indicators belong to their respective renderer owners; their latest reports are authoritative. Physical-device layout, thumb comfort, orientation and performance remain unverified. The paired panel is restricted to explicitly configured bounded native integration fixtures; solo presentation remains unchanged.

## User-selected joystick default (2026-11-09)

The translucent circular joystick is now the production default, following the user's explicit correction. Classic cross remains only an optional implementation/test path. Eight sectors retain original digital movement: up aims, down ducks, and jump is independent. A captured thumb may leave the base without losing ownership; entering native HUD controls suspends steering without activating them. Release, cancellation, focus loss, resize, pause and level change reset contacts. Touch suite: 175 checks; independent input audit: 119 checks. Actual desktop OpenGL captures are `native-artifacts/screenshots/latest/native-joystick-default.png` and `native-joystick-active.png` outside the repo. These are not physical-phone evidence.
