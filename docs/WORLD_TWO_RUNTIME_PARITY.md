# World 2 runtime: parking stage 2-1

Current extension: 2-2 through 2-5 and 2-S now use this runtime alongside parking. The sections below retain the initial parking contract; shared gate/floor/drop mechanics and fresh drop-counter cleanup are documented in SUPERMARKET_HAZARDS_PARITY.md. Host integration uses a separate painter per stage and live shared surfaces for every query.

Implementation date: 2026-11-09. This document covers `world_two.gd` and its isolated runtime tests. It does not by itself certify the integrated main scene, combat/renderer, six-housemate completion, device input or an exported build. See the separate integration/run reports for those results.

## Scope and evidence

The executable `game/2-1/index.html` and `game/polish.js` were read directly, not inferred from imported data or the implementation plan. Source files are unchanged. W1 remains separate. The runtime supports **only 2-1**. Imported JSON is never mutated: static surfaces, scenes and all hazard tuples are deep-copied on reset.

Source anchors:

- `2-1:315–334`: surfaces, `landOn`, `below`, `wallClamp`, `insideWall`.
- `2-1:379–388,408–447`: damage, safe recovery and movement.
- `2-1:633–673`: camera, waves, timed end, deferred all-down resolution.
- `2-1:738–841`: world initialization and ordered late update.
- `2-1:1070–1100`: receipt geometry/reward and draw offsets.
- `2-1:1115–1137`: scene gate and callback.
- `2-1:1170–1289`: parking-specific hooks/art.
- `polish.js:109–163`: labelled iris closes 520ms, holds 1050ms, opens 600ms; midpoint callback at 1430ms, total 2170ms.

Native coordinates are absolute feet, pixels/second and seconds. Source velocities use pixels/ms; the live native integration must cap simulation delta to 34ms. The isolated tests sometimes pass large delta deliberately to verify single-spawn and exact threshold contracts, not to model a real rendering frame.

## Host API and order

`reset(host, seed=21)` begins a fresh run. `invalidate_run()` cancels any pending transition when leaving or loading a run. **Continue never calls reset**. It restores host hearts/invulnerability while preserving scene, waves, positions, elapsed time, checkpoint, authored rows and trolley batches.

Queries are `surfaces(host, skip_platforms=false)`, `land_on(host,x,old_y,new_y,skip=false)`, `below(host,x,y)`, `wall_clamp(host,from_x,to_x,feet)` and `inside_wall(host,point)`. Each live surface is a stable `{row:[x0,x1,top],plat:bool}`. The combat adapter can store its row reference. Car roofs are one-way platforms; neither car art nor autonomous trolleys become solid bodies or standing surfaces.

The player phase uses `base_displacement(dt,host,move)` for the unmodified parking speed of 270px/s, separate from knockback and character bonus motion. `after_motion(host)` remembers interior solid safe positions. `recover_from_fall(host)` clamps the saved x into current camera bounds, searches right in 20px steps, and uses the highest acceptable surface. Thus recovery may land on a car roof even though only solid-ground positions are saved. It clears invulnerability before normal hurt, then clears knockback.

The camera uses `camera_cap(host)`. After combat waves, call `objective_tick(dt,host)` before enemy/projectile/pickup passes. Returned `ending` and `clear` events are single-shot. All waves must be done and camera must reach `level.w-view_width-2`; timer starts at 0.001s and adds the initiating frame's delta, clearing only strictly after 2.6s. Autonomous hazards do not block waves or the objective. Source checks play state rather than living-player count at this point; final all-down handling belongs to the host.

After generic combat pickups, `after_pickups(dt,host)` runs this exact supported-stage order:

1. Advance world elapsed clock; clamp/trigger scene gate.
2. Repair embedded non-pop/non-drone bots onto the first eligible solid, updating their segment.
3. Full-heal/revive checkpoint.
4. Spawn authored rows and maintain resting authored-coin age.
5. Spawn/move/hit/cull autonomous trolleys.
6. `host.combat.late_carts(dt,host)`, then `late_drones(dt,host)`.
7. `host.collect_level_pickups()`; remove dead hazard entities.
8. Advance a pre-existing wipe and queue its midpoint callback.

After late ability effects and ghost-shot expiry, the host calls `finish_frame(host)` to apply a queued callback. Receipt pickup remains host-owned, with World 2 source feet threshold `y-30` and draw center `y-40`. Receipt coordinates remain `(80,482)`, `(3920,269)`, `(12120,269)`; the first is behind start x300. Persistence/index adaptation and replay-reward policy are integration concerns, not implemented by this module. `intercept_shot(host,bullet)` returns false because 2-1 has no button/boss shot target and autonomous trolleys are not shootable.

## Lift, checkpoint and clocks

Before transition the camera caps at 7162; the player cannot pass x7600. Transition requires a living player at x≥7550, no active wave anywhere, and no unfinished wave at/before the cap. A near-cap hint uses the authored “Take the lift down!” text. The trigger frame sets wipe time to zero, matching the source first rendered wipe frame.

At 1.43s, `finish_frame` increments scene index and moves the player to x8020, choosing the highest destination surface. It resets velocity, sets grounded, revives a down player to three hearts, pops bots strictly left of x7920 without normal kill rewards, clears both player and hostile bullets, advances camera to at least7860, and resets camera speed/y. Source safe position, on-platform and ability caches are retained. The callback does not rerun pickups or checkpoint retroactively: those see the new destination on the next late update.

The checkpoint uses camera midpoint≥7700, not player x. It heals a living player to three without altering existing invulnerability; a zero-heart player also receives two seconds of invulnerability. The host must defer knockout so this late heal/revive can take effect. The checkpoint is a one-time heal, not a respawn coordinate.

`wiping` describes the **whole 2.17s visual interval**, unlike source `LVS.wiping`, which becomes false at the midpoint while `BD.wiping` remains true. `wipe_midpoint_done` distinguishes those states. Ordinary simulation and input continue during the iris. An actual pause/menu/over mode freezes all module clocks and callbacks. Continue resumes a suspended transition; a fresh run starts clean.

The runtime captures iris focus in source 960×540 canvas coordinates: start when triggered, end on the first simulation frame reaching1.57s; x is clamped to22–78% of canvas width, y is60%. The renderer reads the state without physics or RNG side effects.

## Authored coins and trolleys

All 13 rows produce exactly73 coins, when row-start x is strictly less than camera+738+260. Rows emit once, evenly spaced with the authored sine arc, zero velocity, age0.3s, rest/keep flags. Late age maintenance caps only resting keep-coins at2s. Generic combat pickup/filter runs first, so already-culled/dead/behind-camera coins are not restored and airborne coins are not artificially immortal.

Batch tuples `(at,count,gap seconds,direction)` are `(2600,3,1.3,-1)`, `(5200,5,.75,-1)`, `(11300,4,1,-1)`, `(13900,3,1.1,+1)`. Activation immediately spawns one; each update can emit at most one per batch, even for large delta. Failed support queries consume the attempt. New trolleys move in the same late pass. They start90px beyond the incoming screen edge at360–440px/s, fall with3000px/s² gravity, and reverse velocity by−.6 on side-wall collision **without correcting x**. Contact requires strict horizontal distance<46 and feet in `(trolleyFeet-86,trolleyFeet+20)`. They cull beyond camera−300/camera+view+400 or the fall line.

Entities are public `entities`: batches have `k:'tspawn',at,n,gap,dir,t,done,on`; live hazards have `k:'trolley',p:Vector2,v:Vector2,t,dead`. Time is seconds. `coins_done` keys are original hazard indices. Additional renderer state is `scene_index,wiping,wipe_elapsed,wipe_midpoint_done,wipe_kind,wipe_label,wipe_focus_start,wipe_focus_end,checkpoint_hit,elapsed,end_time,run_generation`. `snapshot()` deep-copies entity data for tests/tools.

## Stockroom scene policy

The 2-3 source L overrides are explicit: scene view120, landing offset0, camera offset200 and landing query476. This caps the initial camera at8292 and lands the player at8910/482 with camera8710/0, not420px ahead or on the highest rack. The default300/420/160/−9999 policy remains unchanged for parking and aisle. Runtime queries fall back to below(−9999) only if the preferred landing query has no surface.

## Deliberate native repairs and omissions

- The asynchronous source draw callback is implemented as a simulation-time queue, applied after late ability effects and final all-down resolution, preserving the source Knocked out/Continue decision for fatal midpoint damage. A pending native callback freezes while paused or knocked out, then resumes on Continue; the browser instead can teleport behind its game-over screen via wall-clock drawing. This timing-only lifecycle adaptation is intentional. No wall-clock timer can teleport while paused. Run-generation, current-level and host-identity checks reject stale callbacks after exit/restart, including a restart into the same level.
- Millisecond-inclusive timer thresholds use a 1ns comparison tolerance to avoid floating-point drift introduced by converting milliseconds to seconds. The strict >2.6s exit comparison is unchanged.
- Runtime RNG is seeded separately from rendering; drawing/screenshot count cannot change trolley speeds. Cosmetic puff/shake/floating text are not simulated here; sound/status hooks and mandatory trolley/iris visuals are renderer/host responsibilities.
- Shared gates/plates/buttons, ice/flour/belts and falling boxes/icicles now run through `hazard_controller`: movement before base physics, gates after coins, drops after trolleys and before late cart/drone motion. The source airborne momentum rule applies outside ice too. The course controller now supplies flame/low/block contacts after drops and before carts, plus source variable automatic camera displacement before waves. Only checkout machinery remains unintegrated. Stages 2-1 through 2-5 and 2-S may clear through this module.
- Co-op/CPU schemas remain intact in source data and combat wave input. This runtime host is solo: multi-player movement, scene destinations/revival and pickup loops are not yet native multiplayer support.
- Main receipt persistence/replay policy, combat ability compatibility, full-stage legitimate runs, renderer appearance, Android/iOS input/performance and packaged builds need their respective integration/release checks. This isolated suite is not a gameplay-completion claim.

## Verification

`godot --headless --path godot --script res://tests/test_world_two.gd`, with isolated HOME/XDG directories, currently passes **101 checks, zero failures** on Godot4.6.3. Coverage includes exact geometry/recovery, source inventories, late phase ordering, scene gating/callback/visual timing, full-heal and same-frame revive, paused and stale callbacks, fresh reset versus Continue, immutable metadata, future-schema retention, authored coins, all trolley batches/strict hit boundaries/physics, and timed exit. `git diff --check` is clean. The parent integration owner registers this suite in aggregate verification and owns final packed-runtime results.
