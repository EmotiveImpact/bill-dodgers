# World 3 field runtime parity

`godot/src/world_three.gd` implements **3-1 only**. It does not advertise or enable 3-2 through 3-S. Imported metadata is copied for mutable run state. Source: `game/3-1/index.html`, with labeled wipe timing from `game/polish.js:103–166`. The shared World 3 contract is in `WORLD_THREE_IMPLEMENTATION.md`.

## Coordinates, clocks and host phases

Positions are absolute world pixels at the player's feet. Time is seconds and velocities are pixels/second. Surface `conv` remains in its authored pixels/millisecond units; carry converts it once using `dt * 1000`. Surface `dx`/`dy` and `cam_dx` are displacement per frame.

Required host order:

1. Calculate horizontal base motion with `base_displacement(dt, host, move)` and add knockback separately.
2. Set the intended player position, then `carry_player(dt, host)` **before** side walls and camera-window clamping. `can_jump`, `jump_multiplier` and `allow_drop` control the ordinary source jump branches. Tied prevents normal jumping, not the earlier down+jump drop branch.
3. Resolve gravity/landing/fall, then `after_motion(host)`. This remembers safe ground and captures pre-follow camera x.
4. Follow the camera, then `after_camera(dt, host)`. This sets `cam_dx` and advances `level_time`/`elapsed` exactly once. No W2 scene approach cap applies. `auto_displacement` is zero because 3-1 is not an automatic-scroll level.
5. Ordinary combat waves, then `objective_tick(dt, host)`, enemies, shots and coin/item pickups.
6. `after_pickups(dt, host)` calls `host.collect_level_pickups()` first, starts a qualifying scene, seeds authored coins, decrements cheer/tent shake/tied, checks the checkpoint, and requests the mini boss.
7. Host-owned boss and jar ticks, all-down resolution and late ability/ghost cleanup, then `finish_frame(host)` for a due scene callback. The callback must not move to an earlier gameplay phase.

`host.combat.start_boss(host, cfg)` receives the copied authored mini config. Main records `mini_done = true` when `combat.boss_tick` returns `mini_done`. The combat module clears its boss/camera lock. `boss_event(host, event)` can receive a seconds-valued `cheer` event; the host owns audio. Every boss event forwards to optional `host.festival_event(event)` after cheer is updated; changing boss music back to the normal loop does not stop music.

## Geometry and movement

- All **31** source surfaces are retained in original order: 28 solid ground/bale rows, followed by three one-way van roofs.
- Surface dictionaries contain `row`, `plat` and all authored row properties. In particular, van roofs retain `nospawn: true` and `style: vanroof`. Combat's `surface` and `segment` references remain valid for the run.
- `land_on` uses inclusive x bounds and source `old_y - 1` / `new_y + 0.5` tolerances, choosing the highest crossed top. `below` uses the inclusive `y - 2` tolerance.
- Solid side walls stop 14 pixels short. A top exactly six pixels above the feet does not block. Wall interiors use strict horizontal bounds and `y > top + 4`.
- The six mud spans apply only when grounded, strictly inside a span, and less than four pixels from ground y=482. Mud multiplies movement by 0.55 and jump by 0.84; wellies remove these two modifiers.
- Wristband ties last 2.2 seconds, multiply base motion by 0.45, combine with mud, and block normal jumps even with wellies. Combat applies a tie even if invulnerability prevents the accompanying damage. Ties decrement in the late level phase, including the collision frame.
- Carry retains the source cached-support checks, nodrop property, conveyor conversion and per-frame dx/dy behavior. These are isolated hooks, not a claim that later moving-platform stages are implemented.
- Fall recovery searches from the last interior solid position, clamped into the camera view, stepping right by 20 pixels up to 60 times. It requires a strict 30-pixel inset, falls back to `below`/the first surface, clears invulnerability before normal hurt, and zeroes velocity. A one-way roof can be the recovery landing but never becomes the normal safe-ground cache.

## Coins and finds

Five authored `coinRows` create **29 coins** all at once during the first late level update, including rows far outside the initial view. The formula uses `start_x + i * step`, the exact authored sine arc, zero velocity, `age=0.3`, `rest=true` and `stay=true`. The normal combat pickup controller owns attraction, collection, the `stay` lifetime exception, and rear-camera culling. Runtime does not reseed collected coins or reset their age.

Receipt policy helpers:

- `receipt_position(row)` returns the original authored center. No World 1/2 y offset applies.
- `finds_near(host, point)` requires a living player, `abs(dx) < 42`, `point.y > feet - height - 10`, and `point.y < feet + 20`.
- `receipt_reward()` is **zero**. The host persists the receipt without a currency bonus and allows saved receipts to be found again on a new run, with the renderer showing the prior-save fade.

The three authored positions are `(5060,252)`, `(8700,152)` and `(14100,152)`. There is no skill card in 3-1. The shared movement-skill controller already has the World 3 card contact predicate, but later card stages remain unsupported.

## Checkpoint, scenes and mini boss

The checkpoint is independent of the scene. A living player's **x > 7000** triggers it once per run, fills all supported participant hearts to three and sets 1.5 seconds of invulnerability unconditionally. Camera position cannot trigger it. In the normal solo adapter an all-down player cannot revive themselves by crossing the coordinate. A busy wave can block the scene while the checkpoint still heals that frame.

The Food village scene triggers on **living player x > 7000** only when there is no started unfinished wave, no non-popped bot, and no boss object. Unstarted waves do not block it. There is no player-x clamp, approach-camera cap or W2-style earlier-wave completion condition. The scene is marked done at trigger time; gameplay continues during its visual wipe.

For the labeled door iris: the callback is due at **1.430 s**, opening focus is captured at **1.570 s**, and the visual finishes at **2.170 s**. The triggering update does not consume the wipe's first frame. At callback:

- Camera x becomes **7900**.
- Player x moves by `7900 - old_camera_x`, preserving the current screen offset. It is **not** set to 7900.
- Horizontal velocity becomes zero. For this non-auto level, the nearest destination surface from `view_top - 600`, falling back to `GROUND - 10`, sets feet and zeroes vertical velocity.
- The safe point is updated; all enemies and both projectile types are cleared; camera lock is cleared.
- Camera y/speed, grounded/on-platform/cached support, powers, invulnerability, tents and coins are retained. Finds are not collected retroactively at the destination on the callback frame.

The Wristband seller is requested when camera x reaches **8640**, which is the authored arena camera 8900 minus 260. The exact config includes 60 solo HP / 80 two-participant HP. Existing normal waves do not prevent this request. Active or finished minis do not duplicate.

The ending checks the source condition: camera x at least `15800 - 738 - 2 = 15060`, all ten ordinary waves done, no boss, and neither `noEnd` nor final-boss config. It does not invent a separate `mini_done` requirement. In the real route the mini remains a boss object through its down celebration, blocking the ending until dismissal. The timer begins at 0.001 seconds plus that frame's dt; clear occurs strictly after 2.6 seconds and is reported once.

## Lifecycle and deliberate native reliability choices

Reset/leave invalidates a generation token. Late work rejects different hosts, different levels, unsupported stages and non-play modes. The sole exception is the source final clear frame: optional `host.festival_base_step_active()` attests that its already-started base update may finish the late level phase. Subsequent clear frames remain frozen. A due callback cannot execute after restart or leaving the run. Pause and game-over freeze simulation time; Continue resumes a pending same-run callback. Rendering only reads state and never advances clocks, RNG or transitions.

These simulation-time/run-token boundaries deliberately replace the browser's wall-clock render callback with pause-safe native behavior. The labeled 3-1 timing and game ordering are retained. Helpers accept mutable combat participant records where already used by combat, but this is **not** verification of a complete native co-op mode. The primary-player adapter is the verified route.

## Verification

`godot --headless --path godot --script res://tests/test_world_three.gd`

**139 isolated checks pass** under Godot 4.6.3. Coverage includes actual imported data, original-source provenance tokens, strict geometry/mud/find boundaries, currency policy, seed/order/arc values, tie/carry behavior, checkpoint and mini thresholds, scene gating/relative teleport/timing, camera units, fall recovery, pause/Continue/restart/stale-host invalidation, unsupported-stage gating and one-shot end timing. The source file is read without printing its embedded images. Test saves/config/cache are isolated under `/tmp`.

This runtime suite does not claim a full-route playthrough, touch/controller validation, visual screenshot approval, iOS/Android export, signing, or physical-device testing. Integration, combat, boss and renderer verification are separate suites/reports.
