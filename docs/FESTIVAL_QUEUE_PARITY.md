# Queue jump runtime extension (3-2)

Scope: native extension, production shared-runtime integration and source-contract tests, not a claim that the complete game, device build, visual parity, or a full 3-2 playthrough is finished. Original HTML/assets/imported JSON are unchanged. Production dispatch is now integrated by the parent in `world_three.gd`/`main.gd`; this extension does not register a playable capability itself.

## Sources and exact behavior

`game/3-2/index.html` is the source of truth. Coordinates are absolute feet in native code; seconds replace source milliseconds. The imported `level` and `l3` objects are consumed without mutation.

- Lines 631–652: levelT advances **before** player physics and camera. Auto camera has no ordinary-follow acceleration/lock recurrence. At current-frame time strictly >1.8 seconds, advance by 140 px/s, capped at world width30000 minus view738 =29262. Wiping, a living boss, non-play state or an existing end timer suppress auto movement. A down boss allows scrolling but still blocks ordinary completion while its object exists. Hearts0 does not suppress this camera branch before final all-down resolution.
- Lines 1175–1182: carry is grounded-only and uses the shared cached surface/reacquisition implementation. Five crowd surfaces are **solids**, top442, conveyor120 px/s, not moving one-way decks. Carry happens after voluntary/knockback displacement and before wall and old-camera clamps. No conveyor push is applied to bots, coins or crates. Squash checks strict solid interior at feet−10 after the old-camera clamp and calls ordinary shared recovery, including forced normal hurt. It runs during warmup and wipes too.
- Lines 382–387,436: fall triggers strictly below782. Shared recovery clamps safe x to camera+70..camera+WV−70, searches60 candidates in20px steps with strict30px solid inset, then source fallback. It clears old invulnerability and applies ordinary hurt rather than an instant death. The six gaps are absent solid geometry, not extra damage volumes. A narrow80px barrier can be skipped by the20px search if no sample meets both strict insets.
- Lines 1305–1307: six banners `[1837,1987]`, `[6956,7106]`, `[10972,11122]`, `[17506,17656]`, `[21982,22132]`, `[27161,27311]`, underside362. x coverage includes both endpoints expanded10px. Hit requires feet−height×(.6 for act=crouch, otherwise .86)<362 and feet>322. Both vertical comparisons are strict. Source uses final animation action, not raw down input. Ordinary hurt invulnerability/ability guards remain in the host.
- Shared scene/checkpoint: living player x strictly>14300 triggers the actual labeled iris, even with live bots/active waves in auto stages. Checkpoint heals to3/inv1.5s in the same late pass. The existing render-phase transition teleports camera to15300 after1.43s, preserving current screen-relative player offset; opening starts1.57s and finishes2.17s. Geometry landing/clearing enemies and shots/state preservation remain shared. Scene creation is not immediate teleport.
- Lines 1295,1327: camera notices at15300 (“Crowd surf!” / “Ride the crowd and keep up”) and27762 (“Nearly at the stage!” / “Don't let them get away”), once each. The visual runner clock advances only when endT is set. Source1136's `min(WV−70,WV−70+endRun*.4)` fixes the runner at WV−70; it is presentation, not a chase target or kill gate.
- Lines 657–668,1182: existing festival combat dispatches unsorted wave entries in source order, finishes auto waves once entries are consumed, and does not lock the camera. All15 waves remain authored. Completion at camera>=29260 ignores wave completion/live ordinary bots; it still needs no boss object, no configured boss/noEnd. Existing runtime starts end timer at.001, adds currentdt immediately, and clears strictly>2.6 seconds. No wave-kill or jar-catch requirement may be added.

## Stable integration hooks

Instantiate `festival_queue_rush.gd` as the shared runtime's composed stage extension, call `reset(host)` on every run, and expose `snapshot()` under runtime `stage_data`. Do not reset on pause or Continue. The shared runtime is the clock, identity and run-generation owner. Extension guards call `runtime._can_step(host)` so pause/gameover freeze; an attested final base-clear frame can still run late hooks. All auto scrolling additionally requires mode=play.

1. `auto_displacement(dt,host,runtime,frame_elapsed)` returns raw displacement. Until the shared clock is moved to frame start, pass `runtime.level_time + dt`. The host applies `min(world−WV,camera+displacement)` and **does not run ordinary follow at all**, including warmup, wipe and ending. Preserve vertical-follow ordering separately; don't zero source camera velocity just for auto.
2. `squash(host,runtime)` directly after old-camera clamping and before drop/jump/gravity. It returns whether shared recovery ran. Existing carry/recovery methods are reused, not cloned.
3. `scene_can_start(host,runtime)` provides the auto busy bypass inside existing scene triggering. Keep strict living-player crossing, one-shot flags and real generation-guarded wipe callback. Don't replace the complete scene predicate with this method alone.
4. `events_tick(host,runtime)` immediately after shared scene-trigger pass, before authored coins/timer decrement/checkpoint. It sets `host.status` and optionally emits `host.festival_event({banner,sub,say})`. Notice at the scene destination occurs on the following late pass after the render callback, not retroactively.
5. `banners_tick(host,runtime)` immediately after shared checkpoint, before fire/movers/late bosses. The primary-player adapter uses `host.player_animation`, height, position and `hurt_player(x+40)`. `banner_hits(row,feet,height,action)` is pure and available to any future participant adapter. This module does not claim implemented network/local second-player physics.
6. `end_ok(host)` replaces only the ordinary wave-completion predicate for3-2. Shared objective retains its !boss, distance, mode, noEnd/configured-boss and end timer checks. Do not call ordinary objective and then override its result, which would already mutate its clocks.
7. `late_tick(dt,host,runtime)` at the end of levelUpdate advances end_run, including the attested final clear base frame. `snapshot` gives copied end_run/events_done/duck state. Rendering never advances it.

### Player-order edge requiring production coverage

The original updatePlayer captures `locked` before squash/fall. Recovery can then set a new hurt lock, but the current frame's drop/jump/fire/action decisions use the earlier cached value. Existing main previously reread current `hurt_lock` after recovery. Parent production integration now preserves cached pre-recovery lock for base W3 jump/fire/animation while post-ability/skill adapters still see the new lock. Real-main tests owned by the parent cover this; this shared-runtime suite cannot alone prove main control ordering.

## Verification

`godot/tests/test_festival_queue_rush.gd` passes100 assertions: exact source tokens and fixtures,100-frame warmup recurrence, cap and all auto gates, five shared solid-conveyor carries/airborne rejection, six actual holes, strict squash and shared recovery, all six banner boundaries/action/invulnerability, actual inherited iris/checkpoint timing and relative landing, notices, reset/pause/final-clear continuation, metadata immutability. Floating position comparisons tolerate.002px because Godot Vector2 uses32-bit components; timing and logical boundaries are tested independently.

The suite now uses production WorldThree directly and its owned `queue_rush` controller: no supports override, scene-busy bypass override, or duplicate manual event dispatch remains. The100-frame recurrence calls the production auto wrapper; inherited late passes dispatch notices/banner damage/runner clocks. Five new actual objective checks cover distance, down-boss rejection, livebot/incomplete-wave exit, exact2.6s boundary and one-shot clear. It does not clone objective/camera/scene logic. Actual main controls, campaign/save/menu capability, wave integration, rendered notices and full-route clear still need the separate production integration suites.

Run with isolated HOME/XDG (no shared user data):

```sh
mkdir -p /tmp/queue-godot-home /tmp/queue-godot-data /tmp/queue-godot-config
HOME=/tmp/queue-godot-home XDG_DATA_HOME=/tmp/queue-godot-data XDG_CONFIG_HOME=/tmp/queue-godot-config \
  /usr/local/bin/godot --headless --path godot --script tests/test_festival_queue_rush.gd > /tmp/queue-test.log 2>&1
rc=$?
cat /tmp/queue-test.log
test "$rc" -eq 0 && ! grep -E 'SCRIPT ERROR|Parse Error|ERROR|FAIL:' /tmp/queue-test.log
```

A Godot exit0 alone is never a pass. No publication, install, device signing or account changes are part of this extension.
