# Binman Bot: source parity

`godot/src/binman.gd` ports the encounter in original `game/1-6/index.html` without editing that source. Relevant source: ordinary `updateShots` at lines 526–550, inherited `bossDown` at 618, frame order at 666–671, `sceneBossStart/openLid/throwBin/sceneBossUpdate` at 897–954, and ability `zap`, `hitBot`, `hitBoss`, bubble, ground pound and ball helpers at 1342–1347, 1384, 1520–1555. Rendering is a separate module.

## Integration contract

- Instantiate the RefCounted script and call `reset(world_width, view_width, ground_y, player_count=1, random_seed=1)`. World positions are absolute pixels, `position.y` denotes player feet, times are seconds, velocities are pixels/second and gravity is pixels/second².
- `tick(dt, players: Array[Dictionary], shots: Array=[], view_top=0, playing=true)` advances the encounter and returns queued events. Player dictionaries supply `position: Vector2`, `alive: bool`, `height: float` and `crouching: bool`. Height defaults to 180, crouching to false, alive to true. Array indices identify players. `grounded` is not consulted: source damage depends on actual foot height. Invulnerability, shields and health are enforced by the host, not the encounter.
- `shots` is the host's mutable native bullet array. Entries supply `p: Vector2`, `life`, `enemy`, `damage`; `dead` is honored. Bin collisions set `dead=true` and `life=0`. The host removes expired entries. Enemy bullets are not player shots and do not damage bins.
- Run ordinary player-shot movement and collisions against **helpers → boss → crates → walls/viewport** before this tick. Call `hit(position, damage=1)` at the boss step. Its boolean means **consumed**, including a clang against a shut lid. `hit_shot(shot)` is an optional adapter that performs the same hit and marks the native bullet dead. Never put bin hits in this early pass: source bins collide later, in the boss update.
- Boss tick order is delayed throw callback, timers/lid easing/dizzy reset, old waves (including prior-frame rolling-bin markers), each bin's motion → all player collisions → all surviving shot collisions, marker replacement, rain, down/clear check, nearest living target, phase selection and AI, helpers, then boss body collision. A bin is removed on player contact even if the host refuses damage due to invulnerability. Rain uses standing height even during crouch.
- `drain_events()` can be used after a shot hit for immediate effects, especially `kill_bots` on the final hit, before processing subsequent shots. `tick()` drains whatever remains. Do not apply a drained event twice. `down()` is idempotent and supports the source test/debug defeat action; normal defeat calls it through `hit()`.
- `open_lid(seconds)` and `throw_bin(target_position, rolling=false)` expose the source operations for focused simulation. A delayed phase-3 throw targets the current nearest alive player, falling back to the original target position if nobody survives. Reset/down cancels pending delayed throws.

### Public rendering state

`state` contains `x`, `fy`, `hp`, `max`, `state`, `t`, `face`, `flash`, `dizzy`, `waves`, `bins`, `rain`, `next`, `lid`, `lid_t`, `phase`, `called` and `pending_throw`.

States are `enter`, `walk`, `throw`, `roll`, `slam`, `down`. `lid` eases from zero to one. `called` retains the original three entries, although only its first two are used. There is deliberately no Jar Thief `jar`, `dz`, `stomp` state, pickup or dizzy-phase compatibility.

- Waves: `x`, `vx`, `t`; rolling-bin markers also have `bin=true` and `vx=0`. Markers are for CPU jump awareness and source collision behavior; render only real waves.
- Bins: `x`, `y`, `vx`, `vy`, `rot` (radians), `roll`, `hp`, `t`.
- Recycling rain: `x`, `y`, `vy`, `t`, `k` (0 blue, 1 green, 2 grey), optional `dead`.

### Events

`warning`; `roar` (`shake=10`); `throw` (`position`, `rolling`); `stomp` (`shake=14`); `spawn_bot` (`side` l/r, `kind`); `backup`; `furious`; `hurt_player` (`player_index`, `source_x`, diagnostic `hazard` wave/bin_marker/bin/rain/body); `hit` (`position`, `boss_hits=1`); `clang` (`position`, `label` random 15%); `bin_hit` (`position`); `bin_land` (`position`, `shake=5`); `rain_land` (`position`); `bits` (`position`); `drop_coins` (`position`, `count`); `kill_bots`; `down` (`shake=16`, inherited `bus_delay=1.5`); `clear`.

The host owns sound, particles, status/float text, helper creation/death, score/coins and progression. Suggested source sound mapping: warning→warn; throw→throw; stomp/bin_land→stomp; hit/clang/bin_hit→hitBot; down→pop plus stomp. No sound is attached to the source roar itself. Defeat emits 16 coins, two debris bursts and helper cleanup, and clears directly strictly after 2.6 seconds. `clear` is emitted once and only while `playing` is true. Keep bin/rain simulation and collisions running during the defeat delay. Do not spawn or wait for a jar.

## Exact source rules retained

- Health is 260 solo, 340 with more than one player. Start at world+200, facing left. Arena is world−view+90 to world−90. Entry is 250 px/s and completes at arena-right−160; the source also clamps the entry position, so its first live-player frame jumps inside the arena. Entry completion starts 1.4 seconds of walking delay and lid opening.
- Phase is 1 above `.66`, 2 above `.33`, otherwise 3. Helper thresholds are instead strictly **below** `.66` and `.33`. First helpers: left rush/right throw. Second: left flat/right rush, plus left fly in multiplayer. Both reopen the lid for 2.4 seconds.
- Walk speed is 80 px/s (120 in phase 3), only at distance strictly greater than 200. Attacks start strictly after `next`. Phase 1 always throws, phase 2 rolls with probability .5, phase 3 slams below .4, rolls below .7 and otherwise throws. Windup releases strictly after 420ms, recovery strictly after 820ms. Recovery gaps: 1.7–2.3s, 1.3–1.9s, .9–1.5s. Lid recovery opening: 1.2s, 1.0s, 1.2s. Phase 3 throwing also throws again 260ms later.
- Lid timer decrements before interpolation: `lid += (target-lid)*min(1,dt/.09)`. A hit at `lid=.6` damages; below .6 it clangs. The body hitbox is inclusive x±105 and ground−300 through ground. Shots ignore their damage value, applying one point, or two only when `dizzy>0`; flash lasts 80ms. Entry/down do not consume body shots.
- Bins launch x+face×60 with two HP. Arcs start at ground−270, vy −850, vx `(target_x + jitter[-60,60] − launch_x)/1.1` clamped ±550. Gravity 1700 uses semi-implicit Euler. At ground−40 they roll at ±300, using the boss face if their horizontal speed was zero. Direct rolling launches use face×[320,420]. Rotation accumulates horizontal displacement×.02.
- Bin player contact is strict x<40, feet>bin_y−40 and player top<bin_y+40; crouch/standing top uses .56/.86 of character height. Shot contact is strict x<40/y<46, costs one bin HP regardless of shot damage, and consumes the shot. At hp≤0 each matching shot emits two coins and debris. The source has no in-loop dead-bin guard, so a same-frame third shot can repeat the reward, and a shot after player contact can reward the already-collided bin. This unusual ordering is retained. Bins cull outside arena±140, not at equality.
- Slam waves start at boss x±80, speed ±450. Wave contact is strict x<24 and feet>ground−30; damage source is wave_x−vx×.05. Waves cull at arena±120, including equality. Rolling bins are represented as stationary wave markers for the following frame, then replaced after bin movement.
- Slam creates five rain pieces with x uniformly in the arena, y=view_top−40−i×120 and color i%3. Rain gravity is 1800. Pieces expire strictly beyond ground−14, then still test players that frame. Contact is strict x<28 and standing-top<rain_y<feet, even when crouched. Player shots do not destroy rain.
- Boss contact is strict x<210×.42 and feet>ground−260 after entry. There is no grounded or upper-feet bound. Dead players are ignored.

## Ability/invisible-shot equivalence

Source ability `zap` is a real player shot with `ghost=true`, nominal vx ±.1 px/s, initial age zero, initial t=1ms (so it does not sweep from the player's location), no homing, and expiry strictly after 70ms, applied after the ordinary update. Its intended target does not bypass object precedence. Helpers can intercept a boss-targeted zap; the boss can absorb a zap before crates/bins. A zap hitting a bin still costs exactly one HP.

For complete native parity, enqueue ability zaps and let the ordinary collision pass process them, rather than calling `hit()` directly. Direct `hit()` only guarantees the boss's lid/HP contract, not earlier helper interception. Ama temporarily sets `dizzy`, potentially making one or more same-frame accepted shots do two damage; the boss clears dizziness unconditionally in the next scene tick. The module does not introduce a stunned behavior or persistent bonus damage.

The original Binman object omits `fy`, although ability helpers later read it. Ama's unconditional boss-targeted ghost consequently has NaN y in JavaScript; Binman's negative-form hitTest still accepts it when the lid is open because NaN comparisons are false, while helpers' positive y tests cannot intercept it. Maya's boss distance test, ground pound's boss distance test and Theo's boss height tests instead fail before a targeted ghost is even emitted. Theo can still damage the source boss with finite-position free-ball ghosts. The native state explicitly supplies `fy=ground`, placing the targeted ghost at ground−120, enabling the intended Maya/pound/targeted-ball interactions and permitting helper interception of Ama's ghost. These are deliberate repairs to the source's missing coordinate, not claims of identical behavior to the bug. Do not emulate NaN coordinates in the renderer or physics.

### Native deferred ability hooks

For stage 1-6, call `abilities.tick(dt, controls, host, true)` after player motion. This pre-step keeps the previous ability clock and emits activation/shield/kick/pound ghosts early enough for the current ordinary shot pass. Combat must skip live bubbled enemies before its AI timer/flash updates and in its cleanup loop. After ordinary bot AI, call `abilities.bubbles_tick(dt, host)` before projectiles: it moves held bubbles to the array end, decrements their flash/bubble timer, updates bob using the previous ability clock, restores feet on release and queues the one-point sting. Array reordering preserves source shot-target priority. Do not remove bubbles before wave-completion checks.

After boss/bin collisions, call `abilities.effects_tick(dt, host)`. It advances the shared ability clock and moves Theo's ball, whose ghosts are first eligible for collision on the following frame. Then increment every ghost's age and remove ages strictly over .07 seconds, including ghosts just created by that ball. Free Theo balls call `host.ability_free_zap(ball_position, sign(ball_vx))` once per .18 seconds when no bot/boss is near. A `true` host return means one generic ghost was queued at the exact ball position, even with no nearby crate; `false` retains earlier stages' existing crate-proximity fallback. Targeted enemy/boss ghosts use direction `sign(target_x-player_x) || face`; crate ghosts use face. All ghosts skip shooter-to-target first-frame sweeps and ordinary projectile rendering.

The default three-argument ability tick retains earlier stages' combined clock/bubble/effect behavior. The new path is covered by `test_ability_ghost_order.gd`: 45 checks for pre/post clock order, late generic and targeted ball ghosts, target cooldowns, overlapping targets, one generic shot rather than per-crate shots, legacy fallback, bubble release/reordering and early physical coin rain. Existing `test_abilities.gd` remains 67/67 passing.

## Deliberate runtime boundaries

Godot's seeded RNG is repeatable, not JavaScript's Math.random sequence. Sprite/particle random numbers are not required to share the boss RNG. Use the original/fixed cadence: large Euler steps do not equal many small ones. Negative dt is clamped to zero. Native delayed throws use active simulation time and stop while paused, rather than the source's unpaused JavaScript setTimeout; an epsilon of one nanosecond avoids missing mathematically exact 260ms boundaries due to float accumulation. Reset cancels delayed work from the prior encounter rather than letting a stale callback affect a new boss. Clear is emitted once rather than repeatedly on every post-defeat play frame.

## Verification

Godot 4.6.3 headless:

```
XDG_DATA_HOME=/tmp/bd-binman-data XDG_CACHE_HOME=/tmp/bd-binman-cache \
  godot --headless --path godot --script res://tests/test_binman.gd
```

156 checks pass, covering HP, entry/clamp, lid smoothing, exact hit/phase/helper thresholds, shot consumption and damage, deterministic phase attack choice, windup/recovery/gaps, retargeted 260ms second throw/cancellation, arc and roll physics, landing/rotation, bins and overkill rewards, player/shot order, invulnerability boundaries, markers, slam/rain/wave geometry and collisions, post-down hazards, direct delayed clear, reset and multi-attack determinism. Renderer and full native stage/save behavior are verified by separate suites; this focused module suite alone does not assert host integration.

### Host wiring status

Native `main.gd` now selects this encounter for 1-6, passes the native bullet array and character-height/crouch participants, routes ordinary and invisible shots through the same helper/boss/crate pass, and drains final-hit helper cleanup before processing later shots. The host wires the deferred ability/bubble/effect hooks above, keeps the source's strict player-shot viewport bounds before bin collisions, ignores ghost drawing, and uses direct post-defeat progression without a jar. Source-order module checks remain separate from the host-integration and all-six-character full-stage/save simulations, which are maintained in their own suites.

### Victory and knockout precedence

Source `stageClear` runs before the final all-down check in `updatePlay`. The native host now defers the global knockout transition until the end of a 1-6 step, while applying health loss immediately. A lethal retained-bin/rain or ordinary-bill hit on the >2.6-second victory frame therefore still clears, restores the down player to one heart and saves/banks once. Earlier lethal hits still knock out normally; Continue retains the boss/hazard state and later clears. During that deferred frame, zero-heart players cannot collect coins/items/receipts or receive checkpoint healing. This prevents an already-latched boss clear from becoming permanently lost behind the knockout screen.
