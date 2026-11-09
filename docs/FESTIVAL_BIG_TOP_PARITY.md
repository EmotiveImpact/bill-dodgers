# Big top runtime extension (3-4)

Implemented `godot/src/festival_big_top.gd`; tested with `godot/tests/test_festival_big_top.gd`. This is an isolated mechanics milestone, not a device, whole-stage navigation, or visual-parity claim. The integration owner controls native capability promotion.

## Integration contract

- Construct `BigTop` once in WorldThree. Call `reset(host, runtime)` **after** all shared live surfaces have been created. A fresh native level load resets geometry and samples six seeded spotlight phases. Do not call either reset on Continue: preserve the existing runtime.
- Expose `big_top.spots` or a `spots` getter for the painter, and `stage_data = big_top.snapshot()`. Spotlight records are `{x,y,on,hp,a,t}`; t is seconds. `a` remains the source's unused initialized zero. Snapshots are deep copies, never collision state.
- Call `events_tick(host,runtime)` after shared scene updates, before authored coins/checkpoint. This emits the one-shot “Trapeze!” event at camera3900.
- In the late phase after checkpoint/banner/fire damage, call `movers_tick(host,runtime)`, then `spotlights_tick(dt,host,runtime)`, then the shared mini trigger. Ordinary shots and their solid/camera cleanup MUST already have finished. Do not move platforms before player motion.
- Shared `carry_player` consumes the preceding late phase's dx/dy, and shared collision/drop/spawn/ability queries must all use the same live dictionaries and arrays. The extension never replaces them. Preserve arbitrary surface properties.
- Shared checkpoint, finds/card, authored coins, fall recovery, ordinary objectives, combat and boss controller remain the sole owners. No duplicate engine or alternate victory gate is implemented here.

## Exact source evidence and behavior

Source: `game/3-4/index.html`, declarations729–730; player carry1175–1179; finds1262–1282; reset1285–1290; late update1294–1327; ordinary shots528–547. See the shared source audit in `WORLD_THREE_IMPLEMENTATION.md`.

The stage has15 solids and49 one-way platforms. Four platform indexes10–13 are width130 trapezes, each `nospawn:true`, amplitude90px horizontally and26px downward, period3200ms, phases0/1.4/2.8/4.2. No authored platform has `nodrop`; generic live `nodrop` remains respected by shared carry/drop rather than invented on trapezes.

Late transform uses the source literal6.283, not TAU:

`k=sin(level_time_seconds / period_seconds * 6.283 + phase)`

`x=authored_x+amplitude_x*k`, `top=authored_top+amplitude_y*abs(k)`.

The deltas are current minus previous coordinates, not speeds. Bot carry requires truthy dx, no hop, and state other than pop, then applies dx and snaps absolute feet to top. It does not apply isolated vertical movement, and does not carry coins/items/crates. Stable `surface` and `segment` references remain valid. Source player carry first checks x against the *new* platform bounds and feet against previous top; a player left outside new x bounds reacquires rather than automatically receiving carry.

Independent reference for first trapeze at0.8 seconds: x0=4209.999999903422, top=-202.0000000279004, first dx=89.999999903422, dy=25.9999999720996. Tests exercise these reference values and retained array/dictionary identity.

Six spotlight centers are(2800,-448), (3600,-448), (5900,-508), (7100,-508), (9900,-558), (11000,-558). Each starts off with2HP and independently randomized t in[0,6) seconds. Every frame increments t before collision/dazzle. Switch hit rectangle is strict `abs(shot.x-x)<26 && abs(shot.y-y-4)<26`; the actual center is four pixels below y. Each surviving player shot decrements HP by one regardless of damage or ghost flag. Hostile/dead shots never count. The inner loop deliberately continues after activation: several overlapping shots in the activation frame can make HP negative and repeat the power/float event. On subsequent frames an on lamp no longer intercepts. Mark consumed shots dead without early erasure, matching late source behavior.

Beam geometry uses bot feet minus60px, requires dy>0 and `abs(atan2(dx,dy)-sin(t/0.9)*0.6)<0.2`. There is no range, camera, solid occlusion or ground condition. Pop bots are excluded. Active beams refresh `dz=max(dz,0.25)` every late frame. Existing combat decrements daze/skips AI and doubles ordinary damage while positive. Activation cannot retroactively double damage already resolved earlier that frame. Source ghost shots born in the final ability pass normally wait until next frame.

Source `reset3()` resets on/HP/events but preserves initial random spotlight t and mover positions/deltas. `reset_round()` models that source same-page operation. Native fresh level loading deliberately starts new scene geometry and phases; Continue preserves everything in place. Neither mechanism writes runtime state into imported META.

## Shared policies and source quirks to retain

- Ringmaster is shared Tout mini configuration,60HP solo/80HP pair, cam8300, late trigger8040, absolute ground feet482. It is not an upper-rig boss. No `l3.stage` exists, so do not invent a stage-hop destination.
- Checkpoint triggers strictly beyond x5600, with flag presentation at y=-278. It fills hearts/revives but does not teleport players or make a new respawn rule.
- Ground-pound card is(5700,-358), through the parent's shared skill-card/find/save path. Receipts are exact centers(3900,-278), (7900,-218), (12300,-438), worth no money. Decorative bobbing never shifts pickup bounds.
- There are20 authored coins in three rows. Fall threshold is882. Shared source vertical camera follows grounded-history feet; airborne height alone is not an alternate climb objective.
- Ordinary clear requires final horizontal camera distance, completed waves, and no boss (including mini down celebration). There is no exit-altitude, skill-card, receipt, or mandatory-miniDone gate. “Out through the roof!” is source presentation, not a new physical win condition.

## Verification

Godot4.6.3 headless, isolated HOME/XDG directories, command:

`HOME=/tmp/big-top-home XDG_DATA_HOME=/tmp/big-top-xdg /usr/local/bin/godot --headless --path godot --script res://tests/test_festival_big_top.gd`

42 checks passed. Output was scanned for `SCRIPT ERROR`, `ERROR:`, `FAIL:`, and leak warnings, not just process status. Tests cover source inventory, deterministic phases, stable live geometry, exact transform reference/deltas, bot and next-frame player carry, nodrop/airborne behavior, reset distinction, strict switch bounds, enemy/dead exclusion, ghost damage semantics, excess hits, immediate/continuous dazzle, strict beam bounds, unlimited beam range, already-on bypass, camera event, pause, detached snapshots, mini config, checkpoint/find coordinates, absence of invented gates and metadata immutability.

Parent acceptance still needs full-host projectile precedence (enemy/boss/crate/solid/camera before lamps), daze double-damage timing, source-style high-camera culling, full mini lifecycle/checkpoint/card save flow, and reachable whole-course/platform navigation. Those require shared host integration, deliberately outside this worker's file ownership.
