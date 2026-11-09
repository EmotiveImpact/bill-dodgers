# World 4 native implementation and verification

## Scope

The seven World 4 stages use the imported original stage metadata and original paintings/sprite sheets. The implementation is split into:

- `godot/src/world_four.gd`: source surfaces, carrying, water recovery, gates, checkpoints, hold/bonus objectives, receipts, early Dash seam, boss/jar sequencing and run lifecycle.
- `godot/src/holiday_combat.gd`: source ordered waves, ordinary bots, player projectiles, enemy bills, crates, pickups and ordinary combat clocks.
- `godot/src/holiday_foes.gd`: suitcases, falling luggage, Bailiff, jet skis, inflatables, four-seat banana boat, melons, towel grabbers and the two spawning controllers. These are deliberately separate from ordinary bots.
- `godot/src/holiday_renderer.gd`: original scene art, platforms and maritime actors, pickups and world-specific HUD.
- `godot/src/holiday_captain.gd` and `holiday_captain_renderer.gd`: the full Captain encounter, procedural flamingo and original thief rider, and physical jar. See `HOLIDAY_CAPTAIN_PARITY.md` for the detailed boss contract.

The source inventory and executable ordering are recorded in `WORLD_FOUR_IMPLEMENTATION.md`. That earlier audit predates implementation. Its proposed-repair decisions are resolved below. The shared integration in `main.gd`, dispatch registry, save flow, shared character abilities and presentation overlays is owned separately.

## Stage coverage

| Stage | Implemented mechanics |
| --- | --- |
| 4-1 | Both airport scenes, nine fixed suitcase ambushes, four conveyors, ordered 12 waves, luggage chute, Bailiff, lift, three receipts and delayed exit. |
| 4-2 | Tall old-town route and camera, ten waves, rolling-melon controller, Bailiff, stairs transition and three physical receipts, including the named repair below. |
| 4-3 | Approach waves and gate, four towels, 150-second hold, grab/carry/save/loss behavior, all-towels reset adding at most 40 seconds, half-time Bailiff, £10 per remaining towel and delayed exit. |
| 4-4 | Twelve waves, immediate automatic harbour camera, 23 live bobbing boats, Bailiff pause, water recovery, fade gate, real Dash card, three receipts and delayed exit. |
| 4-5 | Source moving/bobbing pedalo, automatic camera, ten waves, jet-ski safe slots, inflatables, independently damageable banana seats, out-state camera release and delayed exit. |
| 4-6 | Four waves, 17 solo entries, 34-HP Bailiff, three receipts, full 90-HP Captain, all phases/crew attacks, sink, physical jar and normal clear/save. |
| 4-S | Source 258 kept coin positions, seven waves, 100-second clock, eight single-use +8-second gates, multiplier up to nine, source timeout/finish award and clear coin sweep. No automatic Dash unlock. |

The pair-count HP/wave extension branches have isolated coverage. The production test routes are solo, not two-player or CPU-partner certification.

## Integration order and host interface

Coordinates are absolute world feet in pixels. Clocks are seconds, velocities pixels per second. Native `player` and each ordinary bot's `p` are `Vector2`; custom foes store `x`/`y`. Surfaces are live dictionaries, and bots keep their support dictionary by identity.

The integrated base frame increments `host.elapsed`, then calls `world_four.pre_motion` before decrementing invulnerability, hurt lock, power or movement timers. `pre_motion` increments the World 4 source clock, carries actors on the previous-camera deck/bobs/conveyors and performs water rescue. Player movement and shared abilities follow. Camera, ordered waves and objective countdown precede `before_combat`. That hook handles checkpoint/set triggers, receipt/card collection, the W4 early Dash update, hold/bonus clocks, custom foes and Captain start. Ordinary AI, bubbles, projectiles, bills and pickups run after it. `boss_tick` then runs Captain and drains presentation events once; `jar_tick` applies source gravity/bounce and horizontal pickup. `finish_frame` owns the guarded gate midpoint after the base frame. The shared late Dash pass is not repeated for W4.

`family_base_step_active(4)` allows the remainder of the real final base frame after a clear/story transition. It does not allow unrelated future updates while paused, over or on another stage.

Reset creates deck geometry against camera zero before the host's floor query, independent of a previous stage's camera. `seed_pickups(host)` is called after common pickup arrays have been cleared and preserves the source kept-coin initial age of 0.4 seconds. `receipt_position(host, index)` returns raw source feet, except the explicit first old-town receipt repair. The painter subtracts 60 exactly once.

The Captain adapter exposes `.state` and `.hit(point, damage)` for shared abilities; `.state` is the same dictionary as `.boss`. Its own tick is used, never the legacy Jar Thief tick. The source fixed body/valve damage behavior is retained.

## Intentional differences from source

1. **Reachable first old-town receipt.** The original 4-2 metadata places receipt index 0 at `(-300, 482)`, behind the source nonnegative camera and `player.x >= camera.x + 30` clamp. Runtime alone relocates that physical pickup to `(60, 482)`. Original JSON is unchanged. The native saved identity remains 0, matching the rest of native receipt indexing. The pickup adds £5 to kitty and nothing to personal coins, rewards once per run, and can reward again on replay while saved history remains deduplicated. All six characters have an unassisted, left-input-only test from `(300, 482)`. This is a functional repair, not coordinate-identical parity.
2. **Captain ability target coordinate.** Source Captain has `y` but lacks the `fy` expected by shared direct abilities. Native `.fy` follows `.y`, including sinking. This enables valid direct ability targeting without changing fixed one-point body or three-point phase-three valve damage. It is a functional repair, not preservation of source invalid-coordinate behavior.
3. **Gate lifecycle safety.** Native gate callbacks freeze during pause/over and cannot relocate a replacement stage after reset. This intentionally replaces the web wall-clock callback behavior. Source close/label/midpoint/open timings remain 0.52/1.43/1.57/2.17 seconds as applicable.
4. **Native ownership and painting.** Discarded grabbers have mutual towel references detached to avoid RefCounted cycles. Renderers are pure and do not consume gameplay RNG or change flash clocks. The original JavaScript's tracing GC and draw-time mutation cannot be copied literally into Godot.

No source JSON, web page, asset, source wave entry, authored encounter, clear condition or save permission has been edited by this family implementation. Procedural Captain/jet craft/ring drawing is source behavior because the optional dedicated sheets are absent.

## Rendering and presentation

The order is level/finds, crates/items/coins, Captain, ordinary bots, custom foes, jar, players, shots/bills/effects and front warnings/water. The source's final wrapper disables fast foreground parallax and moves any front props behind actors. Native follows that final executable override, not the earlier disabled code.

World 4 owns source hold/bonus/ride HUD, Captain health/name, Go blink and gate iris/label. Original receipts rotate, have four paper teeth and fade for 0.6 seconds after pickup. The source has no receipt-count HUD. Shared player HUD owns hearts, personal coins, kitty and abilities. Guarded `hud_banner` hooks report source gate/checkpoint/hold/set-piece banners. Captain presentation events are drained once to `holiday_event`; SFX and rewards are already emitted by their controllers and must not be duplicated.

CanvasItem submission tests are not screenshots or pixel comparisons. Artwork placement, screen composition, mobile touch overlap, animation feel, particles and shake still require visual/device QA. In particular, a presentation event being emitted is not evidence that a shared particle/shake sink visibly renders it.

## Verification

Run from the repository root with a writable, isolated HOME/XDG directory for saves, for example:

```sh
export HOME=/tmp/holiday-qa/home
export XDG_DATA_HOME=/tmp/holiday-qa/data
export XDG_CONFIG_HOME=/tmp/holiday-qa/config
export XDG_CACHE_HOME=/tmp/holiday-qa/cache

godot --headless --path godot --script tests/test_holiday_runtime.gd
godot --headless --path godot --script tests/test_holiday_renderer.gd
godot --headless --path godot --script tests/test_holiday_lifecycle.gd
godot --headless --path godot --script tests/test_holiday_captain.gd
godot --headless --path godot --script tests/test_holiday_captain_renderer.gd
godot --headless --path godot --script tests/test_full_holiday_runs.gd
godot --headless --path godot --script tests/test_full_captain_run.gd
```

Do not run simultaneous save-writing tests against the same HOME/XDG location.

Latest focused checks with Godot 4.6.3:

- Runtime/combat: **164 checks**, passing.
- World painter: **120 checks**, passing, including actual CanvasItem calls for all stage scenes, eight custom foe types and added HUD/iris/receipt/ring commands.
- Lifecycle: **634 checks**, passing. Most repeated assertions validate the unassisted receipt walk's source camera/clamp on every tick. Also tests replay/history/Continue, far-camera W3/W4 transitions into the pedalo and kept-coin stage, pause/resume and stale wipe invalidation. Death, camera and active-hold setup in these lifecycle checks are explicitly synthetic fixtures, not playthrough evidence.
- Captain controller: **155 assertions**, passing.
- Captain painter: **98 assertions**, passing, including actual CanvasItem execution.
- Captain real-main routes: **6/6**, passing, all source waves/entries, receipts, 90 HP, three phases, crew, rear/charge/throw, sink/jar, clear/save; zero falls. Input-only navigation and attacks with invulnerability as the sole gameplay assist. Masked contacts are reported per run, so this does not establish ordinary-health completion or difficulty balance.
- Non-Captain real-main matrix: **36/36**, passing with exit 0 and no Godot errors/warnings. All six housemates across 4-1 through 4-5 and 4-S. Totals: **363,075 ticks, 330/330 waves, 1,374/1,374 source entries, 108 physical receipts, 30 gates, 36 configured encounters and 36 normal saved clears**. All six physically earned and saved the harbour Dash card. There were **14 normal source fall recoveries**, with no Continue or health edits. Invulnerability is the sole assist, not a difficulty or ordinary-health validation.

Together the two real-main suites cover **42/42 solo routes and all 126 physical receipt pickups**. The five focused suites total **1,171 assertions/checks**. These counts are not interchangeable: route evidence, lifecycle fixtures and isolated controller/painter assertions test different things.

The real-main route tests never teleport actors, delete enemies, fabricate wave flags, damage Captain directly, set completion timers, award pickups or call clear. Normal source gate/fall relocation and game-generated pickups remain part of execution. Steering is character/geometry aware: old-town overlapping stairs require a lower firing lane, pedalo combat crouching must yield to safe deck navigation, and Leo's glider uses held jump input.

Physical Android/iPhone exports, signing/install, actual multitouch, notch/rotation/background/audio, performance/battery and human full-game playthrough are separate release gates and are not claimed here.
